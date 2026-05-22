vim9script
source <sfile>:h/setup.vim

const FIX = fnamemodify(resolve(expand('<sfile>:p')), ':h') .. '/fixtures'

def g:Test_ResolveTarget_finds_nested_basename()
  var path = wikijump#ResolveTarget(FIX .. '/notebook', 'foo')
  assert_equal(FIX .. '/notebook/notes/foo.md', path)
enddef

def g:Test_ResolveTarget_excludes_underscore_dir()
  var path = wikijump#ResolveTarget(FIX .. '/notebook', 'skip')
  assert_equal('', path)
enddef

def g:Test_ResolveTarget_missing_returns_empty()
  var path = wikijump#ResolveTarget(FIX .. '/notebook', 'ghost')
  assert_equal('', path)
enddef

def g:Test_Follow_opens_existing_target()
  execute 'edit' fnameescape(FIX .. '/notebook/notes/bar.md')
  cursor(3, stridx(getline(3), 'foo') + 1)
  WikijumpFollow
  assert_equal(FIX .. '/notebook/notes/foo.md', expand('%:p'))
  bwipeout!
enddef

def g:Test_Follow_missing_target_opens_at_root()
  execute 'edit' fnameescape(FIX .. '/notebook/notes/bar.md')
  append(line('$'), 'A link to [[ghost]] here.')
  cursor(line('$'), stridx(getline('$'), 'ghost') + 1)
  WikijumpFollow
  assert_equal(FIX .. '/notebook/ghost.md', expand('%:p'))
  # Two new buffers exist (modified bar.md + empty ghost.md). Wipe both.
  bwipeout!
  bwipeout!
enddef

def g:Test_Follow_outside_notebook_errors()
  execute 'edit' fnameescape(FIX .. '/outside/random.md')
  var out = execute('WikijumpFollow')
  assert_match('not in a notebook', out)
  bwipeout!
enddef
