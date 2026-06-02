vim9script
# Implementation for wikijump.vim. Loaded on first call via autoload.

# Wiki back-history: a stack of source locations, one per file-changing
# follow. Each entry is {path, lnum, col} where col is the followed link's
# col_start (the `[[`), so Back() can park the cursor on the link and a
# subsequent <CR> re-follows it forward. This is the plugin's only persistent
# module-level state; everything else is buffer-local and recomputed.
var back_stack: list<dict<any>> = []

# True when the current buffer sits inside a resolved tree (b:wj_root set).
def HasRoot(): bool
  return exists('b:wj_root') && !empty(b:wj_root)
enddef

# ---------- Tree resolution ----------

# Walk up from `start` looking for the marker file. Stop at any directory in
# g:wj_stop_markers, at $HOME, or at the filesystem root. Returns the
# root path (containing the marker) or empty string.
export def FindRoot(start: string): string
  var marker = g:wj_marker_name
  var stops = g:wj_stop_markers
  var home = resolve(expand('$HOME'))

  var dir = resolve(fnamemodify(start, ':p'))
  if !isdirectory(dir)
    dir = fnamemodify(dir, ':h')
  endif

  while !empty(dir)
    if filereadable(dir .. '/' .. marker)
      return dir
    endif
    for stop in stops
      if isdirectory(dir .. '/' .. stop) || filereadable(dir .. '/' .. stop)
        return ''
      endif
    endfor
    if dir ==# home
      return ''
    endif
    var parent = fnamemodify(dir, ':h')
    if parent ==# dir
      return ''
    endif
    dir = parent
  endwhile
  return ''
enddef

# Read the first non-blank line of <root>/<marker>, trimmed.
# Returns empty string if the file is empty or whitespace-only.
export def ReadIndexName(root: string): string
  var path = root .. '/' .. g:wj_marker_name
  if !filereadable(path)
    return ''
  endif
  for line in readfile(path)
    var trimmed = trim(line)
    if !empty(trimmed)
      return trimmed
    endif
  endfor
  return ''
enddef

# Precedence: marker field -> g:wj_index_name -> 'README.md'.
export def ResolveIndexName(root: string): string
  var from_marker = ReadIndexName(root)
  return !empty(from_marker) ? from_marker : g:wj_index_name
enddef

# ---------- Wikilink parsing ----------

const LINK_PATTERN = '\[\[[^\]\[\n]\+\]\]'

# Return the [[wikilink]] under the cursor as a dict
#   {target, anchor, display, col_start, col_end}
# or empty dict when the cursor is not inside one.
export def LinkUnderCursor(): dict<any>
  var line = getline('.')
  var col = col('.')
  var start = 0
  while true
    var m = matchstrpos(line, LINK_PATTERN, start)
    var text = m[0]
    var s = m[1]
    var e = m[2]
    if s < 0
      return {}
    endif
    # Vim column is 1-based; matchstrpos returns 0-based byte positions.
    # The link spans bytes [s, e), so cursor column in [s+1, e] is "inside".
    if col >= s + 1 && col <= e
      var inner = text[2 : -3]
      var display = inner
      var pipe = stridx(inner, '|')
      if pipe >= 0
        display = inner[pipe + 1 :]
        # Guard pipe==0 so we don't fall into Vim's [:-1] = full-string slice.
        inner = pipe == 0 ? '' : inner[: pipe - 1]
      endif
      var target = inner
      var anchor = ''
      var hash = stridx(inner, '#')
      if hash >= 0
        target = hash == 0 ? '' : inner[: hash - 1]
        anchor = inner[hash + 1 :]
      endif
      return {
        target: trim(target),
        anchor: trim(anchor),
        display: trim(display),
        col_start: s + 1,
        col_end: e,
      }
    endif
    start = e
  endwhile
  return {}
enddef

# ---------- Navigation ----------

# Jump to the next [[wikilink]] in the buffer, wrapping at end.
export def Next()
  search(LINK_PATTERN, 'w')
enddef

# Jump to the previous [[wikilink]] in the buffer, wrapping at start.
export def Prev()
  search(LINK_PATTERN, 'wb')
enddef

# ---------- Follow ----------

# Resolve a basename to a path under root. Returns empty string when no
# match is found. Paths containing any directory segment starting with `_`
# or `.` (excluding root itself) are excluded.
export def ResolveTarget(root: string, basename: string): string
  if empty(basename)
    return ''
  endif
  var pattern = root .. '/**/' .. EscapeGlobMeta(basename) .. '.md'
  for path in glob(pattern, true, true)
    if !IsExcludedPath(root, path)
      return path
    endif
  endfor
  return ''
enddef

# Wrap glob metacharacters in single-character classes so a wikilink
# target like `foo*` doesn't accidentally pattern-match other files.
def EscapeGlobMeta(s: string): string
  return substitute(s, '[][*?]', '[&]', 'g')
enddef

def IsExcludedPath(root: string, path: string): bool
  var rel = strpart(path, len(root) + 1)
  var dir = fnamemodify(rel, ':h')
  if dir ==# '.'
    return false
  endif
  for segment in split(dir, '/')
    if segment =~# '^[._]'
      return true
    endif
  endfor
  return false
enddef

# Entry point for :WikijumpFollow and the <CR> map. Returns true when a
# link was followed, false when there was nothing to follow.
export def Follow(): bool
  if !HasRoot()
    Error('no .wikijump marker found')
    return false
  endif
  var link = LinkUnderCursor()
  if empty(link)
    return false
  endif
  # Anchor-only links (`[[#section]]`) jump within the current buffer
  # rather than opening or creating a file. Matches Obsidian behavior.
  if empty(link.target)
    if !empty(link.anchor)
      JumpToAnchor(link.anchor)
    endif
    return true
  endif
  # Enforce the flat-namespace contract: wikilinks address files by
  # basename, not by path. A `/` in the target almost always means a
  # stray path was pasted into a wikilink. (`\`, `[`, `]` can't appear
  # in a parsed target — LINK_PATTERN's character class already
  # excludes them.)
  if stridx(link.target, '/') >= 0
    Error('wikilink target cannot contain /: ' .. link.target)
    return false
  endif
  var path = ResolveTarget(b:wj_root, link.target)
  if empty(path)
    path = b:wj_root .. '/' .. link.target .. '.md'
  endif
  # Capture where we came from so <BS> can return here with the cursor parked
  # on the link. Record it only after the :edit succeeds — a failing edit
  # (e.g. E37 on a modified buffer with 'nohidden') must not leave a phantom
  # entry for a hop that never happened. Reached only on a file-changing
  # follow; the no-root, no-link, and anchor-only cases all return above.
  var from = {path: expand('%:p'), lnum: line('.'), col: link.col_start}
  execute 'edit' fnameescape(path)
  add(back_stack, from)
  if !empty(link.anchor)
    JumpToAnchor(link.anchor)
  endif
  return true
enddef

# Find the first heading whose text matches `anchor` (case-insensitive,
# hyphens treated as spaces). Centers the match with `zz`. Silent on miss.
export def JumpToAnchor(anchor: string)
  var needle = NormalizeAnchor(anchor)
  if empty(needle)
    return
  endif
  var in_fence = false
  var last = line('$')
  for lnum in range(1, last)
    var line = getline(lnum)
    if line =~# '^\s*\%(```\|\~\~\~\)'
      in_fence = !in_fence
      continue
    endif
    if in_fence
      continue
    endif
    var heading = matchstr(line, '^\s*#\+\s\+\zs.\{-}\ze\s*$')
    if !empty(heading) && NormalizeAnchor(heading) ==# needle
      cursor(lnum, 1)
      normal! zz
      return
    endif
  endfor
enddef

def NormalizeAnchor(s: string): string
  return tolower(substitute(trim(s), '-', ' ', 'g'))
enddef

# Expression mapping used by the <CR> map: returns either a follow
# invocation that consumes the key, or a literal <CR> so the default
# behavior is preserved off-link.
export def FollowExpr(): string
  if !HasRoot() || empty(LinkUnderCursor())
    return "\<CR>"
  endif
  return ":WikijumpFollow\<CR>"
enddef

# ---------- Back ----------

# Pop the wiki back-history and return to the previous page, parking the
# cursor on the [[wikilink]] that was followed forward (so <CR> re-follows).
# Entries whose file is no longer readable are skipped. The recorded line is
# clamped to the buffer in case it shrank since. Returns true when it
# navigated, false when there was nothing readable to go back to.
export def Back(): bool
  while !empty(back_stack)
    var entry = back_stack[-1]
    if !filereadable(entry.path)
      remove(back_stack, -1)
      continue
    endif
    # Pop only after the :edit succeeds — a failing edit (e.g. E37 on a
    # modified buffer with 'nohidden') must not consume the entry we were
    # trying to return to, so a later <BS> can retry it.
    execute 'edit' fnameescape(entry.path)
    remove(back_stack, -1)
    cursor(min([entry.lnum, line('$')]), entry.col)
    return true
  endwhile
  Error('no previous wiki page')
  return false
enddef

# Expression mapping used by the <BS> map: returns a back invocation that
# consumes the key when there is history, or a literal <BS> so the default
# backspace behavior is preserved when there is nothing to go back to.
export def BackExpr(): string
  if empty(back_stack)
    return "\<BS>"
  endif
  return ":WikijumpBack\<CR>"
enddef

# Reset the back-history. Exported for test isolation; not used at runtime.
export def ClearBackStack()
  back_stack = []
enddef

# ---------- Completion ----------

# Vim completion-function protocol. Lives on `completefunc`; triggered via
# <C-x><C-u> or the <Plug>(wikijump-complete) map.
export def Complete(findstart: number, base: string): any
  if findstart == 1
    return FindCompletionStart()
  endif
  return Candidates(base)
enddef

# Find the column of the first character after `[[` on the current line,
# scanning left from the cursor. Returns -2 (cancel completion) when the
# cursor is not inside an open [[ … ]] span.
def FindCompletionStart(): number
  var line = getline('.')
  # Scan left from the byte just before the cursor. Cursor is 1-based.
  var idx = col('.') - 2
  while idx >= 1
    if line[idx - 1] ==# '[' && line[idx] ==# '['
      # idx is 0-based position of the second '['; the next char is 0-based
      # idx + 1, which is 1-based column idx + 2.
      return idx + 2
    endif
    if line[idx] ==# ']'
      return -2
    endif
    idx -= 1
  endwhile
  return -2
enddef

def Candidates(base: string): list<dict<string>>
  if !HasRoot()
    return []
  endif
  var pattern = b:wj_root .. '/**/*.md'
  var results: list<dict<string>> = []
  var seen: dict<bool> = {}
  for path in glob(pattern, true, true)
    if IsExcludedPath(b:wj_root, path)
      continue
    endif
    var name = fnamemodify(path, ':t:r')
    if has_key(seen, name)
      continue
    endif
    if empty(base) || stridx(tolower(name), tolower(base)) >= 0
      results += [{word: name, kind: 'f', menu: PathMenu(b:wj_root, path)}]
      seen[name] = true
    endif
  endfor
  return results
enddef

def PathMenu(root: string, path: string): string
  var rel = strpart(path, len(root) + 1)
  var dir = fnamemodify(rel, ':h')
  return dir ==# '.' ? '' : dir .. '/'
enddef

# Manual completion trigger used by <Plug>(wikijump-complete). Works
# regardless of what owns &completefunc.
export def TriggerComplete()
  var start = FindCompletionStart()
  if start < 0
    return
  endif
  var base = strpart(getline('.'), start - 1, col('.') - start)
  complete(start, Candidates(base))
enddef

# TextChangedI handler. Checks g:wj_autocomplete on every event so the
# global can be flipped at runtime.
export def MaybeAutoComplete()
  if !get(g:, 'wj_autocomplete', 0)
    return
  endif
  if mode() !=# 'i'
    return
  endif
  var start = FindCompletionStart()
  if start < 0
    return
  endif
  var base = strpart(getline('.'), start - 1, col('.') - start)
  if empty(base)
    return
  endif
  complete(start, Candidates(base))
enddef

# ---------- Index ----------

# Open the tree's landing page in the current window. Filename comes
# from b:wj_index_name (marker field -> g:wj_index_name -> 'README.md').
# Errors when the buffer is not inside a tree.
export def Index()
  if !HasRoot()
    Error('no .wikijump marker found')
    return
  endif
  var path = b:wj_root .. '/' .. b:wj_index_name
  execute 'edit' fnameescape(path)
enddef

# ---------- Diagnostics ----------

# Echo the resolved root for the current buffer. Errors if the
# buffer is not inside any tree.
export def Root()
  if !HasRoot()
    Error('no .wikijump marker found')
    return
  endif
  echo b:wj_root
enddef

def Error(msg: string)
  echohl ErrorMsg
  echomsg 'wikijump: ' .. msg
  echohl None
enddef

# Called from the BufEnter autocmd. Populates buffer-local state when the
# buffer sits inside a tree; clears it otherwise.
export def OnBufEnter()
  # Skip terminal, quickfix, help, command-line, and other non-file
  # buffers. Their `%:p` is a synthetic string ("term://…" etc.) that
  # would walk the resolver up a phantom path.
  if !empty(&buftype)
    unlet! b:wj_root
    unlet! b:wj_index_name
    return
  endif
  var name = expand('%:p')
  if empty(name)
    unlet! b:wj_root
    unlet! b:wj_index_name
    return
  endif
  var root = FindRoot(name)
  if empty(root)
    unlet! b:wj_root
    unlet! b:wj_index_name
    return
  endif
  b:wj_root = root
  b:wj_index_name = ResolveIndexName(root)
enddef
