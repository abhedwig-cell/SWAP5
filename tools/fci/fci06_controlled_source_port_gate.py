#!/usr/bin/env python3
"""Fail-closed source/provenance/architecture gate for F-CI06."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PORT = ROOT / "src" / "legacy" / "b1_10_port"
CHECKPOINT = ROOT / "src" / "adapter" / "mod_b1_10_water_checkpoint.f90"
B1_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"

EXPECTED_NORMALIZED = {
    "headcalc.f90": "bca8022c23e90ef35e5330ac43eac0b3b096b5ad32773a10b35589a3a1e5840d",
    "soilwater.f90": "34046a1cb90e11eb7e97e0c188fb6fe6193920bc38e4d246f093390cf0d88cd9",
    "swap.f90": "50c4538c7cf965c41ce2b71db02c231138df56f3ce0280b6bae26a21e1e311c5",
    "swap_main.f90": "51aeb371ef70494bbf0e9749b2dac244f55b51f1dfff0b3200b78b2a37d76408",
}


def norm(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")


def digest(data: bytes) -> str:
    return hashlib.sha256(norm(data)).hexdigest()


def assembled_swap() -> bytes:
    return b"".join((PORT / f"swap_part0{i}.inc").read_bytes() for i in range(1, 5))


def code_without_comments(text: str) -> str:
    return "\n".join(line.split("!", 1)[0] for line in text.splitlines())


def main() -> int:
    checks: dict[str, bool] = {}
    actual: dict[str, str] = {}

    for name in ("headcalc.f90", "soilwater.f90", "swap_main.f90"):
        path = PORT / name
        checks[f"materialized:{name}"] = path.is_file()
        if path.is_file():
            actual[name] = digest(path.read_bytes())
            checks[f"postimage_identity:{name}"] = actual[name] == EXPECTED_NORMALIZED[name]

    wrapper = PORT / "swap.f90"
    checks["materialized:swap.f90"] = wrapper.is_file()
    for i in range(1, 5):
        checks[f"materialized:swap_part0{i}.inc"] = (PORT / f"swap_part0{i}.inc").is_file()
    if all((PORT / f"swap_part0{i}.inc").is_file() for i in range(1, 5)):
        actual["swap.f90"] = digest(assembled_swap())
        checks["postimage_identity:swap.f90"] = actual["swap.f90"] == EXPECTED_NORMALIZED["swap.f90"]
    if wrapper.is_file():
        w = wrapper.read_text(encoding="utf-8")
        checks["swap_wrapper_exact_order"] = all(
            f"include 'swap_part0{i}.inc'" in w for i in range(1, 5)
        ) and w.find("part01") < w.find("part02") < w.find("part03") < w.find("part04")

    head = (PORT / "headcalc.f90").read_text(encoding="utf-8")
    head_code = code_without_comments(head).lower()
    checks["headcalc_optional_worker"] = "optional :: worker" in head.lower()
    checks["headcalc_worker_dkdh"] = "ctx%headcalc%dkdh" in head.lower()
    checks["headcalc_worker_history"] = all(x in head.lower() for x in ("ctx%history%flwarn", "ctx%history%iwarn", "ctx%history%nstep"))
    checks["headcalc_no_saved_dkdh"] = not re.search(r"save\s*::[^\n]*\bdkdh\b", head_code, re.I)
    checks["headcalc_no_saved_warning_history"] = not re.search(r"save\s*::[^\n]*(\bflwarn\b|\biwarn\b|\bnstep\b)", head_code, re.I)
    checks["headcalc_legacy_compat_context_explicit"] = "legacy_worker" in head.lower() and "canonical_trial = present(worker)" in head.lower()
    checks["headcalc_trial_warning_suppression"] = "if (.not.canonical_trial) call swap_warning" in head.lower()

    soil = (PORT / "soilwater.f90").read_text(encoding="utf-8").lower()
    checks["soilwater_optional_worker"] = "subroutine soilwater(task, worker)" in soil and "optional :: worker" in soil
    checks["soilwater_propagates_worker"] = "call headcalc(worker)" in soil

    swap = assembled_swap().decode("utf-8").lower()
    checks["swap_optional_worker"] = "subroutine swap(icaller, itask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker)" in swap
    checks["swap_propagates_worker_to_soilwater"] = all(x in swap for x in ("call soilwater(1, worker)", "call soilwater(2, worker)", "call soilwater(3, worker)"))
    checks["swap_trial_output_suppression"] = "if (.not.present(worker)) then" in swap and "call swapoutput(2)" in swap and "call soilwateroutput(2)" in swap
    checks["swap_day_end_output_suppression"] = "if (.not.present(worker) .and. sw_end == 2) call soilwateroutput(3)" in swap
    checks["legacy_dll_single_day_hold_preserved"] = "only single day allowed: tend must equal tstart" in swap

    main_src = (PORT / "swap_main.f90").read_text(encoding="utf-8").lower()
    checks["standalone_interface_accepts_optional_worker"] = "optional :: worker" in main_src
    checks["standalone_calls_unchanged"] = "call swap(icaller, itask, tstart_in, tend_in)" in main_src

    cp = CHECKPOINT.read_text(encoding="utf-8")
    cp_low = cp.lower()
    checks["checkpoint_extends_canonical_state"] = "extends(canonical_state_t)" in cp_low
    checks["checkpoint_capture_restore_clone"] = all(x in cp_low for x in ("capture_b1_10_water_state", "restore_b1_10_water_state", "procedure :: clone"))
    checks["checkpoint_no_file_io"] = not any(x in code_without_comments(cp_low) for x in ("open(", "read(", "write("))
    state_match = re.search(r"type,\s*extends\(canonical_state_t\).*?::\s*b1_10_water_state_t(.*?)contains", cp, re.S | re.I)
    state_body = state_match.group(1).lower() if state_match else ""
    checks["checkpoint_type_found"] = bool(state_match)
    forbidden = ("meteo_rec", "rain_rec", "t1900", "daynr", "cgrai", "output", "nprint", "dt =", "numerical", "forcing", "accounting")
    checks["checkpoint_water_only_categories"] = bool(state_match) and not any(x in state_body for x in forbidden)

    snap = (ROOT / "reference/swap-4.3.1/snapshots/B1.10.yml").read_text(encoding="utf-8")
    checks["b1_10_manifest_pinned"] = B1_MANIFEST in snap
    checks["fci06_applicator_present"] = (ROOT / "tools/fci/fci06_apply_controlled_source_port.py").is_file()

    failed = sorted(k for k, v in checks.items() if not v)
    result = {
        "work_unit": "F-CI06",
        "status": "PASS" if not failed else "FAIL",
        "b1_oracle": "B1.10",
        "b1_manifest_sha256": B1_MANIFEST,
        "normalized_postimage_sha256": actual,
        "checks": checks,
        "failed": failed,
        "admission": "CONTROLLED_SOURCE_PORT_SEAM" if not failed else "NONE",
        "not_admitted": "FULL_PHYSICAL_TRANSACTION_ADAPTER",
        "holds": [
            "complete physical/process continuation state not yet captured",
            "integral/process module-global mutations can still leak across rejected physical trials",
            "forcing and time ownership remain legacy-global below the seam",
            "accepted unrounded physical interval mass totals are not yet exposed",
            "generic physical sub-day execution remains unqualified",
            "full B1.10 end-to-end numerical reference qualification remains pending",
            "legacy physical backend remains serialized/module-global",
        ],
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
