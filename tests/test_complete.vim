vim9script
source <sfile>:h/setup.vim

const FIX = fnamemodify(resolve(expand('<sfile>:p')), ':h') .. '/fixtures'

def OpenInNotebook()
  execute 'edit' fnameescape(FIX .. '/notebook/index.md')
enddef

def g:Test_Complete_findstart_inside_brackets()
  OpenInNotebook()
  enew!
  b:wj_root = FIX .. '/notebook'
  setline(1, 'See [[fo')
  cursor(1, len(getline(1)) + 1)
  var start = wikijump#Complete(1, '')
  # Cursor at end of line; '[[' opens at column 5-6 (1-based), so the
  # completion start should be column 7.
  assert_equal(7, start)
  bwipeout!
enddef

def g:Test_Complete_findstart_outside_brackets()
  OpenInNotebook()
  enew!
  b:wj_root = FIX .. '/notebook'
  setline(1, 'just plain prose')
  cursor(1, len(getline(1)) + 1)
  assert_equal(-2, wikijump#Complete(1, ''))
  bwipeout!
enddef

def g:Test_Complete_candidates_listed_by_basename()
  OpenInNotebook()
  var candidates = wikijump#Complete(0, '')
  var words = map(copy(candidates), (_, c) => c.word)
  assert_true(index(words, 'foo') >= 0)
  assert_true(index(words, 'bar') >= 0)
  assert_true(index(words, 'index') >= 0)
  bwipeout!
enddef

def g:Test_Complete_excludes_underscore_dirs()
  OpenInNotebook()
  var candidates = wikijump#Complete(0, '')
  var words = map(copy(candidates), (_, c) => c.word)
  assert_equal(-1, index(words, 'skip'))
  bwipeout!
enddef

def g:Test_Complete_filters_by_base()
  OpenInNotebook()
  var candidates = wikijump#Complete(0, 'fo')
  var words = map(copy(candidates), (_, c) => c.word)
  assert_true(index(words, 'foo') >= 0)
  assert_equal(-1, index(words, 'bar'))
  bwipeout!
enddef

def g:Test_Completefunc_installed_in_notebook_markdown()
  execute 'edit' fnameescape(FIX .. '/notebook/index.md')
  assert_equal('wikijump#Complete', &l:completefunc)
  bwipeout!
enddef

def g:Test_Completefunc_preserves_existing_value()
  set completefunc=
  # Pretend the user already has a completefunc; verify ftplugin leaves it.
  execute 'edit' fnameescape(FIX .. '/outside/random.md')
  setlocal completefunc=MyOwnComplete
  execute 'edit' fnameescape(FIX .. '/notebook/index.md')
  setlocal completefunc=MyOwnComplete
  setfiletype markdown
  doautocmd FileType markdown
  assert_equal('MyOwnComplete', &l:completefunc)
  bwipeout!
  bwipeout!
enddef

def g:Test_Plug_mapping_exists_in_notebook_buffer()
  execute 'edit' fnameescape(FIX .. '/notebook/index.md')
  assert_match('wikijump#TriggerComplete',
        \ maparg('<Plug>(wikijump-complete)', 'i'))
  bwipeout!
enddef

def g:Test_Complete_dedupes_basename_collisions()
  var nb = tempname()
  mkdir(nb .. '/a', 'p')
  mkdir(nb .. '/b', 'p')
  writefile([], nb .. '/.wikijump')
  writefile([], nb .. '/a/foo.md')
  writefile([], nb .. '/b/foo.md')
  execute 'edit' fnameescape(nb .. '/a/foo.md')
  var candidates = wikijump#Complete(0, '')
  var foo_count = 0
  for c in candidates
    if c.word ==# 'foo'
      foo_count += 1
    endif
  endfor
  assert_equal(1, foo_count)
  bwipeout!
  delete(nb, 'rf')
enddef
