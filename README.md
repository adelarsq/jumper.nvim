# jumper.nvim 🐏

A simple plugin to jump between files.

## Installation 🧙

### [Lazy](https://github.com/folke/lazy.nvim) 🐢

Add the following lines on the NeoVim config file (Lua):

```lua
require('lazy').setup({
  {
    'https://github.com/adelarsq/jumper.vim',
    config = function ()
        require('jumper').setup()
    end
  },
}, {})
```

## Commands 🧩

- JumperAdd - add current file to the list. Supports [oil](https://github.com/stevearc/oil.nvim) and [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua) plugins.
- JumperList - show current file list on quickfix
- JumperClear - clean file list
- JumperJump - jump to file by index 
- JumperTerminal - open or toggle terminal per tab

## Acknowledgments 💡

Thanks goes to these people/projects for inspiration:

- [ThePrimeagen/harpoon](https://github.com/ThePrimeagen/harpoon)
- [0x7a7a/bufpin.nvim](https://github.com/0x7a7a/bufpin.nvim)
- [volskaya/windovigation.nvim](https://github.com/volskaya/windovigation.nvim)
- [alucherdi/hand-of-god](https://github.com/alucherdi/hand-of-god)


