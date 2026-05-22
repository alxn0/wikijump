vim9script
source <sfile>:h/setup.vim

const FIX = fnamemodify(resolve(expand('<sfile>:p')), ':h') .. '/fixtures'

def MakeNotebook(): string
  var dir = tempname()
  mkdir(dir .. '/notes', 'p')
  mkdir(dir .. '/_templates', 'p')
  writefile([], dir .. '/.wikijump')
  writefile(['# Foo', '## Some Heading'], dir .. '/notes/foo.md')
  writefile([
    '# Bar',
    'plain [[foo]] link',
    'alias [[foo|nice]] link',
    'section [[foo#some-heading]] link',
    'combined [[foo#some-heading|click]] link',
    'unrelated [[other]] link',
  ], dir .. '/notes/bar.md')
  writefile(['# Other'], dir .. '/notes/other.md')
  writefile(['skip me [[foo]] please'], dir .. '/_templates/skip.md')
  return dir
enddef

def Cleanup(dir: string)
  delete(dir, 'rf')
enddef

def g:Test_Rename_moves_file_on_disk()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux
  assert_true(filereadable(nb .. '/notes/qux.md'))
  assert_false(filereadable(nb .. '/notes/foo.md'))
  assert_equal(nb .. '/notes/qux.md', expand('%:p'))
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_updates_plain_link()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux
  var bar = readfile(nb .. '/notes/bar.md')
  assert_match('\V[[qux]]', bar[1])
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_updates_alias_link()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux
  var bar = readfile(nb .. '/notes/bar.md')
  assert_match('\V[[qux|nice]]', bar[2])
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_updates_section_link()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux
  var bar = readfile(nb .. '/notes/bar.md')
  assert_match('\V[[qux#some-heading]]', bar[3])
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_updates_section_with_alias()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux
  var bar = readfile(nb .. '/notes/bar.md')
  assert_match('\V[[qux#some-heading|click]]', bar[4])
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_leaves_unrelated_links_alone()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux
  var bar = readfile(nb .. '/notes/bar.md')
  assert_match('\V[[other]]', bar[5])
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_skips_excluded_directories()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux
  var tpl = readfile(nb .. '/_templates/skip.md')
  assert_match('\V[[foo]]', tpl[0])
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_strips_md_extension()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux.md
  assert_equal(nb .. '/notes/qux.md', expand('%:p'))
  assert_false(filereadable(nb .. '/notes/qux.md.md'))
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_preserves_non_md_extension()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux.draft
  assert_equal(nb .. '/notes/qux.draft.md', expand('%:p'))
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_rejects_bare_md_extension()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  var out = execute('WikijumpRename .md')
  assert_match('rename requires a new name', out)
  assert_true(filereadable(nb .. '/notes/foo.md'))
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_rejects_directory_at_destination()
  var nb = MakeNotebook()
  mkdir(nb .. '/notes/qux.md', 'p')
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  var out = execute('WikijumpRename qux')
  assert_match('destination already exists', out)
  assert_true(filereadable(nb .. '/notes/foo.md'))
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_aborts_on_dirty_buffer_in_notebook()
  var nb = MakeNotebook()
  # Open bar.md in a hidden buffer and dirty it without saving.
  execute 'edit' fnameescape(nb .. '/notes/bar.md')
  call append(0, 'dirty edit')
  var bar_buf = bufnr('%')
  # Switch to foo.md and try to rename — should refuse.
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  var out = execute('WikijumpRename qux')
  assert_match('has unsaved changes', out)
  assert_true(filereadable(nb .. '/notes/foo.md'))
  assert_false(filereadable(nb .. '/notes/qux.md'))
  # Bar's on-disk content must be untouched.
  var bar = readfile(nb .. '/notes/bar.md')
  assert_match('\V[[foo]]', bar[1])
  bwipeout!
  execute 'bwipeout!' bar_buf
  Cleanup(nb)
enddef

def g:Test_Rename_preserves_cursor_view()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  cursor(2, 1)
  var before = line('.')
  WikijumpRename qux
  assert_equal(before, line('.'))
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_preserves_file_permissions()
  var nb = MakeNotebook()
  setfperm(nb .. '/notes/bar.md', 'rw-------')
  var before = getfperm(nb .. '/notes/bar.md')
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  WikijumpRename qux
  assert_equal(before, getfperm(nb .. '/notes/bar.md'))
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_ignores_dirty_buffer_in_sibling_notebook()
  # Two notebooks where one's path is a string prefix of the other's.
  var parent = tempname()
  mkdir(parent .. '/notes', 'p')
  mkdir(parent .. '/notes-archive', 'p')
  writefile([], parent .. '/notes/.wikijump')
  writefile([], parent .. '/notes-archive/.wikijump')
  writefile(['# foo'], parent .. '/notes/foo.md')
  writefile(['# other'], parent .. '/notes-archive/other.md')
  # Open and dirty a buffer in the sibling notebook.
  execute 'edit' fnameescape(parent .. '/notes-archive/other.md')
  call append(0, 'dirty')
  var sib_buf = bufnr('%')
  # Rename in the primary notebook — should NOT be blocked.
  execute 'edit' fnameescape(parent .. '/notes/foo.md')
  WikijumpRename qux
  assert_true(filereadable(parent .. '/notes/qux.md'))
  assert_false(filereadable(parent .. '/notes/foo.md'))
  bwipeout!
  execute 'bwipeout!' sib_buf
  delete(parent, 'rf')
enddef

def g:Test_Rename_rejects_existing_destination()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  var out = execute('WikijumpRename other')
  assert_match('destination already exists', out)
  assert_true(filereadable(nb .. '/notes/foo.md'))
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_rejects_same_name()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  var out = execute('WikijumpRename foo')
  assert_match('same as the current name', out)
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_rejects_invalid_characters()
  var nb = MakeNotebook()
  execute 'edit' fnameescape(nb .. '/notes/foo.md')
  # | is Vim's command separator on the command line, so call directly.
  var out = execute('call wikijump#Rename("bad|name")')
  assert_match('invalid characters', out)
  assert_true(filereadable(nb .. '/notes/foo.md'))
  bwipeout!
  Cleanup(nb)
enddef

def g:Test_Rename_errors_outside_notebook()
  execute 'edit' fnameescape(FIX .. '/outside/random.md')
  var out = execute('WikijumpRename whatever')
  assert_match('not in a notebook', out)
  bwipeout!
enddef
