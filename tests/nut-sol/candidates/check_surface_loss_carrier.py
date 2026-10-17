#!/usr/bin/env python3
"""Fail-closed preflight for MC-SOL01 surface-loss production carrier."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[3]
backend = (ROOT / "src/runtime/mod_fmr_serialized_reference_backend.f90").read_text()
pond = (ROOT / "src/process/mod_b111_persistent_pond.f90").read_text()
joint = (ROOT / "src/runtime/mod_fmr_b111_pond_joint_application.f90").read_text()
match = re.search(r"type, public :: fmr_water_flux_substep_trace_t\b(.*?)end type fmr_water_flux_substep_trace_t", backend, re.S | re.I)
assert match, "accepted trace type unavailable"
trace = match.group(1).lower()
required = ("top_flux", "bottom_flux", "pond_start_cm", "pond_end_cm")
assert all(x in trace for x in required), "incumbent accepted fields missing"
missing = ("runoff", "evaporation", "runon", "gross_rain", "gross_irrigation")
assert not any(re.search(r"\b" + name + r"\b", trace) for name in missing), (
    "accepted trace changed: re-evaluate owner and remove obsolete blocker"
)
assert "s%depth_end-s%depth_begin-(s%rain_rate+s%irrigation_rate+s%qtop)*dt" in pond.replace(" ", ""), (
    "existing zero-loss pond water closure changed"
)
assert "allocated(forcing%black_evaporation)" in joint
assert "allocated(forcing%boesten_evaporation)" in joint
print("SOL_SURFACE_LOSS_CARRIER_PREFLIGHT=BLOCKED_EXPECTED")
print("Missing accepted per-substep gross evaporation/runoff/runon fields; no production admission.")
