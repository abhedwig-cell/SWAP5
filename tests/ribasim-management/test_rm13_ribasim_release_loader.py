from __future__ import annotations

import os
import shutil
import sys
import tempfile
from contextlib import ExitStack
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SUPPORT=ROOT/"tests"/"ribasim-management"/"support"
sys.path.insert(0,str(SUPPORT))
from rm13_ribasim_process import RibasimWorker  # noqa: E402

RIBASIM_ROOT=Path(os.environ["RM13_RIBASIM_ROOT"]).resolve()
MODEL=Path(os.environ["RM13_RIBASIM_MODEL"]).resolve()
LIB=Path(os.environ["RM13_LIBRIBASIM"]).resolve()
WINDOW_S=8.64
TOL=1e-12


def require(condition: bool,message: str)->None:
    if not condition:
        raise AssertionError(message)


def same_snapshot(a: dict,b: dict)->bool:
    return (
        abs(float(a["time_s"])-float(b["time_s"]))<=TOL
        and abs(float(a["basin_level_m"])-float(b["basin_level_m"]))<=TOL
        and abs(
            float(a["user_demand_cumulative_inflow_m3"])
            -float(b["user_demand_cumulative_inflow_m3"])
        )<=TOL
    )


source_dir=MODEL.parent
with tempfile.TemporaryDirectory(prefix="rm13-ribasim-process-smoke-") as tmp:
    root=Path(tmp)
    dirs={}
    for tag in ("accepted","a","b"):
        target=root/tag/"model"
        target.parent.mkdir(parents=True)
        shutil.copytree(source_dir,target)
        dirs[tag]=target

    with ExitStack() as stack:
        accepted=stack.enter_context(RibasimWorker(
            model_path=dirs["accepted"]/MODEL.name,
            lib_path=LIB,
            ribasim_root=RIBASIM_ROOT,
            log_path=root/"accepted.log",
        ))
        a=stack.enter_context(RibasimWorker(
            model_path=dirs["a"]/MODEL.name,
            lib_path=LIB,
            ribasim_root=RIBASIM_ROOT,
            log_path=root/"a.log",
        ))
        b=stack.enter_context(RibasimWorker(
            model_path=dirs["b"]/MODEL.name,
            lib_path=LIB,
            ribasim_root=RIBASIM_ROOT,
            log_path=root/"b.log",
        ))

        origin=accepted.ready["snapshot"]
        sa=a.update_until(WINDOW_S)
        a.finalize()
        require(same_snapshot(accepted.snapshot(),origin),"candidate A mutated accepted witness")

        sb=b.update_until(WINDOW_S)
        require(abs(float(sa["time_s"])-float(sb["time_s"]))<=TOL,"time replay")
        require(abs(float(sa["basin_level_m"])-float(sb["basin_level_m"]))<=TOL,"level replay")
        require(
            abs(
                float(sa["user_demand_cumulative_inflow_m3"])
                -float(sb["user_demand_cumulative_inflow_m3"])
            )<=TOL,
            "supply replay",
        )
        require(same_snapshot(accepted.snapshot(),origin),"candidate B mutated accepted witness")
        b.finalize()
        accepted.finalize()

print(f"RM13_RIBASIM_SMOKE_ORIGIN={origin}")
print(f"RM13_RIBASIM_SMOKE_CANDIDATE={sa}")
print("RM13_RIBASIM_RELEASE_LOADER=PASS")
print("RM13_RIBASIM_THREE_PROCESS_ISOLATION=PASS")
