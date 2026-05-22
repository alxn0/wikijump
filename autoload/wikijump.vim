vim9script
# Implementation for wikijump.vim. Loaded on first call via autoload.

# ---------- Notebook resolution ----------

# Walk up from `start` looking for the marker file. Stop at any directory in
# g:wj_stop_markers, at $HOME, or at the filesystem root. Returns the
# notebook root path (containing the marker) or empty string.
export def FindRoot(start: string): string
  var marker = get(g:, 'wj_marker_name', '.wikijump')
  var stops: list<string> = get(g:, 'wj_stop_markers', ['.git'])
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
  var marker = get(g:, 'wj_marker_name', '.wikijump')
  var path = root .. '/' .. marker
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

# Precedence: notebook field -> g:wj_index_name -> 'index.md'.
export def ResolveIndexName(root: string): string
  var from_marker = ReadIndexName(root)
  if !empty(from_marker)
    return from_marker
  endif
  return get(g:, 'wj_index_name', 'index.md')
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
        inner = inner[: pipe - 1]
      endif
      var target = inner
      var anchor = ''
      var hash = stridx(inner, '#')
      if hash >= 0
        target = inner[: hash - 1]
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
  var pattern = root .. '/**/' .. basename .. '.md'
  for path in glob(pattern, true, true)
    if !IsExcludedPath(root, path)
      return path
    endif
  endfor
  return ''
enddef

def IsExcludedPath(root: string, path: string): bool
  var rel = strpart(path, len(root) + 1)
  for segment in split(fnamemodify(rel, ':h'), '/')
    if segment =~# '^[._]'
      return true
    endif
  endfor
  return false
enddef

# Entry point for :WikijumpFollow and the <CR> map. Returns true when a
# link was followed, false when there was nothing to follow.
export def Follow(): bool
  if !exists('b:wj_root') || empty(b:wj_root)
    Error('not in a notebook')
    return false
  endif
  var link = LinkUnderCursor()
  if empty(link)
    return false
  endif
  var path = ResolveTarget(b:wj_root, link.target)
  if empty(path)
    path = b:wj_root .. '/' .. link.target .. '.md'
  endif
  execute 'edit' fnameescape(path)
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
  var lines = getline(1, '$')
  for i in range(len(lines))
    var heading = matchstr(lines[i], '^\s*#\+\s\+\zs.\{-}\ze\s*$')
    if !empty(heading) && NormalizeAnchor(heading) ==# needle
      cursor(i + 1, 1)
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
  if !exists('b:wj_root') || empty(b:wj_root)
    return "\<CR>"
  endif
  if empty(LinkUnderCursor())
    return "\<CR>"
  endif
  return ":WikijumpFollow\<CR>"
enddef

# ---------- Index ----------

# Open the notebook's landing page in the current window. Filename comes
# from b:wj_index_name (notebook field -> g:wj_index_name -> 'index.md').
# Errors when the buffer is not inside a notebook.
export def Index()
  if !exists('b:wj_root') || empty(b:wj_root)
    Error('not in a notebook')
    return
  endif
  var path = b:wj_root .. '/' .. b:wj_index_name
  execute 'edit' fnameescape(path)
enddef

# ---------- Diagnostics ----------

# Echo the resolved notebook root for the current buffer. Errors if the
# buffer is not inside any notebook.
export def Root()
  if !exists('b:wj_root') || empty(b:wj_root)
    Error('not in a notebook')
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
# buffer sits inside a notebook; clears it otherwise.
export def OnBufEnter()
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
