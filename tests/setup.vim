vim9script
# Loaded by each test_*.vim to put the plugin on runtimepath.
# Run from the project root.

var here = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
execute 'set runtimepath^=' .. fnameescape(here)
execute 'set runtimepath+=' .. fnameescape(here .. '/after')

# Load plugin/* (BufEnter autocmd, defaults, commands).
runtime! plugin/wikijump.vim

# Make sure markdown filetype detection is active so ftplugin loads.
filetype plugin on

# Allow switching between modified buffers in tests without errors.
set hidden
