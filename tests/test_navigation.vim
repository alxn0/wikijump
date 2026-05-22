vim9script
source <sfile>:h/setup.vim

def Setup()
  enew!
  setline(1, [
    'no links here',
    'first [[alpha]] link',
    'a markdown [link](should-be-skipped.md)',
    'second [[beta]] link',
    'third [[gamma]] link',
  ])
  cursor(1, 1)
enddef

def g:Test_Next_jumps_to_first_link()
  Setup()
  WikijumpNext
  assert_equal(2, line('.'))
  bwipeout!
enddef

def g:Test_Next_skips_markdown_links()
  Setup()
  cursor(2, 1)
  WikijumpNext
  WikijumpNext
  assert_equal(4, line('.'))
  bwipeout!
enddef

def g:Test_Next_wraps_around()
  Setup()
  cursor(5, 1)
  WikijumpNext
  WikijumpNext
  assert_equal(2, line('.'))
  bwipeout!
enddef

def g:Test_Prev_jumps_backward()
  Setup()
  cursor(5, 1)
  WikijumpPrev
  assert_equal(4, line('.'))
  bwipeout!
enddef

def g:Test_Prev_wraps_around()
  Setup()
  cursor(1, 1)
  WikijumpPrev
  assert_equal(5, line('.'))
  bwipeout!
enddef
