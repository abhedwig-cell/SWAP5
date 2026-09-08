#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def normalized(path: Path) -> str:
    return re.sub(r"\s+", " ", path.read_text(encoding="utf-8")).strip().lower()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"F-GC02_BLOCKER_GATE FAIL: {message}")


def main(root: Path) -> None:
    backend = normalized(root / "src/runtime/mod_fmr_serialized_reference_backend.f90")
    legacy_binding = normalized(root / "src/adapter/mod_reference_richards_legacy_binding.f90")
    state_binding = normalized(root / "src/solver/mod_reference_richards_state_binding.f90")
    headcalc = normalized(root / "src/legacy/b1_10_port/headcalc.f90")
    orchestrator = normalized(root / "src/runtime/mod_fmr_checkpoint_orchestrator.f90")

    blocker_path = root / "integration/f-gc/F-GC02_OWNER_BLOCKER.json"
    blocker = json.loads(blocker_path.read_text(encoding="utf-8"))

    require(
        "parameters%bottom_mode == 7 .or. parameters%bottom_mode == -2" in backend,
        "F-MR restricted physical admission no longer matches the source-bound 7/-2 expectation",
    )
    require(
        "if (swbotb /= 7 .and. swbotb /= -2) then" in legacy_binding
        and "legacy-bottom-mode-deferred" in legacy_binding,
        "F-SI legacy binding no longer fails closed outside the qualified 7/-2 route",
    )
    require(
        "else if (swbotb == 7 .or. swbotb == -2) then" in headcalc
        and "free drainage option" in headcalc,
        "HeadCalc 7/-2 free-drainage semantics changed",
    )
    require(
        "swbotb == 5" in headcalc and "pressure head at lower boundary specified" in headcalc,
        "HeadCalc lower-head route is missing or changed",
    )
    require(
        "state%hbot = request%boundary%bottom_head" in state_binding,
        "explicit request bottom_head is no longer bound to the lower-head carrier",
    )
    require(
        all(name in orchestrator for name in (
            "fmr_capture_checkpoint",
            "fmr_trial_from_checkpoint",
            "fmr_commit_candidate",
            "fmr_discard_candidate",
        )),
        "candidate-only checkpoint orchestration seam is missing",
    )
    require(
        blocker.get("status") == "BLOCKED_ON_QUALIFIED_PHYSICAL_GROUNDWATER_BOUNDARY",
        "persisted blocker status does not fail closed",
    )
    require(
        blocker.get("minimum_owner_capability_required", {}).get("F-KT_work") == "NONE currently required",
        "blocker unexpectedly assigns transaction-seam work to F-KT",
    )

    print("F-GC02_CHECKPOINT_CANDIDATE_SEAM=AVAILABLE")
    print("F-GC02_ADMITTED_BOTTOM_MODES=7,-2")
    print("F-GC02_ADMITTED_BOTTOM_SEMANTICS=FREE_DRAINAGE")
    print("F-GC02_EXPLICIT_LOWER_HEAD_ROUTE=EXISTS_IN_HEADCALC_NOT_ADMITTED")
    print("F-GC02_REQUIRED_OWNER_WORK=F-SI,F-MR")
    print("F-GC02_BLOCKER_GATE PASS")


if __name__ == "__main__":
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
    main(root)
