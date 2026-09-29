#!/usr/bin/env python3
"""Check that admitted production-application standalone entry points share the serialized runtime route.

This is a source-structure census only. It does not qualify the physical profiles,
restart, transactions, numerical results, or mass closure exercised by that route.
"""
from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
BOOTSTRAP = ROOT / "src/runtime/mod_fmr_production_application_bootstrap.f90"
RUNTIME = ROOT / "src/runtime/mod_fmr_serialized_multiswap_runtime.f90"


def routine(source: str, name: str) -> str:
    match = re.search(
        rf"(?ims)^\s*subroutine\s+{re.escape(name)}\b(.*?)^\s*end\s+subroutine\s+{re.escape(name)}\b",
        source,
    )
    if not match:
        raise AssertionError(f"routine not found: {name}")
    return match.group(1).lower()


def function(source: str, name: str) -> str:
    match = re.search(
        rf"(?ims)^\s*(?:logical\s+)?function\s+{re.escape(name)}\b(.*?)^\s*end\s+function\s+{re.escape(name)}\b",
        source,
    )
    if not match:
        raise AssertionError(f"function not found: {name}")
    return match.group(1).lower()


def require(condition: bool, marker: str) -> None:
    if not condition:
        raise AssertionError(marker)
    print(f"{marker}=PASS")


def main() -> int:
    bootstrap = BOOTSTRAP.read_text(encoding="utf-8").lower()
    runtime = RUNTIME.read_text(encoding="utf-8").lower()

    basic = routine(bootstrap, "production_application_run_standalone")
    forcing = routine(bootstrap, "production_application_run_standalone_with_forcing")
    receipts = routine(bootstrap, "production_application_run_standalone_with_forcing_receipts")
    dispatcher = routine(runtime, "fmr_run_serialized_physical_multiswap")
    transaction = routine(runtime, "execute_resolved_column")
    profile = function(bootstrap, "tile_config_valid")

    require("self%run_standalone_with_forcing(" in basic, "M7_STANDALONE_BASE_DELEGATES_TO_FORCING_ROUTE")
    serialized_call = "call fmr_run_serialized_physical_multiswap("
    require(forcing.count(serialized_call) == 1, "M7_STANDALONE_FORCING_HAS_ONE_SERIALIZED_DISPATCH")
    require(receipts.count(serialized_call) == 1, "M7_STANDALONE_RECEIPTS_HAS_ONE_SERIALIZED_DISPATCH")
    require("call execute_column(" in dispatcher, "M7_SERIALIZED_DISPATCH_USES_COLUMN_ROUTER")
    require("call backend%run_trial(" in transaction, "M7_SERIALIZED_ROUTE_USES_TYPED_BACKEND_TRIAL")
    require("call fmr_commit_candidate" in transaction, "M7_SERIALIZED_ROUTE_USES_KERNEL_COMMIT_CONTRACT")
    require("call fmr_discard_candidate" in transaction, "M7_SERIALIZED_ROUTE_USES_KERNEL_REJECT_CONTRACT")
    require(
        "call fmr_run_" not in basic.replace("call fmr_run_serialized_physical_multiswap(", ""),
        "M7_STANDALONE_BASE_HAS_NO_ALTERNATE_KERNEL_ENTRY",
    )

    accepted_bottom_modes = [
        "tile%parameters%bottom_mode /= 5",
        "tile%parameters%bottom_mode /= 7",
        "tile%parameters%bottom_mode /= 2",
    ]
    accepted_layouts = [
        "fmr_optional_state_layout_base",
        "fmr_optional_state_layout_black_evaporation",
        "fmr_optional_state_layout_boesten_evaporation",
    ]
    for token in accepted_bottom_modes + accepted_layouts:
        require(token in profile, f"M7_STANDALONE_PROFILE_GUARD_{token.replace('%', '_').replace(' ', '_').upper()}")
    for token in (
        "fmr_backend_serialized_reference",
        "fmr_numerical_continuation_none",
        "fmr_numerical_continuation_richards_temporal_history",
        "macropore_active",
        "snow_active",
        "hysteresis_active",
        "elasticity_active",
        "frost_active",
        "soil_temperature_active",
        "drainage_response_active",
        "tabulated_hydraulics_active",
        "root_extraction_active .and. tile%parameters%bottom_mode /= 7",
    ):
        require(token in profile, f"M7_STANDALONE_PROFILE_GUARD_{token.replace('%', '_').replace(' ', '_').upper()}")

    print("M7_STANDALONE_KERNEL_ROUTE_CENSUS=PASS_SOURCE_STRUCTURE_ONLY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
