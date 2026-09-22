#!/usr/bin/env python3
from __future__ import annotations

import ast
import os
from pathlib import Path

PIN = "8907fb13f8301ba1e0f32dd90a64ea475d4896d6"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


root = Path(os.environ["RIBASIM_DUMMY_20A_IMOD_COUPLER_ROOT"]).resolve()
require(root.is_dir(), "pinned iMOD Coupler checkout missing")
require(
    os.environ.get("RIBASIM_DUMMY_20A_IMOD_COUPLER_SHA") == PIN,
    "unexpected iMOD Coupler pin",
)

driver_path = root / "imod_coupler" / "drivers" / "driver.py"
ribamod_path = root / "imod_coupler" / "drivers" / "ribamod" / "ribamod.py"
wrapper_path = root / "imod_coupler" / "kernelwrappers" / "ribasim_wrapper.py"

for path in (driver_path, ribamod_path, wrapper_path):
    require(path.is_file(), f"missing upstream source: {path}")

driver_source = driver_path.read_text(encoding="utf-8")
ribamod_source = ribamod_path.read_text(encoding="utf-8")
wrapper_source = wrapper_path.read_text(encoding="utf-8")

driver_tree = ast.parse(driver_source)
ribamod_tree = ast.parse(ribamod_source)
wrapper_tree = ast.parse(wrapper_source)

driver_cls = next(
    (n for n in driver_tree.body if isinstance(n, ast.ClassDef) and n.name == "Driver"),
    None,
)
require(driver_cls is not None, "Driver class missing")
execute = next(
    (n for n in driver_cls.body if isinstance(n, ast.FunctionDef) and n.name == "execute"),
    None,
)
require(execute is not None, "Driver.execute missing")
execute_text = ast.get_source_segment(driver_source, execute) or ""
for required in (
    "self.initialize()",
    "while self.get_current_time() < self.get_end_time()",
    "self.update()",
    "self.finalize()",
):
    require(required in execute_text, f"Driver.execute lifecycle changed: {required}")
print("RIBASIM_DUMMY_20A_PRODUCT_DRIVER_LOOP=PASS")

ribamod_cls = next(
    (n for n in ribamod_tree.body if isinstance(n, ast.ClassDef) and n.name == "RibaMod"),
    None,
)
require(ribamod_cls is not None, "RibaMod class missing")
update = next(
    (n for n in ribamod_cls.body if isinstance(n, ast.FunctionDef) and n.name == "update"),
    None,
)
require(update is not None, "RibaMod.update missing")
update_text = ast.get_source_segment(ribamod_source, update) or ""

ordered = [
    "self.ribasim.update_subgrid_level()",
    "self.mf6.prepare_time_step(0.0)",
    "self.exchange_rib2mod()",
    "self.mf6.prepare_solve(1)",
    "self.mf6.finalize_solve(1)",
    "self.mf6.finalize_time_step()",
    "self.exchange_mod2rib()",
    "self.ribasim.update_until(self.mf6.get_current_time() * RIBAMOD_TIME_FACTOR)",
]
positions = []
for token in ordered:
    pos = update_text.find(token)
    require(pos >= 0, f"RibaMod.update operation missing: {token}")
    positions.append(pos)
require(positions == sorted(positions), "RibaMod.update operation ordering changed")
print("RIBASIM_DUMMY_20A_MF6_LEADS_RIBASIM_UPDATE=PASS")

require(
    "RIBAMOD_TIME_FACTOR = 86400" in ribamod_source,
    "RibaMod time conversion authority changed",
)
require(
    "self.ribasim.update_until(self.mf6.get_current_time() * RIBAMOD_TIME_FACTOR)" in update_text,
    "Ribasim update target is no longer MF6 current time",
)
print("RIBASIM_DUMMY_20A_MF6_ENDPOINT_IS_RIBASIM_BMI_TARGET=PASS")

for forbidden in (
    "parse_allocations!",
    "user_demand.allocated",
    "inflow_link_allocated",
    "update_allocation!",
    "allocation.dt",
    "solver.saveat",
):
    require(
        forbidden not in ribamod_source,
        f"RibaMod gained explicit allocation/apply/clock ownership: {forbidden}",
    )
print("RIBASIM_DUMMY_20A_NO_EXPLICIT_USERDEMAND_APPLY=PASS")
print("RIBASIM_DUMMY_20A_NO_ALLOCATION_OR_SAVEAT_OVERRIDE=PASS")

wrapper_cls = next(
    (n for n in wrapper_tree.body if isinstance(n, ast.ClassDef) and n.name == "RibasimWrapper"),
    None,
)
require(wrapper_cls is not None, "RibasimWrapper missing")
require(
    "class RibasimWrapper(XmiWrapper)" in wrapper_source,
    "Ribasim wrapper no longer delegates generic update/update_until to XmiWrapper",
)
require(
    "def update_until" not in wrapper_source,
    "RibasimWrapper now overrides update_until; contract requires fresh review",
)
print("RIBASIM_DUMMY_20A_RIBASIM_UPDATE_UNTIL_DELEGATED_TO_XMI=PASS")

print("RIBASIM_DUMMY_20A_RIBAMOD_PRODUCT_CLOCK_CONTRACT=PASS")
