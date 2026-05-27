vim9script
source <sfile>:h/setup.vim

const FIX = fnamemodify(resolve(expand('<sfile>:p')), ':h') .. '/fixtures'

def g:Test_Index_opens_default_landing_page()
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  WikijumpIndex
  assert_equal(FIX .. '/tree/README.md', expand('%:p'))
  bwipeout!
enddef

def g:Test_Index_honors_marker_override()
  execute 'edit' fnameescape(FIX .. '/custom_index/notes.md')
  WikijumpIndex
  assert_equal(FIX .. '/custom_index/index.md', expand('%:p'))
  bwipeout!
enddef

def g:Test_Index_outside_tree_errors()
  execute 'edit' fnameescape(FIX .. '/outside/random.md')
  var out = execute('WikijumpIndex')
  assert_match('no .wikijump marker found', out)
  bwipeout!
enddef

def g:Test_Index_creates_missing_landing_page_on_save()
  # Fresh tree where the landing page does not yet exist.
  var tmp = tempname()
  mkdir(tmp, 'p')
  writefile([], tmp .. '/.wikijump')
  writefile(['# placeholder'], tmp .. '/placeholder.md')
  execute 'edit' fnameescape(tmp .. '/placeholder.md')
  WikijumpIndex
  assert_equal(tmp .. '/README.md', expand('%:p'))
  assert_false(filereadable(tmp .. '/README.md'))
  bwipeout!
  bwipeout!
  delete(tmp .. '/.wikijump')
  delete(tmp .. '/placeholder.md')
  delete(tmp, 'd')
enddef
