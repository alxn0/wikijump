vim9script
source <sfile>:h/setup.vim

const FIX = fnamemodify(resolve(expand('<sfile>:p')), ':h') .. '/fixtures'

def g:Test_ResolveTarget_finds_nested_basename()
  var path = wikijump#ResolveTarget(FIX .. '/tree', 'foo')
  assert_equal(FIX .. '/tree/notes/foo.md', path)
enddef

def g:Test_ResolveTarget_excludes_underscore_dir()
  var path = wikijump#ResolveTarget(FIX .. '/tree', 'skip')
  assert_equal('', path)
enddef

def g:Test_ResolveTarget_missing_returns_empty()
  var path = wikijump#ResolveTarget(FIX .. '/tree', 'ghost')
  assert_equal('', path)
enddef

def g:Test_Follow_opens_existing_target()
  execute 'edit' fnameescape(FIX .. '/tree/notes/bar.md')
  cursor(3, stridx(getline(3), 'foo') + 1)
  WikijumpFollow
  assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  bwipeout!
enddef

def g:Test_Follow_missing_target_opens_at_root()
  execute 'edit' fnameescape(FIX .. '/tree/notes/bar.md')
  append(line('$'), 'A link to [[ghost]] here.')
  cursor(line('$'), stridx(getline('$'), 'ghost') + 1)
  WikijumpFollow
  assert_equal(FIX .. '/tree/ghost.md', expand('%:p'))
  # Two new buffers exist (modified bar.md + empty ghost.md). Wipe both.
  bwipeout!
  bwipeout!
enddef

def g:Test_Follow_outside_tree_errors()
  execute 'edit' fnameescape(FIX .. '/outside/random.md')
  var out = execute('WikijumpFollow')
  assert_match('no .wikijump marker found', out)
  bwipeout!
enddef

def g:Test_Follow_jumps_to_anchor()
  execute 'edit' fnameescape(FIX .. '/tree/notes/bar.md')
  cursor(3, stridx(getline(3), 'some-heading') + 1)
  WikijumpFollow
  assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  assert_match('^##\s\+Some Heading', getline('.'))
  bwipeout!
enddef

def g:Test_JumpToAnchor_silent_on_miss()
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  cursor(1, 1)
  wikijump#JumpToAnchor('nonexistent')
  assert_equal(1, line('.'))
  bwipeout!
enddef

def g:Test_JumpToAnchor_normalizes_hyphens_and_case()
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  cursor(1, 1)
  wikijump#JumpToAnchor('SOME-HEADING')
  assert_match('^##\s\+Some Heading', getline('.'))
  bwipeout!
enddef

def g:Test_JumpToAnchor_skips_headings_inside_code_fences()
  enew!
  setline(1, [
    '# Foo',
    '',
    '```python',
    '# Some Heading',
    '```',
    '',
    '## Some Heading',
  ])
  cursor(1, 1)
  wikijump#JumpToAnchor('some-heading')
  assert_equal(7, line('.'))
  bwipeout!
enddef

def g:Test_Follow_anchor_only_link_stays_in_current_file()
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  setline(1, ['[[#some-heading]]', '', '## Some Heading'])
  cursor(1, 5)
  WikijumpFollow
  assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  assert_match('^##\s\+Some Heading', getline('.'))
  bwipeout!
enddef

def g:Test_ResolveTarget_treats_glob_metas_as_literal()
  var tr = tempname()
  mkdir(tr, 'p')
  writefile([], tr .. '/.wikijump')
  writefile([], tr .. '/foo.md')
  writefile([], tr .. '/foobar.md')
  # `foo*` must not match `foo.md` or `foobar.md` via glob expansion.
  assert_equal('', wikijump#ResolveTarget(tr, 'foo*'))
  # Sanity: exact literal `foo` still resolves.
  assert_equal(tr .. '/foo.md', wikijump#ResolveTarget(tr, 'foo'))
  delete(tr, 'rf')
enddef

def g:Test_Follow_rejects_slash_in_target()
  execute 'edit' fnameescape(FIX .. '/tree/notes/bar.md')
  setline(1, 'see [[notes/foo]] above')
  cursor(1, stridx(getline(1), 'notes/') + 1)
  var out = execute('WikijumpFollow')
  assert_match('cannot contain /', out)
  # Still in bar.md — no nested file was opened or created.
  assert_equal(FIX .. '/tree/notes/bar.md', expand('%:p'))
  set nomodified
  bwipeout!
enddef

# Split-follow bar.md's [[foo]] link into foo.md — the common arrange step.
def SplitFollowFoo()
  execute 'edit' fnameescape(FIX .. '/tree/notes/bar.md')
  cursor(3, stridx(getline(3), 'foo') + 1)
  WikijumpFollowSplit
enddef

def g:Test_FollowSplit_opens_in_new_window()
  SplitFollowFoo()
  assert_equal(2, winnr('$'))
  # Default 'rightbelow vsplit': new window is on the right (#2) and
  # holds the cursor.
  assert_equal(2, winnr())
  assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  only
  bwipeout!
enddef

def g:Test_FollowSplit_respects_wj_split_cmd()
  var saved = g:wj_split_cmd
  g:wj_split_cmd = 'split'
  SplitFollowFoo()
  # `split` stacks windows: the new one sits above, same width.
  assert_equal(2, winnr('$'))
  assert_equal(winwidth(1), winwidth(2))
  assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  g:wj_split_cmd = saved
  only
  bwipeout!
enddef

def g:Test_JumpToAnchor_skips_tilde_fences()
  enew!
  setline(1, [
    '# Foo',
    '',
    '~~~python',
    '# Some Heading',
    '~~~',
    '',
    '## Some Heading',
  ])
  cursor(1, 1)
  wikijump#JumpToAnchor('some-heading')
  assert_equal(7, line('.'))
  bwipeout!
enddef
