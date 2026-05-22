vim9script
# Buffer-local wiring for markdown buffers inside a notebook.
# Loaded by Vim's filetype machinery after BufEnter, so b:wj_root is set.

if !exists('b:wj_root') || empty(b:wj_root)
  finish
endif
