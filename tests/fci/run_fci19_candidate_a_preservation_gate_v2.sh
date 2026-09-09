#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate.sh"
TMP="$ROOT/tests/fci/.fci19_candidate_a_v2_$$.sh"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

python3 - "$BASE" "$TMP" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1]).read_text(encoding='utf-8')
src = src.replace('ARTIFACTS="$ROOT/.fci19-artifacts"', 'ARTIFACTS="$ROOT/fci19-artifacts"', 1)
start_anchor = "for marker in \\\n  'FKT09_TRANSACTION_REFERENCE=PASS'"
end_anchor = "\ndone\necho 'FCI19_FKT09_PRESERVATION=PASS'"
start = src.index(start_anchor)
end = src.index(end_anchor, start)
replacement = """for marker in \\
  'FKT09_EXISTING_TRANSACTION_REGRESSION=PASS' \\
  'FKT09_FKT05_CHECKPOINT_REGRESSION=PASS' \\
  'FKT09_MODEL_CERTIFICATE_O0_O2_IDENTITY=PASS' \\
  'FKT09_ATTEMPT_CONTEXT_REGRESSION=PASS' \\
  'FKT09_CANONICAL_CERTIFICATE_COMPOSITION=PASS' \\
  'FKT09_KERNEL_CERTIFICATE_COMMIT_DIAGNOSTICS=PASS' \\
  'FKT09_GENERICITY_GATE=PASS' \\
  'FKT09_MODEL_CERTIFICATE_GATE=PASS'; do
  grep -Fq \"$marker\" \"$ARTIFACTS/fkt09.out\" || fail \"missing F-KT09 marker: $marker\"
done"""
src = src[:start] + replacement + src[end + len('\ndone'):]
Path(sys.argv[2]).write_text(src, encoding='utf-8')
PY
chmod +x "$TMP"
exec "$TMP"
