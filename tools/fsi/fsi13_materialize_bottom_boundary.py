#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
HEADCALC = ROOT / "src/legacy/b1_10_port/headcalc.f90"
ADAPTER = ROOT / "src/adapter/mod_reference_richards_legacy_binding.f90"

EXPECTED_HEADCALC_BLOB = "9d19b389c139140de1ec7f880797ebb4edc128e2"
EXPECTED_ADAPTER_BLOB = "15c05cfd288247ac4a1487ae5156e80a0ca430b0"


def blob(path: pathlib.Path) -> str:
    rel = path.relative_to(ROOT).as_posix()
    return subprocess.check_output(["git", "rev-parse", f"HEAD:{rel}"], cwd=ROOT, text=True).strip()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"F-SI13 materializer expected exactly one {label}, found {count}")
    return text.replace(old, new, 1)


def patch_headcalc() -> None:
    if blob(HEADCALC) != EXPECTED_HEADCALC_BLOB:
        raise SystemExit("F-SI13 source guard: HeadCalc is not the qualified F-SI12 blob")
    text = HEADCALC.read_text()

    text = replace_once(
        text,
        "use variables,          only: fldaystart, swbotb, runon, epd, reva, pondm1, legacy_dt => dt, runots, t1900, thetm1, qrot,",
        "use variables,          only: fldaystart, legacy_swbotb => swbotb, runon, epd, reva, pondm1, legacy_dt => dt, runots, t1900, thetm1, qrot,",
        "HeadCalc swbotb import",
    )
    text = replace_once(
        text,
        "integer                          :: swkimpl, swkmean, maxit, maxbacktr",
        "integer                          :: swbotb, swkimpl, swkmean, maxit, maxbacktr",
        "HeadCalc local swbotb declaration",
    )
    text = replace_once(
        text,
        "   dt = legacy_dt\n   swkimpl = legacy_swkimpl",
        "   swbotb = legacy_swbotb\n   dt = legacy_dt\n   swkimpl = legacy_swkimpl",
        "HeadCalc legacy bottom-mode initialization",
    )
    text = replace_once(
        text,
        "   if (.not. legacy_state_binding) then\n      if (.not. present(numerical_config)) error stop 'HeadCalc: explicit numerical config required'",
        "   if (.not. legacy_state_binding) then\n      if (.not. present(boundary_conditions)) error stop 'HeadCalc: explicit boundary conditions required'\n      swbotb = boundary_conditions%bottom_mode\n      if (.not. present(numerical_config)) error stop 'HeadCalc: explicit numerical config required'",
        "HeadCalc explicit bottom-mode binding",
    )

    HEADCALC.write_text(text)


def patch_adapter() -> None:
    if blob(ADAPTER) != EXPECTED_ADAPTER_BLOB:
        raise SystemExit("F-SI13 source guard: reference adapter is not the qualified F-SI12 blob")
    text = ADAPTER.read_text()

    text = replace_once(
        text,
        "    if (swbotb /= 7 .and. swbotb /= -2) then\n       route = 'legacy-bottom-mode-deferred'\n       return\n    end if",
        "    if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2) then\n       route = 'legacy-bottom-mode-deferred'\n       return\n    end if",
        "adapter request bottom-mode admission",
    )
    text = replace_once(
        text,
        "    if (request%boundary%bottom_mode /= swbotb) then\n       route = 'legacy-bottom-mode-mismatch'\n       return\n    end if\n",
        "",
        "adapter legacy bottom-mode mismatch gate",
    )

    ADAPTER.write_text(text)


def verify_postimage() -> None:
    h = HEADCALC.read_text().lower()
    a = ADAPTER.read_text().lower()
    required_h = [
        "legacy_swbotb => swbotb",
        "integer                          :: swbotb, swkimpl, swkmean, maxit, maxbacktr",
        "swbotb = legacy_swbotb",
        "if (.not. present(boundary_conditions)) error stop 'headcalc: explicit boundary conditions required'",
        "swbotb = boundary_conditions%bottom_mode",
    ]
    for token in required_h:
        if token not in h:
            raise SystemExit(f"F-SI13 postimage missing HeadCalc token: {token}")
    if h.count("swbotb = boundary_conditions%bottom_mode") != 1:
        raise SystemExit("F-SI13 postimage has unexpected explicit bottom-mode assignment count")

    required_a = [
        "if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2) then",
        "route = 'legacy-bottom-mode-deferred'",
    ]
    for token in required_a:
        if token not in a:
            raise SystemExit(f"F-SI13 postimage missing adapter token: {token}")
    if "legacy-bottom-mode-mismatch" in a:
        raise SystemExit("F-SI13 postimage still contains legacy bottom-mode mismatch gate")


if __name__ == "__main__":
    patch_headcalc()
    patch_adapter()
    verify_postimage()
    print("F-SI13_BOTTOM_BOUNDARY_MATERIALIZATION PASS")
