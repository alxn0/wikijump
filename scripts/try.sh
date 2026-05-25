#!/usr/bin/env sh
# Launch vanilla Vim with only wikijump loaded, on a throwaway notebook.
#
# Vanilla means: no user vimrc, no other plugins (-Nu NONE). Only this
# plugin is put on the runtimepath, so what you see is exactly what a
# fresh install gives a user.
#
# A sample notebook is copied into tmp/ so you can follow, create and
# edit notes without touching the test fixtures. Re-run to get a clean
# copy. Pass extra Vim args after the script name, e.g.:
#   scripts/try.sh +'let g:wj_autocomplete = 1'
set -eu

VIM=${VIM:-vim}
root=$(cd "$(dirname "$0")/.." && pwd)
sandbox="$root/tmp/sandbox"

rm -rf "$sandbox"
mkdir -p "$sandbox"
cp -r "$root/tests/fixtures/notebook/." "$sandbox/"

# -u NONE skips the user's vimrc *and* the auto-sourcing of plugin/ files,
# so we put this plugin on the runtimepath and source it by hand — the same
# idiom the test harness uses.
exec "$VIM" -N -u NONE \
  --cmd "set runtimepath^=$root" \
  --cmd "set runtimepath+=$root/after" \
  --cmd "filetype plugin on" \
  --cmd "syntax on" \
  --cmd "runtime! plugin/wikijump.vim" \
  "$@" \
  "$sandbox/index.md"
