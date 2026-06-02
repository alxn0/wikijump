vim9script
source <sfile>:h/setup.vim

const FIX = fnamemodify(resolve(expand('<sfile>:p')), ':h') .. '/fixtures'

# back_stack is the plugin's only persistent module state, so it leaks across
# tests in the single vim -es run. Clear it at the top of every test.

# Follow bar.md's [[foo]] link into foo.md — the common arrange step.
def FollowFoo()
  execute 'edit' fnameescape(FIX .. '/tree/notes/bar.md')
  cursor(3, stridx(getline(3), 'foo') + 1)
  WikijumpFollow
enddef

def g:Test_Back_empty_stack_errors()
  wikijump#ClearBackStack()
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  var out = execute('WikijumpBack')
  assert_match('no previous wiki page', out)
  bwipeout!
enddef

def g:Test_BackExpr_empty_returns_literal()
  wikijump#ClearBackStack()
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  assert_equal("\<BS>", wikijump#BackExpr())
  bwipeout!
enddef

def g:Test_BackExpr_nonempty_returns_command()
  wikijump#ClearBackStack()
  FollowFoo()
  assert_equal(":WikijumpBack\<CR>", wikijump#BackExpr())
  bwipeout!
enddef

def g:Test_Back_returns_to_source_file()
  wikijump#ClearBackStack()
  FollowFoo()
  assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  WikijumpBack
  assert_equal(FIX .. '/tree/notes/bar.md', expand('%:p'))
  bwipeout!
enddef

def g:Test_Back_parks_cursor_on_link()
  wikijump#ClearBackStack()
  FollowFoo()
  WikijumpBack
  assert_equal(3, line('.'))
  # The cursor sits inside the link it came through, so it re-resolves.
  assert_equal('foo', wikijump#LinkUnderCursor().target)
  bwipeout!
enddef

def g:Test_Back_forward_via_CR_roundtrip()
  wikijump#ClearBackStack()
  FollowFoo()
  WikijumpBack
  assert_equal(FIX .. '/tree/notes/bar.md', expand('%:p'))
  # Re-following the parked link goes forward again (no forward stack).
  wikijump#Follow()
  assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  # And the re-follow re-pushed, so Back returns to bar a second time.
  WikijumpBack
  assert_equal(FIX .. '/tree/notes/bar.md', expand('%:p'))
  bwipeout!
enddef

def g:Test_Back_anchor_only_not_recorded()
  wikijump#ClearBackStack()
  execute 'edit' fnameescape(FIX .. '/tree/notes/foo.md')
  setline(1, ['[[#some-heading]]', '', '## Some Heading'])
  cursor(1, 5)
  WikijumpFollow
  # Anchor-only jumps stay in the same file and must not push history.
  assert_equal("\<BS>", wikijump#BackExpr())
  bwipeout!
enddef

def g:Test_Back_skips_unreadable_then_errors()
  wikijump#ClearBackStack()
  var tr = tempname()
  mkdir(tr, 'p')
  writefile([''], tr .. '/.wikijump')
  writefile(['[[ghost]]'], tr .. '/src.md')
  execute 'edit' fnameescape(tr .. '/src.md')
  cursor(1, 1)
  WikijumpFollow
  assert_equal(tr .. '/ghost.md', expand('%:p'))
  # The only history entry's source file vanishes mid-session.
  delete(tr .. '/src.md')
  var out = execute('WikijumpBack')
  assert_match('no previous wiki page', out)
  bwipeout!
  bwipeout!
  delete(tr, 'rf')
enddef

def g:Test_Back_clamps_cursor_past_eof()
  wikijump#ClearBackStack()
  var tr = tempname()
  mkdir(tr, 'p')
  writefile([''], tr .. '/.wikijump')
  writefile(['1', '2', '3', '4', 'see [[gone]]', '6'], tr .. '/src.md')
  execute 'edit' fnameescape(tr .. '/src.md')
  var src_buf = bufnr('%')
  cursor(5, 5)
  WikijumpFollow
  # Source shrinks below the recorded line, and its stale buffer is wiped so
  # Back reloads the shorter file from disk.
  writefile(['1', '2'], tr .. '/src.md')
  execute 'bwipeout!' src_buf
  WikijumpBack
  assert_equal(tr .. '/src.md', expand('%:p'))
  assert_equal(2, line('.'))
  bwipeout!
  delete(tr, 'rf')
enddef

def g:Test_Follow_failed_edit_records_nothing()
  wikijump#ClearBackStack()
  var save_hidden = &hidden
  set nohidden
  try
    execute 'edit' fnameescape(FIX .. '/tree/notes/bar.md')
    setline(1, getline(1) .. ' ')  # mark the buffer modified
    cursor(3, stridx(getline(3), 'foo') + 1)
    # :edit aborts with E37 (modified buffer, nohidden); catch it.
    try
      WikijumpFollow
    catch
    endtry
    # No phantom entry for the hop that never happened.
    assert_equal("\<BS>", wikijump#BackExpr())
    assert_equal(FIX .. '/tree/notes/bar.md', expand('%:p'))
  finally
    &hidden = save_hidden
    bwipeout!
  endtry
enddef

def g:Test_Back_failed_edit_keeps_entry()
  wikijump#ClearBackStack()
  FollowFoo()  # now in foo.md, one entry recorded for bar.md
  var save_hidden = &hidden
  set nohidden
  try
    setline(1, getline(1) .. ' ')  # modify foo.md so :edit bar.md errors
    try
      WikijumpBack
    catch
    endtry
    # The entry must survive the failed edit so a later <BS> can retry it.
    assert_equal(":WikijumpBack\<CR>", wikijump#BackExpr())
    assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  finally
    &hidden = save_hidden
    bwipeout!
  endtry
enddef

def g:Test_Back_multi_level()
  wikijump#ClearBackStack()
  # bar -> foo
  FollowFoo()
  assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  # foo -> bar (append a link to follow back)
  append(line('$'), 'go to [[bar]]')
  cursor(line('$'), stridx(getline('$'), 'bar') + 1)
  WikijumpFollow
  assert_equal(FIX .. '/tree/notes/bar.md', expand('%:p'))
  # Back walks the chain LIFO: bar -> foo -> bar.
  WikijumpBack
  assert_equal(FIX .. '/tree/notes/foo.md', expand('%:p'))
  WikijumpBack
  assert_equal(FIX .. '/tree/notes/bar.md', expand('%:p'))
  bwipeout!
  bwipeout!
enddef
