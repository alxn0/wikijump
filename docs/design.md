# Design decisions — wikijump.vim

A record of choices made and the alternatives rejected, so the rationale survives the conversation. Scope: the Vim9 plugin only.

## Scope and boundaries

**The plugin handles `[[wikilinks]]` only.** Vim already provides `gf` (go to file, with `suffixesadd+=.md` for markdown link targets) and `gx` (open URL in system browser). Reimplementing either would duplicate built-in behavior. The plugin's single job is teaching Vim about the one link syntax it doesn't natively understand.

**The plugin touches one buffer at a time, with no exceptions.** Anything that reads or writes multiple files is out of scope: backlink computation, full-text search, tree validation, template instantiation, and renaming. Cross-file rename was briefly in scope (`:WikijumpRename`, which moved the file and rewrote every targeting `[[wikilink]]`) but was removed: a rename is a one-off shell operation (`mv` plus a scripted `rg`/`sed` rewrite over the `:WikijumpRoot`) and does not need to live in the editor. These features each have mature external tools (`rg`, `fzf`, `:WikijumpRoot`-driven shell scripts) that handle them well.

**No search or picker commands.** The plugin ships no `:WikijumpSearch`, no fzf wiring, no telescope integration. Picker choice is personal, and any external tool the user wires up to populate one is their config, not the plugin's.

## Naming

**Plugin: `wikijump.vim`.** Names the action (jumping to wikilinks) rather than the unit (notebook, vault). The plugin's scope is exactly that action plus its prerequisites (resolution, completion). Rejected: `notebook.vim` (overclaims — implies templates, journals, full management), `vault.vim` (borrows Obsidian's term, couples identity to another product), `wikilink.vim` (precise but generic and long).

**Verb: "jump".** Vim's own vocabulary for discontinuous, jumplist-pushing navigation is "jump" (`<C-]>`, `:jumps`, `]m`). Follow uses `:edit`, which pushes to the jumplist. Most other plugins in the space use "Follow" for the same action; the precedent is acknowledged, but "jump" is more Vim-native.

**Commands use the full prefix `Wikijump`; variables use the short prefix `wj_`.** Commands are typed rarely and discovered via `:Wikijump<Tab>`, so legibility wins — `:WikijumpIndex` reads as English. Variables appear in plugin code and user config repeatedly, so terseness wins — `b:wj_root`, `g:wj_index_name` are pleasant to type and read.

## Marker

**The marker is `.wikijump`, a file at the tree's root.** A directory containing `.wikijump` is a tree root; nothing else makes one. Rejected: using `index.md` as the marker. Reasons: `index.md` is a common filename used by many tools and human conventions (Hugo, MkDocs, GitHub web view, ad-hoc directory documentation), so any tree using it for unrelated purposes would silently become a nested tree. A dedicated dot-prefixed marker is collision-free, semantically clear, and follows the precedent of `.git`, `.svn`, `.editorconfig` — file-based markers for tool-defined boundaries.

**The marker filename is configurable via `g:wj_marker_name`** but practically always left at the default. The variable exists for symmetry with the rest of the config surface, not because changing it is encouraged.

**Marker file states form a clean trichotomy:**

- File does not exist → directory is not a tree.
- File exists and is empty (or whitespace-only) → a tree, use all defaults.
- File exists and the first non-blank line is a filename → a tree, that filename overrides `g:wj_index_name` for this tree.

**The format is one filename per file, no other syntax.** Rejected: `key: value` lines, `.env`-style `key=value`, JSON, YAML, TOML. Reasons walked through in conversation: any ad-hoc key-value format requires documenting rules for whitespace, quoting, and edge characters (`=` in filenames, leading spaces), and editor tooling can't help validate it. JSON or YAML would handle arbitrary filenames correctly but introduce parser dependencies and a documentation burden disproportionate to the single setting actually needed. A single filename on one line handles every legal filename (spaces, equals signs, anything but newlines) with zero parsing rules. If a second per-tree setting ever earns its place, the upgrade path is unambiguous: detect a `{` on line 1, parse as JSON; otherwise the legacy first-line-filename interpretation. Migration is one `filereadable` and one character check.

**The parser is eight lines of Vim9.** No regex, no escape handling, no edge cases. Trim the first non-blank line; that's the result.

## Tree resolution

**Resolution walks up, stopping at the first `.wikijump` or a stop marker.** Stop markers (default: `['.git']`, plus implicit `$HOME` and filesystem root, configurable via `g:wj_stop_markers`) bound the walk to a sensible scope and prevent unbounded ascent. No depth counter is needed; the markers guarantee termination.

**A tree is a flat namespace; folders are organizational only.** All `.md` files inside the tree share one address space, addressed by basename. Folders group files visually and on disk but do not affect link resolution. Structure emerges from `[[wikilinks]]`, not from the directory tree — matching the Zettelkasten / Obsidian model. Convention: one `.wikijump` per tree, at the root. A user who places another `.wikijump` in a subfolder creates a separate, nested tree (the walk-up algorithm finds the inner one first). Unlike the previous `index.md`-as-marker design, this only happens deliberately — `.wikijump` is not a name anyone types by accident.

**Wikilinks resolve by basename, not by path.** `[[foo]]` means "any `.md` file named `foo` in the tree." This matches Obsidian's default behavior — no setting flip required for interop. Rejected: path-relative resolution (`<root>/foo.md`, `<root>/sub/foo.md`). Reasons: with a flat namespace, paths in links would duplicate information that doesn't matter; basename links survive file moves between folders for free.

**Wikilink syntax includes display alias and heading anchor.** `[[target]]`, `[[target|Display]]`, `[[target#heading]]`, `[[target#heading|Display]]`. The plugin splits on `|` then on `#` to extract the target basename; everything else is for rendering tools. Full Obsidian syntax adopted because it costs nothing extra and keeps interop seamless.

**Anchor-only links (`[[#heading]]`) jump within the current buffer.** No file is opened or created; the plugin scans the current buffer for the matching heading. Matches Obsidian. An empty target with no anchor is inert.

**A `/` in a wikilink target is rejected with an error.** Enforces the flat-namespace contract at follow time — `[[foo/bar]]` almost always means a path was pasted into a wikilink by mistake. (Backslash and brackets can't reach a parsed target; the link pattern's character class already excludes them.)

**Anchor matching is case-insensitive with hyphens treated as spaces.** `[[notes#some-heading]]` matches `## Some Heading`, `### some heading`, and any other heading whose normalized text equals "some heading". Headings inside fenced code blocks are skipped. First match wins; the matched line is centered in the window. Missing anchors fail silently (cursor stays at top). Matches Obsidian's behavior, which is the only behavior that makes round-trip anchor links work without surprises. Block references (`^block-id`) are not supported — power-user feature, easy to add later if needed.

**Basename collisions are first-match-wins.** Two files sharing a basename make `[[name]]` ambiguous; the plugin opens whichever match Vim's `glob()` returns first (filesystem traversal order). This is pragmatic but nondeterministic, so the design relies on the user maintaining unique basenames. Detecting collisions is out of scope for the plugin — surface it to whatever external validation the user runs.

## Landing page

**The landing page is optional.** A tree with no landing file is fully functional; the plugin's resolution, follow, completion, and link navigation all work without one. The landing page is a user-affordance, not a structural requirement.

**`:WikijumpIndex` opens the landing page, creating it on save if absent.** Same create-on-save behavior as link follow. The filename defaults to `README.md`, overridable per-tree via the first line of `.wikijump`, or globally via `g:wj_index_name`. Rejected: requiring the landing page to exist for the tree to be valid. Reasons: with `.wikijump` as the marker, the tree's identity is fully captured by the marker — the landing page is a separate concern and shouldn't be conflated.

## Self-contained operation

**The plugin resolves the root itself.** No external process is invoked for resolution; walk-up is implemented in pure Vim9. Fork/exec on every `BufEnter` would be wasted cost for a few `filereadable` checks. The convention (`.wikijump` marker) is the contract — any other tool reading the same tree independently walks the same way.

**State is buffer-local and computed on `BufEnter`.** `b:wj_root` is set once per buffer, not recomputed per command. `b:wj_index_name` is read from `.wikijump` at the same time and cached. Renaming the file or editing `.wikijump` from outside the editor invalidates the cache — accepted as a known limitation.

## Navigation

**`<CR>` follows the wikilink under the cursor.** Buffer-local, active only when `b:wj_root` is set, so it does not bleed into markdown buffers outside a tree. The same action is exposed as `:WikijumpFollow` for invoking from other mappings or scripts.

**Back navigation uses Vim's jumplist (`<C-o>` / `<C-i>`), not a custom stack.** Because follow uses `:edit`, every traversal pushes to the jumplist for free. Rejected: a wiki.vim-style `<BS>` mapping that returns the cursor exactly to the source `[[link]]`. Reasons: avoids overriding `<C-o>`/`<C-i>`, keeps the surface small, costs nothing to implement. Hub-and-spoke navigation (scanning many links from one index) is slightly less smooth — revisit if it becomes friction in practice.

**No default mappings for next/previous link.** Exposed as `:WikijumpNext` and `:WikijumpPrev`. The user binds them (typically `<Tab>` / `<S-Tab>` in markdown buffers). Rationale: the plugin is stingy about claiming keys; each mapping it grabs is one the user cannot bind themselves. Tab specifically is risky on terminal Vim where it shadows `<C-i>` — leaving the binding to the user makes that tradeoff explicit.

**No intra-buffer link override of `<C-o>`/`<C-i>`.** wiki.vim repurposes them for prev/next link inside the buffer. Rejected: Vim's jumplist is too useful to lose, and `:WikijumpNext` / `:WikijumpPrev` cover the use case via a key the user picks.

## Completion

**Completion activates only inside `[[…`.** Rejected: surfacing file names in general keyword completion (`<C-n>`). Reasons: pollution of prose completion with file names creates noise; the explicit `[[` prefix is a clear signal of intent and costs one keystroke.

**Completion lives on `completefunc` (`<C-x><C-u>`), not `omnifunc` (`<C-x><C-o>`).** `omnifunc` is left untouched — that slot belongs to LSPs and language-specific completion, which a user is far more likely to want in a markdown buffer. Rejected: claiming `omnifunc`, which the original design assumed.

**`completefunc` is installed only when the slot is free.** If an LSP or other plugin already owns `completefunc`, the plugin does not clobber it. For that case (and any time the user wants completion on a key of their choosing), `<Plug>(wikijump-complete)` invokes wikilink completion directly regardless of what owns the slot; the user binds it themselves.

**Auto-trigger is opt-in via `g:wj_autocomplete`.** Default off. When set to `1`, completion fires automatically while typing inside `[[…` (on `TextChangedI`). The global is re-checked on every keystroke, so it can be toggled at runtime without re-sourcing the ftplugin.

**For markdown link paths, Vim's built-in filename completion (`<C-x><C-f>`) is used.** No plugin code. Same principle as `gf` for following — don't reimplement what Vim does natively.

**Completion source is computed on demand via `glob()`, not cached.** Trees of a few thousand files complete fast enough. Caching is a future optimization keyed on directory mtime if it becomes necessary.

## Commands and bang semantics

**`:WikijumpIndex` is purely local — no global fallback, no bang variant.** Resolution walks up from the current buffer; the nearest `.wikijump` wins. If the buffer is outside any tree, the command errors. Rationale: when editing a file inside a tree, walk-up naturally finds the right root — no fallback logic needed. When editing a file outside any tree, opening "some other" landing page is a personal shortcut, not a command's responsibility; the user wires their own mapping if they want it. Rejected: an earlier design where bare `:WikijumpIndex` fell back to a configured global tree and `:WikijumpIndex!` forced it. Reasons: location-driven tools should stay location-driven; the bang variant was extra surface for a case better handled by user mapping.

**No bang variants on any current command.** None of `:WikijumpIndex`, `:WikijumpRoot`, `:WikijumpFollow`, `:WikijumpNext`, `:WikijumpPrev` has a meaningful global/local distinction. The bang convention is held in reserve for a future command that genuinely needs it; it is not used decoratively.

## File organization conventions

**Files under directories with a leading underscore or dot (e.g. `_templates/`, `.archive/`) are excluded from completion and `:WikijumpNext`/`:WikijumpPrev` scans.** Standard convention for "this isn't part of the tree's public surface." Obsidian's "Excluded files" setting hides them from search there too. The plugin honors this by skipping such paths during `glob()`.

## Configuration

The plugin's complete configuration surface.

| Variable | Per-tree override | Purpose | Default |
|---|---|---|---|
| `g:wj_marker_name` | — | Filename used as the marker. | `'.wikijump'` |
| `g:wj_index_name` | first line of `.wikijump` | Landing page filename, opened by `:WikijumpIndex`. | `'README.md'` |
| `g:wj_stop_markers` | — | Directory contents (in addition to `$HOME` and filesystem root, which are implicit) that halt the walk-up resolution. | `['.git']` |
| `g:wj_autocomplete` | — | When `1`, completion fires automatically inside `[[…`. | `0` |

Globals set in vimrc; the only per-tree override is the landing page filename, taken from the first non-blank line of `.wikijump`. Precedence: marker field → global → built-in default. Anything not listed is not configurable. Adding configuration is a deliberate act, weighed against the cost of an additional surface to document and maintain.

## Obsidian interop

**Passive compatibility on files and links; the tree boundary is wikijump-only.** Markdown is markdown; `[[wikilinks]]` are native to Obsidian; basename resolution matches Obsidian's default. Aliases and anchors round-trip without setting changes. The `.wikijump` marker is invisible to Obsidian — that's fine, since Obsidian defines vaults by what folder you point it at, not by any in-folder marker. The two tools agree on what every link means; they reach that agreement through different mechanisms.

**`.obsidian/` is gitignored.** Each machine maintains its own Obsidian config. Revisit if a specific plugin needs to be portable.

**Flat namespace matches Obsidian's model.** Both treat the tree as a single address space where every file is reachable by name.

## Things deliberately not done

- **No nested trees as a design feature.** One `.wikijump` per folder tree. A second `.wikijump` deeper creates a nested tree — possible but never accidental.
- **No path-relative wikilinks.** Basename resolution everywhere, matching Obsidian and surviving file moves.
- **No basename-collision detection inside the plugin.** First-match-wins at follow time; uniqueness is the user's responsibility, surfaced by external tooling.
- **No required landing page.** `:WikijumpIndex` creates the configured file on save if it doesn't exist. A tree with no landing page is valid.
- **No custom back-stack navigation.** Jumplist suffices.
- **No `<BS>` mapping.** Not needed; reserves the key for the user.
- **No `<C-o>` / `<C-i>` override.** Vim's jumplist is sacred.
- **No search or picker commands.** Picker is user config; the plugin ships none.
- **No template instantiation.** Out of scope; plugin only follows, completes, and opens.
- **No backlinks pane or graph view.** Out of scope; Obsidian or external tooling for that.
- **No file-list cache for completion.** Premature.
- **No global fallback on `:WikijumpIndex`.** Location-driven, errors when outside a tree.
- **No structured marker format.** `.wikijump` carries at most one filename on its first line. Beyond that, the file is meaningless. Avoids parser dependencies and edge-case rules; upgrade path to JSON later is unambiguous (detect leading `{`).