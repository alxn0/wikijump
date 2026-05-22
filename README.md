# wikijump.vim

A Vim9 plugin for following and creating `[[wikilinks]]` in markdown
notebooks. Single-buffer, opinionated, and small.

## What it does

- Press `<CR>` on a `[[wikilink]]` to open it. Basename resolution across
  the notebook, anchor jump on `[[foo#some-heading]]`, alias display on
  `[[foo|Friendly Name]]`.
- Missing target? Opens an empty buffer at `<root>/<basename>.md`. Save
  to create.
- `:WikijumpNext` / `:WikijumpPrev` cycle through wikilinks in the
  buffer (markdown `[](…)` links are skipped).
- `:WikijumpIndex` opens the notebook's landing page.
- Inside `[[…`, `<C-x><C-u>` completes notebook basenames.

## What it does not do

`gf` (markdown links), `gx` (URLs), `<C-o>`/`<C-i>` (jumplist), search,
pickers, backlinks, cross-file rename, templates. Those are Vim or other
tools. See [`docs/design.md`](docs/design.md) for the reasoning.

## Install

Requirements: Vim 9.1+. Neovim is not supported (`vim9script` is Vim-only).

With vim-plug:

```vim
Plug 'alxn0/wikijump'
```

Or any other plugin manager that puts a directory on `runtimepath`. Run
`:helptags ALL` after install.

## Make a directory a notebook

```sh
touch .wikijump
```

That's it. The file's first non-blank line, if present, overrides the
landing-page name:

```
README.md
```

## Recommended mappings

The plugin ships only one default mapping: `<CR>` to follow the link
under the cursor (markdown buffers in a notebook). Bind the rest yourself:

```vim
" Tab / Shift-Tab cycle wikilinks (Neovim or GUI; on terminal Vim, <Tab>
" shadows jumplist forward).
augroup wikijump_keys
  autocmd!
  autocmd FileType markdown nmap <buffer> <Tab>   <Cmd>WikijumpNext<CR>
  autocmd FileType markdown nmap <buffer> <S-Tab> <Cmd>WikijumpPrev<CR>
augroup END

" Wiki completion on a dedicated insert-mode key (works regardless of
" what owns &completefunc — useful when an LSP claims it).
imap <C-x>w <Plug>(wikijump-complete)
```

## Configuration

| Variable | Default | Notes |
|---|---|---|
| `g:wj_marker_name`  | `.wikijump` | Notebook sentinel. |
| `g:wj_index_name`   | `index.md`  | Landing page. Per-notebook override: first line of the marker file. |
| `g:wj_stop_markers` | `['.git']`  | Directories (or files) that halt walk-up. |
| `g:wj_autocomplete` | `0`         | When `1`, completion fires automatically inside `[[…`. |

## Test

```sh
make test
```

Runs Vim's built-in test harness against `tests/test_*.vim`. Output goes
to `tmp/test.log` and is echoed to stdout. No external dependencies.

## Docs

- [`:help wikijump`](doc/wikijump.txt) — full reference
- [`docs/user_story.md`](docs/user_story.md) — what it does, in narrative
- [`docs/design.md`](docs/design.md) — why each decision was made

## License

MIT — see [`LICENSE`](LICENSE).
