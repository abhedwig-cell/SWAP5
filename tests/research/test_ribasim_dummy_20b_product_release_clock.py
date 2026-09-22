#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

PIN = "e7fc8ade52a4bedeec10e508d2065577f33eb76a"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


root = Path(os.environ["RIBASIM_DUMMY_20B_RIBASIM_ROOT"]).resolve()
require(root.is_dir(), "pinned Ribasim release checkout missing")
require(
    os.environ.get("RIBASIM_DUMMY_20B_RIBASIM_SHA") == PIN,
    "unexpected Ribasim release commit",
)

model_path = root / "core" / "src" / "model.jl"
bmi_path = root / "core" / "src" / "bmi.jl"
allocation_path = root / "core" / "src" / "allocation_optim.jl"

for path in (model_path, bmi_path, allocation_path):
    require(path.is_file(), f"missing release source: {path}")

model = model_path.read_text(encoding="utf-8")
bmi = bmi_path.read_text(encoding="utf-8")
allocation = allocation_path.read_text(encoding="utf-8")

require("function BMI.update_until(model::Model, time::Float64)::Nothing" in bmi, "BMI.update_until signature changed")
require("dt = time - t" in bmi, "BMI.update_until no longer derives one requested interval")
require("step!(model, dt)" in bmi, "BMI.update_until no longer delegates to step!")
print("RIBASIM_DUMMY_20B_BMI_UPDATE_UNTIL_DELEGATES_STEP=PASS")

step_start = model.find("function step!(model::Model, dt::Float64)::Model")
require(step_start >= 0, "step! definition missing")
step_end = model.find("\nend", step_start)
step_text = model[step_start:step_end + 4]
for required in (
    "ntimes = t / something(config.allocation.dt, 86400.0)",
    "if round(ntimes) ≈ ntimes",
    "update_allocation!(model)",
    "SciMLBase.step!(integrator, dt, true)",
):
    require(required in step_text, f"fixed allocation boundary rule changed: {required}")
print("RIBASIM_DUMMY_20B_FIXED_DT_ALLOCATION_AT_CURRENT_GRID_TIME=PASS")

solve_start = model.find("function solve_with_allocation!(model::Model)::Nothing")
require(solve_start >= 0, "solve_with_allocation! missing")
solve_end = model.find("\nend", solve_start)
solve_text = model[solve_start:solve_end + 4]
require("if config.allocation.dt === nothing" in solve_text, "adaptive/fixed allocation split missing")
require("saveat = config.solver.saveat" in solve_text, "adaptive branch no longer owns saveat")
require("dt_alloc = config.allocation.dt" in solve_text, "fixed allocation.dt branch missing")
require("SciMLBase.step!(integrator, dt_alloc, true)" in solve_text, "fixed allocation branch no longer steps by allocation.dt")
fixed_branch = solve_text.split("else", 1)[1]
require("saveat" not in fixed_branch, "solver.saveat leaked into fixed allocation.dt branch")
print("RIBASIM_DUMMY_20B_FIXED_DT_INDEPENDENT_OF_SAVEAT=PASS")

require(
    "function update_allocation!(model, Δt = 0.0; record::Bool = true)::Nothing" in allocation,
    "update_allocation! default record contract changed",
)
require("if record\n            parse_allocations!" in allocation, "parse/apply record gate changed")
require("node.allocated[node_id.idx, demand_priority_idx] = allocated_flow" in allocation, "UserDemand applied allocation write missing")
require("link_alloc[i] = max(0.0, JuMP.value(flow[link_metadata.link]) * scaling.flow)" in allocation, "UserDemand per-link applied allocation write missing")
print("RIBASIM_DUMMY_20B_ALLOCATION_GRID_SOLVE_APPLIES_USERDEMAND=PASS")

require("allocation.time.tstops" not in model, "later allocation-tstop architecture unexpectedly present in release")
print("RIBASIM_DUMMY_20B_LATER_TSTOP_ARCHITECTURE_ABSENT=PASS")

print("RIBASIM_DUMMY_20B_PRODUCT_RELEASE_CLOCK_CONTRACT=PASS")
