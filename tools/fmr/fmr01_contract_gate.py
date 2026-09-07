#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "integration" / "f-mr"

required = [
    "F-MR01_DEPENDENCIES.json",
    "F-MR01_RUNTIME_OWNERSHIP.json",
    "F-MR01_COLUMN_MODEL.json",
    "F-MR01_TEMPLATE_CONTRACT.json",
    "F-MR01_BACKEND_ADMISSION.json",
    "F-MR01_CHECKPOINT_CONTRACT.json",
    "F-MR01_STATUS.json",
]
for name in required:
    path = BASE / name
    if not path.exists():
        raise SystemExit(f"missing F-MR01 contract artifact: {path}")

with (BASE / "F-MR01_DEPENDENCIES.json").open(encoding="utf-8") as handle:
    deps = json.load(handle)
with (BASE / "F-MR01_BACKEND_ADMISSION.json").open(encoding="utf-8") as handle:
    admission = json.load(handle)
with (BASE / "F-MR01_CHECKPOINT_CONTRACT.json").open(encoding="utf-8") as handle:
    checkpoint = json.load(handle)
with (BASE / "F-MR01_COLUMN_MODEL.json").open(encoding="utf-8") as handle:
    column = json.load(handle)

fkt = deps["consumed_production_dependency"]
assert fkt["work_unit"] == "F-KT05"
assert fkt["closeout_head"] == "f50b8cd20221fac27a2059b6c6192ed0b7384be8"
assert fkt["status"] == "QUALIFIED"
assert deps["observed_admission_dependency"]["source_consumed"] is False
assert deps["observed_admission_dependency"]["production_multiswap_admission"] is False

parallel = admission["backends"]["PARALLEL_REFERENCE_BACKEND"]
assert parallel["status"] == "NOT_ADMITTED"
assert parallel["parallel_reference_backend_admitted"] is False
assert admission["backends"]["DETERMINISTIC_TEST_BACKEND"]["physical_swap_admission"] is False
assert admission["routing_boundary"].startswith("F-MR -> F-KT")

assert checkpoint["transaction_authority"] == "F-KT05"
assert checkpoint["checkpoint_type"] == "mod_kernel_transactions::kernel_checkpoint_t"
assert checkpoint["checkpoint_owner"] == "F-KT"
assert checkpoint["f_mr_checkpoint_type_defined"] is False

forbidden = " ".join(column["logical_column"]["forbidden_per_column"])
assert "Jacobian" in forbidden
assert "Newton" in forbidden
assert "checkpoint" in forbidden.lower()

source_paths = [
    ROOT / "src" / "runtime" / "mod_fmr_checkpoint_orchestrator.f90",
    ROOT / "src" / "runtime" / "mod_fmr_runtime_core.f90",
    ROOT / "src" / "runtime" / "mod_fmr_deterministic_runtime.f90",
]
for path in source_paths:
    text = path.read_text(encoding="utf-8")
    if "HeadCalc" in text or "headcalc" in text:
        raise SystemExit(f"F-MR source must not schedule HeadCalc directly: {path}")

checkpoint_source = source_paths[0].read_text(encoding="utf-8")
assert "kernel_checkpoint_t" in checkpoint_source
assert "capture_checkpoint" in checkpoint_source
assert "advance_interval" in checkpoint_source
assert "type :: fmr_checkpoint" not in checkpoint_source.lower()

print("FMR01_CONTRACT_GATE PASS")
