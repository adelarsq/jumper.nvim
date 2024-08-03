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

- JumperAdd - add current file to the list. Supports oil and nvim-tree plugin.
- JumperList - show current file list on quickfix
- JumperJump - jump to file by index 

## Acknowledgments 💡

Thanks goes to these people/projects for inspiration:

- [ThePrimeagen/harpoon](https://github.com/ThePrimeagen/harpoon)
- [0x7a7a/bufpin.nvim](https://github.com/0x7a7a/bufpin.nvim)
- [volskaya/windovigation.nvim](https://github.com/volskaya/windovigation.nvim)


