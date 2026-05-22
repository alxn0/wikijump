vim9script
source <sfile>:h/setup.vim

def Setup(line: string)
  enew!
  setline(1, line)
enddef

def Select(start_col: number, end_col: number)
  cursor(1, start_col)
  execute 'normal!' 'v' .. (end_col - start_col) .. 'l'
  execute "normal! \<Esc>"
enddef

def g:Test_Wrap_wraps_word()
  Setup('hello world')
  Select(1, 5)
  WikijumpWrap
  assert_equal('[[hello]] world', getline(1))
  bwipeout!
enddef

def g:Test_Wrap_wraps_phrase_with_space()
  Setup('hello cruel world')
  Select(7, 17)
  WikijumpWrap
  assert_equal('hello [[cruel world]]', getline(1))
  bwipeout!
enddef

def g:Test_Wrap_no_selection_errors()
  Setup('hello')
  # Clear visual marks by switching buffers.
  delmarks <>
  var out = execute('WikijumpWrap')
  assert_match('no visual selection', out)
  bwipeout!
enddef
