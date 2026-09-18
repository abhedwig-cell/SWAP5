#!/usr/bin/env python3
from __future__ import annotations

import ast
import json
import os
from pathlib import Path


PINNED_UPSTREAM = "8907fb13f8301ba1e0f32dd90a64ea475d4896d6"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


root = Path(os.environ["FGC50_IMOD_COUPLER_ROOT"]).resolve()
require(root.is_dir(), "FGC50 upstream checkout is missing")
require(os.environ.get("FGC50_IMOD_COUPLER_SHA") == PINNED_UPSTREAM, "unexpected upstream pin")

config_path = root / "imod_coupler" / "config.py"
driver_path = root / "imod_coupler" / "drivers" / "driver.py"
metamod_path = root / "imod_coupler" / "drivers" / "metamod" / "metamod.py"

for path in (config_path, driver_path, metamod_path):
    require(path.is_file(), f"missing upstream product source: {path}")

config_source = config_path.read_text(encoding="utf-8")
driver_source = driver_path.read_text(encoding="utf-8")
metamod_source = metamod_path.read_text(encoding="utf-8")

config_tree = ast.parse(config_source)
driver_tree = ast.parse(driver_source)
metamod_tree = ast.parse(metamod_source)

driver_type = next(
    (node for node in config_tree.body if isinstance(node, ast.ClassDef) and node.name == "DriverType"),
    None,
)
require(driver_type is not None, "DriverType enum not found")
values: set[str] = set()
for stmt in driver_type.body:
    if isinstance(stmt, ast.Assign) and isinstance(stmt.value, ast.Constant) and isinstance(stmt.value.value, str):
        values.add(stmt.value.value)
require(values == {"metamod", "ribamod", "ribametamod"}, f"unexpected DriverType surface: {values}")
print("FGC50_UPSTREAM_DRIVER_TYPES_EXCLUDE_SWAP5=PASS")

get_driver = next(
    (node for node in driver_tree.body if isinstance(node, ast.FunctionDef) and node.name == "get_driver"),
    None,
)
require(get_driver is not None, "get_driver not found")
get_driver_text = ast.get_source_segment(driver_source, get_driver) or ""
for required in ("MetaMod", "RibaMod", "RibaMetaMod"):
    require(required in get_driver_text, f"expected hard-coded {required} route missing")
require("entry_points" not in driver_source and "importlib.metadata" not in driver_source, "dynamic driver plugin route detected")
require("swap5" not in get_driver_text.lower(), "upstream already contains a SWAP5 route; blocker record is stale")
print("FGC50_UPSTREAM_GET_DRIVER_HARDCODED_NO_PLUGIN=PASS")

driver_cls = next(
    (node for node in driver_tree.body if isinstance(node, ast.ClassDef) and node.name == "Driver"),
    None,
)
require(driver_cls is not None, "Driver class not found")
execute = next(
    (node for node in driver_cls.body if isinstance(node, ast.FunctionDef) and node.name == "execute"),
    None,
)
require(execute is not None, "Driver.execute not found")
execute_text = ast.get_source_segment(driver_source, execute) or ""
for required in ("self.initialize()", "self.update()", "self.get_current_time()", "self.get_end_time()", "self.finalize()"):
    require(required in execute_text, f"Driver.execute lifecycle changed: {required}")
print("FGC50_UPSTREAM_DRIVER_EXECUTE_LIFECYCLE=PASS")

metamod_cls = next(
    (node for node in metamod_tree.body if isinstance(node, ast.ClassDef) and node.name == "MetaMod"),
    None,
)
require(metamod_cls is not None, "MetaMod class not found")
update = next(
    (node for node in metamod_cls.body if isinstance(node, ast.FunctionDef) and node.name == "update"),
    None,
)
do_iter = next(
    (node for node in metamod_cls.body if isinstance(node, ast.FunctionDef) and node.name == "do_iter"),
    None,
)
require(update is not None and do_iter is not None, "MetaMod coupling methods missing")
update_text = ast.get_source_segment(metamod_source, update) or ""
iter_text = ast.get_source_segment(metamod_source, do_iter) or ""
for required in (
    "self.mf6.prepare_time_step",
    "self.mf6.prepare_solve",
    "self.do_iter",
    "self.mf6.finalize_solve",
    "self.mf6.finalize_time_step",
    "self.msw.finalize_time_step",
):
    require(required in update_text, f"MetaMod timestep ownership changed: {required}")
for required in (
    "self.msw.prepare_solve",
    "self.msw.solve",
    "self.mf6.solve",
    "self.msw.finalize_solve",
):
    require(required in iter_text, f"MetaMod iteration ownership changed: {required}")
print("FGC50_UPSTREAM_PRODUCT_OWNS_COUPLED_TIMESTEP_LIFECYCLE=PASS")

repo_root = Path(__file__).resolve().parents[2]
c_api = (repo_root / "src" / "adapter" / "mod_fmr_groundwater_application_c_api.f90").read_text(encoding="utf-8")
runtime = (repo_root / "src" / "adapter" / "fmr_groundwater_application_runtime.py").read_text(encoding="utf-8")

require("register_fmr_groundwater_application_context" in c_api, "F-GC49D registration authority missing")
require('bind(C, name="fgc49d_context_counts_c")' in c_api, "F-GC49D C ABI missing")
for forbidden in (
    "create_context_from_config",
    "fgc49d_create_context_c",
    "fgc49d_initialize_application_c",
):
    require(forbidden not in c_api, f"new production context bootstrap detected: {forbidden}")
require("def __init__(self, library_path: str | Path, context_handle: int)" in runtime, "F-GC49D runtime constructor changed")
require("if self.context_handle <= 0" in runtime, "F-GC49D positive existing handle guard changed")
print("FGC50_FGC49D_REQUIRES_EXISTING_FORTRAN_CONTEXT=PASS")

fixture = repo_root / "tests" / "fgc" / "support" / "mod_fgc49d_application_context_fixture.f90"
require(fixture.is_file(), "F-GC49D qualification fixture not found")
fixture_text = fixture.read_text(encoding="utf-8")
require("fgc49d_fixture_initialize_c" in fixture_text, "fixture initializer changed")
require("tests/fgc/support" in fixture.as_posix(), "fixture unexpectedly left qualification tree")
print("FGC50_FGC49D_FIXTURE_REMAINS_QUALIFICATION_ONLY=PASS")

ppa_status_path = repo_root / "integration" / "audits" / "PPA_WU01_STATUS.json"
ppa_source_path = repo_root / "src" / "runtime" / "mod_fmr_production_application_bootstrap.f90"
require(ppa_status_path.is_file(), "PPA-WU01 canonical status missing")
require(ppa_source_path.is_file(), "PPA-WU01 production bootstrap source missing")
ppa_status = json.loads(ppa_status_path.read_text(encoding="utf-8"))
ppa_source = ppa_source_path.read_text(encoding="utf-8")
require(ppa_status.get("phase") == "CANONICAL_ADMITTED_CLOSED", "PPA-WU01 is not canonically closed")
require(
    ppa_status.get("verdict") == "CANONICAL_ADMITTED_RESTRICTED_PRODUCTION_CLOSED",
    "PPA-WU01 canonical verdict changed",
)
groundwater_profile = ppa_status.get("admitted_restricted_profiles", {}).get("groundwater", "")
require("bottom_mode=5" in groundwater_profile, "PPA-WU01 groundwater profile is not the admitted mode-5 participant profile")
for required in (
    "materialize_groundwater_context",
    "register_fmr_groundwater_application_context",
    "active_context_handle",
):
    require(required in ppa_source, f"PPA-WU01 production context ownership changed: {required}")
require("tests/fgc/support" not in ppa_source, "PPA-WU01 production bootstrap depends on qualification fixture")
require("python" not in ppa_source.lower(), "PPA-WU01 production owner unexpectedly embeds Python ownership")
print("FGC50_PPA_WU01_PRODUCTION_BOOTSTRAP_RESOLVES_B2=PASS")

print("F-GC50 IMOD COUPLER PRODUCT INTEGRATION RECONCILE GATE PASS")
