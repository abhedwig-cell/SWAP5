#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Resolve transitive USE dependencies from the actual pinned repository tree.
# A hand-maintained subset went stale when F-KT acquired directional
# publication and WOFOST rate-table dependencies. Never use stub .mod files.
mapfile -t SOURCES < <(python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys
root = Path(sys.argv[1])
mod_pattern = re.compile(r'^\s*module\s+(?!procedure\b|function\b|subroutine\b)([a-z][\w]*)', re.I | re.M)
use_pattern = re.compile(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?([a-z][\w]*)', re.I | re.M)
source = {}
by_module = {}
for path in sorted((root / 'src').rglob('*.f90')):
    contents = path.read_text(encoding='utf-8', errors='replace')
    uses = [m.lower() for m in use_pattern.findall(contents)]
    source[path] = uses
    for name in mod_pattern.findall(contents):
        key = name.lower()
        if key in by_module and by_module[key] != path:
            raise SystemExit(f'duplicate source module {key}: {by_module[key]} and {path}')
        by_module[key] = path

targets = ['mod_crop_lifecycle_continuation']
active = set()
visited = set()
ordered = []
def visit(mod):
    if mod not in by_module:
        if mod.startswith('mod_'):
            raise SystemExit(f'missing required source module: {mod}')
        return
    path = by_module[mod]
    if path in visited:
        return
    if path in active:
        raise SystemExit(f'cyclic Fortran USE dependency at {path}')
    active.add(path)
    for dep in source[path]:
        visit(dep)
    active.remove(path)
    visited.add(path)
    ordered.append(path.relative_to(root))

for target in targets:
    visit(target)
for path in ordered:
    print(path)
PY
)
if (("${#SOURCES[@]}" < 8)); then
  echo 'Lifecycle dependency discovery returned too few production source modules' >&2
  exit 1
fi
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace)
for OPT in 0 2; do
  mkdir -p "$BUILD/o$OPT"
  (
    cd "$BUILD/o$OPT"
    for SOURCE in "${SOURCES[@]}"; do
      gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$OPT" -J . -I . -c "$ROOT/$SOURCE"
    done
    gfortran "${COMMON[@]}" -O"$OPT" -J . -I . \
      "$ROOT/tests/fmig431/test_crop_lifecycle_continuation.f90" ./*.o -o test
    ./test > output
  )
  grep -Fx 'SW431_CROP_LIFECYCLE_CONTINUATION=PASS' "$BUILD/o$OPT/output"
done
cmp "$BUILD/o0/output" "$BUILD/o2/output"
echo 'SW431_CROP_LIFECYCLE_CONTINUATION_O0_O2=PASS'
