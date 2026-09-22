#!/usr/bin/env python3
"""C6R research-only reference-floor admission repair.

The frozen public reference-floor wrapper rejects root_extraction_active before
the kernel is entered. C6R requires a prescribed root sink held fixed during
one Reference solve per preregistered transaction. This script removes only that
wrapper-level root-active rejection in a working checkout. It does not alter
Reference Richards, HeadCalc, Feddes, the root-sink provider, numerical
tolerances, retry policy, or any repository production source.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

FROZEN_BACKEND_GIT_BLOB = "9bd344a83afd5e10b96178933362dbb7eeea4f30"
START = "  subroutine fmr_serialized_backend_run_reference_floor_sample"
END = "  end subroutine fmr_serialized_backend_run_reference_floor_sample"
OLD = """        parameters%soil_temperature_active .or. parameters%root_extraction_active .or. &
        parameters%macropore_active .or. parameters%drainage_response_active .or. &"""
NEW = """        parameters%soil_temperature_active .or. &
        parameters%macropore_active .or. parameters%drainage_response_active .or. &"""
MARKER = "C6R_RESEARCH_ROOT_FLOOR_ADMISSION_REPAIR"


def git_blob(data: bytes) -> str:
    h = hashlib.sha1()
    h.update(f"blob {len(data)}\0".encode())
    h.update(data)
    return h.hexdigest()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", required=True, type=Path)
    ap.add_argument("--manifest", type=Path)
    args = ap.parse_args()

    before = args.path.read_bytes()
    before_blob = git_blob(before)
    text = before.decode()

    if MARKER in text:
        # Idempotent invocation in a job that compiles multiple optimization routes.
        after = before
        state = "ALREADY_PATCHED"
    else:
        if before_blob != FROZEN_BACKEND_GIT_BLOB:
            raise SystemExit(
                f"unexpected frozen backend blob {before_blob}; expected {FROZEN_BACKEND_GIT_BLOB}"
            )
        i = text.find(START)
        j = text.find(END, i)
        if i < 0 or j < 0:
            raise SystemExit("reference-floor wrapper block not found")
        block = text[i:j]
        if block.count(OLD) != 1:
            raise SystemExit(f"expected exactly one root-active floor gate, found {block.count(OLD)}")
        repaired = block.replace(
            OLD,
            NEW + "\n    ! " + MARKER + ": wrapper admission only; scientific providers unchanged.",
            1,
        )
        after_text = text[:i] + repaired + text[j:]
        after = after_text.encode()
        args.path.write_bytes(after)
        state = "PATCHED"

    out = {
        "schema": "swap5.lare.bc2.c6r.reference-floor-repair-materialization.v1",
        "state": state,
        "source_path": str(args.path),
        "frozen_backend_git_blob": FROZEN_BACKEND_GIT_BLOB,
        "input_git_blob": before_blob,
        "output_git_blob": git_blob(after),
        "output_sha256": sha256(after),
        "changed_semantics": [
            "research-local fmr_serialized_backend_run_reference_floor_sample admits root_extraction_active"
        ],
        "unchanged_semantics": [
            "Reference Richards and HeadCalc",
            "Feddes root-water-uptake process",
            "b110_root_sink_provider_t",
            "single physical advance per reference-floor transaction",
            "mass tolerance and mass accounting",
            "retry policy",
            "all non-root reference-floor admission guards"
        ],
        "production_source_persisted": False,
        "response_based": False
    }
    if args.manifest:
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        args.manifest.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(json.dumps(out, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
