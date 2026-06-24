local M = {}

local defaults = {
	cmd = { "termaid" },
	ascii = true,
	border = "rounded",
	auto_install = false,
	install_commands = {
		{ "uv", "tool", "install", "termaid" },
		{ "python3", "-m", "pip", "install", "--user", "termaid" },
		{ "pip3", "install", "--user", "termaid" },
		{ "pip", "install", "--user", "termaid" },
	},
	command = "TermaidPreview",
	keymaps = {
		preview = nil,
	},
	integrations = {
		hover = false,
	},
	hover = {
		name = "Mermaid",
		priority = 1100,
	},
}

M.opts = vim.deepcopy(defaults)

local install_state = {
	tried = false,
	success = false,
}

local hover_registered = false

local function normalize_cmd(cmd)
	if type(cmd) == "string" then
		return { cmd }
	end
	return vim.deepcopy(cmd)
end

local function run_command(cmd, input)
	return vim.fn.systemlist(cmd, input), vim.v.shell_error
end

local function ensure_installed(bin)
	if vim.fn.executable(bin) == 1 then
		return true
	end

	if not M.opts.auto_install then
		return false
	end

	if install_state.tried then
		return install_state.success and vim.fn.executable(bin) == 1
	end

	install_state.tried = true
	vim.notify(("`%s` not found. Installing termaid..."):format(bin), vim.log.levels.INFO)

	for _, install_cmd in ipairs(M.opts.install_commands) do
		local _, code = run_command(install_cmd)
		if code == 0 and vim.fn.executable(bin) == 1 then
			install_state.success = true
			vim.notify("termaid installed successfully", vim.log.levels.INFO)
			return true
		end
	end

	install_state.success = false
	vim.notify("Failed to auto-install termaid. Try: pip install termaid", vim.log.levels.ERROR)
	return false
end

local function split_first_word(text)
	return (text:match("^(%S+)") or ""):lower()
end

function M.find_mermaid_block(bufnr, cursor_row)
	local prefix_lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor_row, false)
	local in_fence = false
	local fence_lang = ""
	local content_start = nil

	for i = 1, cursor_row do
		local line = prefix_lines[i]
		local fence = line and line:match("^%s*```%s*(.-)%s*$")
		if fence ~= nil then
			if not in_fence then
				in_fence = true
				fence_lang = split_first_word(fence)
				content_start = i + 1
			else
				in_fence = false
				fence_lang = ""
				content_start = nil
			end
		end
	end

	if not in_fence or fence_lang ~= "mermaid" or content_start == nil then
		return nil
	end

	local total = vim.api.nvim_buf_line_count(bufnr)
	local suffix_lines = vim.api.nvim_buf_get_lines(bufnr, cursor_row, total, false)
	local close_line = nil

	for i, line in ipairs(suffix_lines) do
		if line:match("^%s*```%s*$") then
			close_line = cursor_row + i
			break
		end
	end

	if close_line == nil or close_line <= content_start then
		return nil
	end

	local body = vim.api.nvim_buf_get_lines(bufnr, content_start - 1, close_line - 1, false)
	if #body == 0 then
		return nil
	end

	return body
end

local function open_floating(lines)
	local max_line = 1
	for _, line in ipairs(lines) do
		max_line = math.max(max_line, vim.fn.strdisplaywidth(line))
	end

	local max_width = math.max(40, vim.o.columns - 6)
	local width = math.min(max_line + 2, max_width)
	local max_height = math.max(8, math.floor(vim.o.lines * 0.8))
	local height = math.min(#lines, max_height)

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "text"
	vim.bo[bufnr].modifiable = false

	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = M.opts.border,
		title = " Mermaid ASCII ",
		title_pos = "center",
	})

	vim.wo[win].wrap = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].cursorline = false

	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = bufnr, silent = true })
	end
end

function M.enabled(bufnr, row)
	if vim.bo[bufnr].filetype ~= "markdown" then
		return false
	end

	return M.find_mermaid_block(bufnr, row or vim.api.nvim_win_get_cursor(0)[1]) ~= nil
end

function M.render(bufnr, row)
	local cmd = normalize_cmd(M.opts.cmd)
	local bin = cmd[1]
	if not ensure_installed(bin) then
		return nil, ("`%s` executable not found"):format(bin)
	end

	local mermaid_lines = M.find_mermaid_block(bufnr, row)
	if not mermaid_lines then
		return nil, "Place cursor inside a ```mermaid fenced block"
	end

	if M.opts.ascii then
		table.insert(cmd, "--ascii")
	end

	local input = table.concat(mermaid_lines, "\n") .. "\n"
	local rendered, code = run_command(cmd, input)
	if code ~= 0 then
		return nil, table.concat(rendered, "\n")
	end

	if #rendered == 0 then
		return nil, "termaid returned no output"
	end

	return rendered
end

function M.preview_mermaid_under_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local rendered, err = M.render(bufnr, row)
	if not rendered then
		if err then
			vim.notify(err, vim.log.levels.INFO, { title = "markdown-termaid.nvim" })
		end
		return false
	end

	open_floating(rendered)
	return true
end

function M.hover_provider()
	return {
		name = M.opts.hover.name,
		priority = M.opts.hover.priority,
		enabled = function(bufnr, opts)
			local row = opts and opts.pos and opts.pos[1] or vim.api.nvim_win_get_cursor(0)[1]
			return M.enabled(bufnr, row)
		end,
		execute = function(opts, done)
			local rendered = M.render(opts.bufnr, opts.pos[1])
			if rendered then
				done({ lines = rendered, filetype = "text" })
			else
				done()
			end
		end,
	}
end

function M.register_hover()
	if hover_registered then
		return true
	end

	local ok, hover = pcall(require, "hover")
	if not ok then
		return false
	end

	hover.register(M.hover_provider())
	hover_registered = true
	return true
end

local function setup_command()
	if not M.opts.command or M.opts.command == "" then
		return
	end

	vim.api.nvim_create_user_command(M.opts.command, function()
		M.preview_mermaid_under_cursor()
	end, { desc = "Preview Mermaid block as ASCII via termaid" })
end

local function setup_keymaps()
	local preview = M.opts.keymaps.preview
	if preview then
		vim.keymap.set("n", preview, function()
			M.preview_mermaid_under_cursor()
		end, { desc = "Mermaid ASCII preview" })
	end
end

function M.setup(opts)
	M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	setup_command()
	setup_keymaps()

	if M.opts.integrations.hover then
		M.register_hover()
	end
end

return M
