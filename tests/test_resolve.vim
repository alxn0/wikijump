vim9script
source <sfile>:h/setup.vim

const FIX = fnamemodify(resolve(expand('<sfile>:p')), ':h') .. '/fixtures'

def g:Test_FindRoot_from_nested_file()
  var root = wikijump#FindRoot(FIX .. '/tree/notes/foo.md')
  assert_equal(FIX .. '/tree', root)
enddef

def g:Test_FindRoot_from_root_file()
  var root = wikijump#FindRoot(FIX .. '/tree/index.md')
  assert_equal(FIX .. '/tree', root)
enddef

def g:Test_FindRoot_outside_tree()
  var root = wikijump#FindRoot(FIX .. '/outside/random.md')
  assert_equal('', root)
enddef

def g:Test_FindRoot_stops_at_git_marker()
  var root = wikijump#FindRoot(FIX .. '/outside')
  assert_equal('', root)
enddef

def g:Test_ReadIndexName_empty_marker()
  var name = wikijump#ReadIndexName(FIX .. '/tree')
  assert_equal('', name)
enddef

def g:Test_ResolveIndexName_falls_back_to_global()
  var name = wikijump#ResolveIndexName(FIX .. '/tree')
  assert_equal('README.md', name)
enddef

def g:Test_OnBufEnter_sets_buffer_state_inside_tree()
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  assert_true(exists('b:wj_root'))
  assert_equal(FIX .. '/tree', b:wj_root)
  assert_equal('README.md', b:wj_index_name)
  bwipeout!
enddef

def g:Test_OnBufEnter_clears_state_outside_tree()
  execute 'edit' fnameescape(FIX .. '/outside/random.md')
  assert_false(exists('b:wj_root'))
  bwipeout!
enddef

def g:Test_WikijumpRoot_inside_tree()
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  var out = execute('WikijumpRoot')
  assert_match(escape(FIX .. '/tree', '/.'), out)
  bwipeout!
enddef

def g:Test_WikijumpRoot_outside_errors()
  execute 'edit' fnameescape(FIX .. '/outside/random.md')
  var out = execute('WikijumpRoot')
  assert_match('no .wikijump marker found', out)
  bwipeout!
enddef

def g:Test_OnBufEnter_skips_non_file_buffers()
  # Switch to the existing tree file first to set b:wj_root.
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  assert_true(exists('b:wj_root'))
  # Now switch to a buffer with buftype set (synthetic). OnBufEnter
  # must NOT walk the resolver against the synthetic name.
  enew!
  setlocal buftype=nofile
  call wikijump#OnBufEnter()
  assert_false(exists('b:wj_root'))
  bwipeout!
  bwipeout!
enddef

