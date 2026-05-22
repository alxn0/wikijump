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
