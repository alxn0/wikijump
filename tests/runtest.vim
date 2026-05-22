vim9script
# Minimal test harness inspired by Vim's own tests/runtest.vim.
#
# Invocation:
#   vim -es -Nu NONE -S tests/runtest.vim tests/test_resolve.vim [...]
#
# Discovers Test_* functions in each sourced file, runs each one. Results
# are written to <project>/tmp/test.log because -es silent mode
# suppresses :echo. Exits non-zero (cquit) if any assertion failed.

const PROJECT_ROOT = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')

g:wj_test_failures = 0
g:wj_test_passes = 0
var test_log: list<string> = []

def Log(line: string)
  add(test_log, line)
enddef

def TestFuncs(): list<string>
  var out: list<string> = []
  var listing = execute('function /^Test_')
  for line in split(listing, '\n')
    # Listing prefix is "def" for vim9 def-functions and "function" for legacy.
    var name = matchstr(line, '^\%(def\|function\) \zs[A-Za-z0-9_#]\+')
    if !empty(name)
      out += [name]
    endif
  endfor
  return out
enddef

def RunFile(path: string)
  var before = TestFuncs()
  execute 'source' fnameescape(path)
  var funcs = filter(TestFuncs(), (_, v) => index(before, v) < 0)

  Log(printf('=== %s (%d tests) ===', path, len(funcs)))
  for fn in funcs
    v:errors = []
    try
      execute 'call' fn .. '()'
    catch
      v:errors += [printf('%s: %s', fn, v:exception)]
    endtry
    if empty(v:errors)
      g:wj_test_passes += 1
      Log(printf('  PASS %s', fn))
    else
      g:wj_test_failures += 1
      Log(printf('  FAIL %s', fn))
      for err in v:errors
        Log('    ' .. err)
      endfor
    endif
  endfor
enddef

for f in argv()
  RunFile(f)
endfor

Log(printf('Total: %d passed, %d failed',
      \ g:wj_test_passes, g:wj_test_failures))

mkdir(PROJECT_ROOT .. '/tmp', 'p')
writefile(test_log, PROJECT_ROOT .. '/tmp/test.log')

if g:wj_test_failures > 0
  cquit
else
  qall
endif
