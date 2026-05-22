vim9script
source <sfile>:h/setup.vim

def PlaceCursor(line: string, col_text: string)
  enew
  setline(1, line)
  cursor(1, max([stridx(line, col_text) + 1, 1]))
enddef

def g:Test_Parse_plain_link()
  PlaceCursor('See [[foo]] for more.', 'foo')
  var link = wikijump#LinkUnderCursor()
  assert_equal('foo', link.target)
  assert_equal('', link.anchor)
  assert_equal('foo', link.display)
  bwipeout!
enddef

def g:Test_Parse_alias_link()
  PlaceCursor('See [[foo|Friendly Name]] here.', 'Friendly')
  var link = wikijump#LinkUnderCursor()
  assert_equal('foo', link.target)
  assert_equal('Friendly Name', link.display)
  assert_equal('', link.anchor)
  bwipeout!
enddef

def g:Test_Parse_anchor_link()
  PlaceCursor('See [[foo#some-heading]] here.', 'some-heading')
  var link = wikijump#LinkUnderCursor()
  assert_equal('foo', link.target)
  assert_equal('some-heading', link.anchor)
  bwipeout!
enddef

def g:Test_Parse_anchor_and_alias()
  PlaceCursor('See [[foo#some-heading|click]] here.', 'click')
  var link = wikijump#LinkUnderCursor()
  assert_equal('foo', link.target)
  assert_equal('some-heading', link.anchor)
  assert_equal('click', link.display)
  bwipeout!
enddef

def g:Test_Parse_cursor_outside_link()
  PlaceCursor('plain prose with no links here', 'prose')
  var link = wikijump#LinkUnderCursor()
  assert_true(empty(link))
  bwipeout!
enddef

def g:Test_Parse_picks_link_containing_cursor()
  enew
  setline(1, 'left [[one]] middle [[two]] right')
  cursor(1, stridx(getline(1), 'two') + 1)
  var link = wikijump#LinkUnderCursor()
  assert_equal('two', link.target)
  bwipeout!
enddef

def g:Test_Parse_anchor_only_link()
  PlaceCursor('see [[#some-heading]] above', 'some')
  var link = wikijump#LinkUnderCursor()
  assert_equal('', link.target)
  assert_equal('some-heading', link.anchor)
  bwipeout!
enddef

def g:Test_Parse_alias_only_link()
  PlaceCursor('see [[|just an alias]] above', 'alias')
  var link = wikijump#LinkUnderCursor()
  assert_equal('', link.target)
  assert_equal('just an alias', link.display)
  bwipeout!
enddef
