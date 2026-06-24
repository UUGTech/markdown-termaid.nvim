# markdown-termaid.nvim

Preview Markdown Mermaid fenced blocks as ASCII diagrams through the `termaid`
CLI.

## Requirements

- Neovim 0.9+
- `termaid` on `$PATH`
- Optional: [hover.nvim](https://github.com/lewis6991/hover.nvim)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "UUGTech/markdown-termaid.nvim",
  ft = { "markdown" },
  cmd = { "TermaidPreview" },
  main = "markdown_termaid",
  opts = {
    cmd = { "termaid" },
    ascii = true,
    keymaps = {
      preview = "<leader>ma",
    },
    integrations = {
      hover = true,
    },
  },
}
```

## Usage

Put the cursor inside a Markdown Mermaid fence and run:

```vim
:TermaidPreview
```

or configure a keymap:

```lua
require("markdown_termaid").setup({
  keymaps = {
    preview = "<leader>ma",
  },
})
```

## hover.nvim

The plugin ships a `hover.nvim` provider. Require it from `hover.nvim`'s `init`
callback so it participates in the normal provider priority order:

```lua
require("hover").setup({
  init = function()
    require("hover.providers.lsp")
    require("markdown_termaid.hover")
  end,
})
```

The provider is named `Mermaid` and defaults to priority `1100`.

## Configuration

Defaults:

```lua
require("markdown_termaid").setup({
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
})
```
