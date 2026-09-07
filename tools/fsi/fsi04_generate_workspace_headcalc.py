#!/usr/bin/env python3
"""Generate the F-SI04 workspace-backed HeadCalc candidate from the exact canonical source.

The source file is never modified. This tool is deliberately fail-closed: each
structural edit must match exactly once and each scratch token must occur at
least once. Richards equations and numerical-policy expressions are otherwise
left untouched.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

PINNED_HEADCALC_BLOB = "225b9f2cc1ecff01414b5691799103b92bc068c5"

DECLARATIONS = [
    r"^\s*real\(8\),\s*dimension\(macp\)\s*::\s*dFdhL,\s*dFdhM,\s*dFdhU.*\n",
    r"^\s*real\(8\),\s*dimension\(macp\)\s*::\s*difh,\s*F.*\n",
    r"^\s*real\(8\),\s*dimension\(macp\)\s*::\s*sink,\s*source.*\n",
    r"^\s*real\(8\),\s*dimension\(macp\)\s*::\s*hold\s*\n",
    r"^\s*real\(8\),\s*dimension\(macp\+1\)\s*::\s*qv,\s*hgrad\s*\n",
    r"^\s*logical,\s*dimension\(macp\)\s*::\s*flnonconv1,\s*flnonconv2\s*\n",
    r"^\s*logical,\s*dimension\(3\)\s*::\s*flunsatok.*\n",
]

TOKEN_MAP = [
    (r"ctx%headcalc%dkdh", "fsi_workspace%dconductivity_dhead"),
    (r"\bdFdhL\b", "fsi_workspace%dfdh_lower"),
    (r"\bdFdhM\b", "fsi_workspace%dfdh_main"),
    (r"\bdFdhU\b", "fsi_workspace%dfdh_upper"),
    (r"\bdifh\b", "fsi_workspace%delta_head"),
    (r"\bF\b", "fsi_workspace%residual"),
    (r"\bsink\b", "fsi_workspace%sink"),
    (r"\bsource\b", "fsi_workspace%source"),
    (r"\bhold\b", "fsi_workspace%old_head"),
    (r"\bqv\b", "fsi_workspace%vertical_flux"),
    (r"\bhgrad\b", "fsi_workspace%head_gradient"),
    (r"\bflnonconv1\b", "fsi_workspace%nonconverged_balance"),
    (r"\bflnonconv2\b", "fsi_workspace%nonconverged_head"),
    (r"\bflunsatok\b", "fsi_workspace%unsaturated_flags"),
]


def replace_once(text: str, pattern: str, replacement: str, label: str) -> tuple[str, int]:
    out, count = re.subn(pattern, replacement, text, count=1, flags=re.IGNORECASE | re.MULTILINE)
    if count != 1:
        raise SystemExit(f"F-SI04 transform mismatch for {label}: expected 1, got {count}")
    return out, count


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()

    text = args.source.read_text(encoding="utf-8")
    original = text
    counts: dict[str, int] = {}

    text, counts["signature"] = replace_once(
        text,
        r"^subroutine\s+headcalc\s*\(worker\)\s*$",
        "subroutine headcalc(worker, fsi_workspace)",
        "signature",
    )
    text, counts["workspace_use"] = replace_once(
        text,
        r"^(\s*use\s+mod_a23bu_worker_execution_context.*)$",
        r"\1\n   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace",
        "workspace use",
    )
    text, counts["workspace_argument"] = replace_once(
        text,
        r"^(\s*type\(a23bu_worker_context_t\),\s*target,\s*intent\(inout\),\s*optional\s*::\s*worker\s*)$",
        r"\1\n   type(reference_richards_workspace_t), intent(inout) :: fsi_workspace",
        "workspace argument",
    )

    for idx, pattern in enumerate(DECLARATIONS, start=1):
        text, count = re.subn(pattern, "", text, count=1, flags=re.IGNORECASE | re.MULTILINE)
        if count != 1:
            raise SystemExit(f"F-SI04 declaration removal {idx}: expected 1, got {count}")
        counts[f"declaration_{idx}"] = count

    text, counts["workspace_init"] = replace_once(
        text,
        r"^(\s*if\s*\(ctx%active_nodes\s*/=\s*numnod\)\s*call\s+a23bu_initialize_worker\(ctx,\s*numnod\)\s*)$",
        r"\1\n   call initialize_reference_workspace(fsi_workspace, numnod)",
        "workspace initialization",
    )

    # hgrad is a HeadCalc scratch array but was also passed as a formal argument
    # to the internal vector_F routine. On the workspace path vector_F accesses
    # the same storage through host association. No residual expression changes.
    text, counts["vector_f_signature"] = replace_once(
        text,
        r"^subroutine\s+vector_F\s*\(iTask,\s*hgrad\)\s*$",
        "subroutine vector_F(iTask)",
        "vector_F signature",
    )
    text, counts["vector_f_hgrad_declaration"] = replace_once(
        text,
        r"^\s*real\(8\),\s*dimension\(macp\+1\)\s*::\s*hgrad\s*$",
        "",
        "vector_F hgrad declaration",
    )
    for task in (1, 2):
        text, count = re.subn(
            rf"call\s+vector_F\s*\(\s*{task}\s*,\s*hgrad\s*\)",
            f"call vector_F({task})",
            text,
            count=1,
            flags=re.IGNORECASE,
        )
        if count != 1:
            raise SystemExit(f"F-SI04 vector_F call task {task}: expected 1, got {count}")
        counts[f"vector_f_call_{task}"] = count

    # Replace only Fortran identifier tokens. Comments may change too; executable
    # expressions are otherwise preserved character-for-character.
    for pattern, replacement in TOKEN_MAP:
        text, count = re.subn(pattern, replacement, text, flags=re.IGNORECASE)
        if count <= 0:
            raise SystemExit(f"F-SI04 scratch token not found: {pattern}")
        counts[replacement] = count

    # The rare banded fallback remains local in this slice and is explicitly
    # held for the next slice. Do not silently claim complete linear-solve scratch.
    for token in ("real(8), dimension(macp,3) :: a", "real(8), dimension(macp,1) :: a1", "integer, dimension(macp)   :: indx"):
        if token.lower() not in text.lower():
            raise SystemExit(f"F-SI04 expected fallback-local declaration missing: {token}")

    if text == original:
        raise SystemExit("F-SI04 generated source unexpectedly unchanged")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text, encoding="utf-8")

    manifest = {
        "work_unit": "F-SI04",
        "source": str(args.source),
        "output": str(args.output),
        "pinned_headcalc_blob": PINNED_HEADCALC_BLOB,
        "edits": counts,
        "fallback_banded_scratch_local": True,
        "physics_formula_change_intended": False,
        "numerical_policy_change_intended": False,
    }
    if args.manifest:
        args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    else:
        print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
