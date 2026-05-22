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

def g:Test_Follow_jumps_to_anchor()
  execute 'edit' fnameescape(FIX .. '/notebook/notes/bar.md')
  cursor(3, stridx(getline(3), 'some-heading') + 1)
  WikijumpFollow
  assert_equal(FIX .. '/notebook/notes/foo.md', expand('%:p'))
  assert_match('^##\s\+Some Heading', getline('.'))
  bwipeout!
enddef

def g:Test_JumpToAnchor_silent_on_miss()
  execute 'edit' fnameescape(FIX .. '/notebook/notes/foo.md')
  cursor(1, 1)
  wikijump#JumpToAnchor('nonexistent')
  assert_equal(1, line('.'))
  bwipeout!
enddef

def g:Test_JumpToAnchor_normalizes_hyphens_and_case()
  execute 'edit' fnameescape(FIX .. '/notebook/notes/foo.md')
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
  execute 'edit' fnameescape(FIX .. '/notebook/notes/foo.md')
  setline(1, ['[[#some-heading]]', '', '## Some Heading'])
  cursor(1, 5)
  WikijumpFollow
  assert_equal(FIX .. '/notebook/notes/foo.md', expand('%:p'))
  assert_match('^##\s\+Some Heading', getline('.'))
  bwipeout!
enddef

def g:Test_ResolveTarget_treats_glob_metas_as_literal()
  var nb = tempname()
  mkdir(nb, 'p')
  writefile([], nb .. '/.wikijump')
  writefile([], nb .. '/foo.md')
  writefile([], nb .. '/foobar.md')
  # `foo*` must not match `foo.md` or `foobar.md` via glob expansion.
  assert_equal('', wikijump#ResolveTarget(nb, 'foo*'))
  # Sanity: exact literal `foo` still resolves.
  assert_equal(nb .. '/foo.md', wikijump#ResolveTarget(nb, 'foo'))
  delete(nb, 'rf')
enddef

def g:Test_Follow_rejects_slash_in_target()
  execute 'edit' fnameescape(FIX .. '/notebook/notes/bar.md')
  setline(1, 'see [[notes/foo]] above')
  cursor(1, stridx(getline(1), 'notes/') + 1)
  var out = execute('WikijumpFollow')
  assert_match('cannot contain /', out)
  # Still in bar.md — no nested file was opened or created.
  assert_equal(FIX .. '/notebook/notes/bar.md', expand('%:p'))
  set nomodified
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
