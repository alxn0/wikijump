vim9script
# wikijump.vim — follow and create [[wikilinks]] in markdown notebooks.

if exists('g:loaded_wikijump')
  finish
endif
g:loaded_wikijump = 1

g:wj_marker_name  = get(g:, 'wj_marker_name',  '.wikijump')
g:wj_index_name   = get(g:, 'wj_index_name',   'index.md')
g:wj_stop_markers = get(g:, 'wj_stop_markers', ['.git'])
g:wj_autocomplete = get(g:, 'wj_autocomplete', 0)

augroup wikijump
  autocmd!
  autocmd BufEnter * call wikijump#OnBufEnter()
augroup END

command! -bar WikijumpRoot   call wikijump#Root()
command! -bar WikijumpFollow call wikijump#Follow()
command! -bar WikijumpNext   call wikijump#Next()
command! -bar WikijumpPrev   call wikijump#Prev()
command! -bar WikijumpIndex  call wikijump#Index()
