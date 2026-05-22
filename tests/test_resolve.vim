vim9script
source <sfile>:h/setup.vim

const FIX = fnamemodify(resolve(expand('<sfile>:p')), ':h') .. '/fixtures'

def g:Test_FindRoot_from_nested_file()
  var root = wikijump#FindRoot(FIX .. '/notebook/notes/foo.md')
  assert_equal(FIX .. '/notebook', root)
enddef

def g:Test_FindRoot_from_root_file()
  var root = wikijump#FindRoot(FIX .. '/notebook/index.md')
  assert_equal(FIX .. '/notebook', root)
enddef

def g:Test_FindRoot_outside_notebook()
  var root = wikijump#FindRoot(FIX .. '/outside/random.md')
  assert_equal('', root)
enddef

def g:Test_FindRoot_stops_at_git_marker()
  var root = wikijump#FindRoot(FIX .. '/outside')
  assert_equal('', root)
enddef

def g:Test_ReadIndexName_empty_marker()
  var name = wikijump#ReadIndexName(FIX .. '/notebook')
  assert_equal('', name)
enddef

def g:Test_ResolveIndexName_falls_back_to_global()
  var name = wikijump#ResolveIndexName(FIX .. '/notebook')
  assert_equal('index.md', name)
enddef

def g:Test_OnBufEnter_sets_buffer_state_inside_notebook()
  execute 'edit' fnameescape(FIX .. '/notebook/notes/foo.md')
  assert_true(exists('b:wj_root'))
  assert_equal(FIX .. '/notebook', b:wj_root)
  assert_equal('index.md', b:wj_index_name)
  bwipeout!
enddef

def g:Test_OnBufEnter_clears_state_outside_notebook()
  execute 'edit' fnameescape(FIX .. '/outside/random.md')
  assert_false(exists('b:wj_root'))
  bwipeout!
enddef
