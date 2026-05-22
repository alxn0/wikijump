# wikijump.vim — what I can do

The plugin gives me a small set of in-buffer affordances for following and creating `[[wikilinks]]` in markdown notebooks. Everything it does stays inside one buffer or moves me between buffers. Multi-file operations are not in its scope.

## Making a directory a notebook

**`touch .wikijump` at the directory's root.** The presence of `.wikijump` is what makes a directory a notebook. The file can be empty, in which case all defaults apply.

**To override the landing page filename for this notebook**, put the filename on the first line:

```
README.md
```

That's the entire format. One filename, one line. Subsequent lines are ignored. Files with leading whitespace are trimmed. If the file is empty or contains only whitespace, the global default (`g:wj_index_name`, itself defaulting to `index.md`) is used.

## Follow links

**I press `<CR>` on a `[[wikilink]]` to open it.** The link under the cursor is parsed, the target is resolved by basename lookup across the notebook (any `.md` file with that name, wherever it lives), and the file opens in the current window. If the cursor is not on a wikilink, the mapping is inert and `<CR>` does its default thing. The same action is exposed as `:WikijumpFollow` for invoking from other mappings or scripts.

**The full wikilink syntax is supported.**

```
[[target]]                    link, display "target"
[[target|Display Text]]       link, display "Display Text"
[[target#heading]]            link to a heading inside target
[[target#heading|Display]]    everything combined
```

The plugin splits on `|` (keeps the left side), then on `#` (keeps the left side again) to extract the target basename. The display text is for rendering tools (Obsidian, previewers); when following from vim, only the target matters.

**For `[markdown](links.md)` I use `gf`.** Vim's built-in "go to file" already handles relative paths and, with `suffixesadd+=.md` set in markdown buffers, finds `[foo](bar)` as `bar.md`. The plugin does not reimplement this.

**For URLs I use `gx`.** Vim's built-in opens the URL under the cursor in the system browser. Works on both bare URLs and the URL inside `[text](https://…)`. The plugin does not reimplement this either.

**I press `<C-o>` to go back.** This is Vim's built-in jump-list navigation — no custom mapping needed. Because follow uses `:edit`, every link traversal pushes to the jumplist for free. `<C-i>` goes forward again.

**If the wikilink target does not exist, the buffer opens empty in the notebook root.** Saving it creates the file there. This lets me write a link, follow it, and start the new page in one motion — no separate "create" step.

**Anchor jumps land on the matching heading.** After opening the file, the plugin searches for the first `#`/`##`/`###`/etc. heading whose text matches the anchor. Matching is case-insensitive and treats hyphens in the anchor as spaces, so `[[notes#some-heading]]` finds `## Some Heading`. The matched line is centered in the window. If no heading matches (or the target file is empty, e.g. just created), the cursor stays at the top — silent, no error.

## Move between links in a buffer

**`:WikijumpNext` jumps to the next `[[wikilink]]` in the buffer.** Search wraps around the end so repeated invocations cycle through every wikilink in the file. Markdown links are skipped — they are not the plugin's domain; use `/](` to find them with Vim's regular search.

**`:WikijumpPrev` jumps to the previous link.** Same behavior in the other direction.

These are exposed as commands rather than default mappings. I bind them myself in my config — typically `<Tab>` / `<S-Tab>` in markdown buffers — so I keep control of which keys this layer claims. On terminal Vim, `<Tab>` shadows `<C-i>` (jumplist forward); on Neovim and GUI Vim the two are distinct.

## Open the landing page

**`:WikijumpIndex` opens the notebook's landing page.** Resolution walks up from the current buffer to find the notebook root (the directory with `.wikijump`), then opens the configured landing page there. The filename defaults to `index.md`, overridable per-notebook via the first line of `.wikijump`, or globally via `g:wj_index_name`. If the landing page does not exist, the buffer opens empty and saving creates it — same as link-follow behavior.

A landing page is optional. A notebook with no `index.md` (or whatever it's configured to) is fully functional; `:WikijumpIndex` just creates the file on first use. If the buffer is not inside any notebook, the command errors ("not in a notebook") and does nothing else.

There is no global fallback and no bang variant. If I want a shortcut to a specific notebook from anywhere, I wire it as my own mapping with the explicit path.

## Insert and complete links

**Inside `[[…`, completion proposes notebook pages.** I trigger it with the standard omni-completion key (`<C-x><C-o>`). The list is every `.md` file in the notebook, shown by basename with `.md` stripped — since links are basename-resolved, that's all the information needed to write one. Tab-cycling works as normal.

**Outside `[[…`, completion is not active.** To insert a wikilink, I type `[[` first. This is intentional — polluting general prose completion with note names creates noise. The cost is one extra `[[` keystroke; the benefit is predictable completion behavior everywhere else.

**For markdown links, Vim's built-in filename completion (`<C-x><C-f>`) handles it.** With `path` configured to include the current file's directory, it proposes relative paths. The plugin does not duplicate this.

**`:WikijumpWrap` wraps the visual selection in `[[…]]`.** Useful for converting existing text into a link without retyping. Like the next/previous link commands, it's a command rather than a default mapping — I bind it myself if I want it (`xnoremap <leader>l :WikijumpWrap<CR>` is a typical choice).

## Awareness of where I am

**`:WikijumpRoot` echoes the resolved notebook root.** Useful when I am not sure which notebook a buffer belongs to. Pure debugging — no side effects.

**The status line can show `b:wj_root`.** Optional; off by default. Helps confirm at a glance which notebook is active.

## Configuration

Global variables set in vimrc. The only per-notebook override available is the landing page filename, set as the first line of `.wikijump`.

| Variable | Per-notebook override | Purpose | Default |
|---|---|---|---|
| `g:wj_marker_name` | — | Filename used as the notebook marker. | `'.wikijump'` |
| `g:wj_index_name` | first line of `.wikijump` | Landing page filename, opened by `:WikijumpIndex`. | `'index.md'` |
| `g:wj_stop_markers` | — | Directory contents that halt the walk-up (in addition to `$HOME` and filesystem root, which are implicit). | `['.git']` |

Precedence for the landing page name: notebook `.wikijump` first line → global `g:wj_index_name` → built-in default.