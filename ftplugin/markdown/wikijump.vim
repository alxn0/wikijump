vim9script
# Buffer-local wiring for markdown buffers inside a tree.
#
# Vim's filetype detection runs *before* BufEnter, so b:wj_root may not be
# populated yet when this ftplugin first fires. Calling OnBufEnter here
# makes resolution order-independent.

call wikijump#OnBufEnter()

if !exists('b:wj_root') || empty(b:wj_root)
  finish
endif

nnoremap <buffer><silent><expr> <CR> wikijump#FollowExpr()
nnoremap <buffer><silent><expr> <S-CR> wikijump#FollowExpr(true)
nnoremap <buffer><silent><expr> <BS> wikijump#BackExpr()

# Install completefunc only when the slot is free; we deliberately don't
# override an LSP or other plugin-provided completion. The <Plug> map
# below always works, regardless.
if empty(&l:completefunc)
  setlocal completefunc=wikijump#Complete
endif

inoremap <buffer><silent> <Plug>(wikijump-complete)
      \ <Cmd>call wikijump#TriggerComplete()<CR>

# Install the autocmd unconditionally; MaybeAutoComplete checks
# g:wj_autocomplete on each event, so toggling the global at runtime
# takes effect on the next keystroke without re-sourcing the ftplugin.
augroup wikijump_autocomplete
  autocmd! * <buffer>
  autocmd TextChangedI <buffer> call wikijump#MaybeAutoComplete()
augroup END
