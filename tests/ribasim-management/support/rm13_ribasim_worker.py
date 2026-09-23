from __future__ import annotations

import ctypes
import json
import os
import sys
import traceback
from pathlib import Path

import numpy as np

RESPONSE_FD = int(os.environ["RM13_WORKER_RESPONSE_FD"])
RIBASIM_ROOT = Path(os.environ["RM13_RIBASIM_ROOT"]).resolve()
MODEL = Path(os.environ["RM13_WORKER_MODEL"]).resolve()
LIB = Path(os.environ["RM13_LIBRIBASIM"]).resolve()

sys.path.insert(0, str(RIBASIM_ROOT / "python" / "ribasim_api"))
from ribasim_api import RibasimApi  # noqa: E402


def respond(payload: dict) -> None:
    data=(json.dumps(payload, separators=(",", ":"))+"\n").encode()
    os.write(RESPONSE_FD,data)


def snapshot(api: RibasimApi) -> dict[str,float]:
    return {
        "time_s": float(api.get_current_time()),
        "basin_level_m": float(np.asarray(api.get_value_ptr("basin.level"),dtype=float)[0]),
        "user_demand_cumulative_inflow_m3": float(
            np.asarray(api.get_value_ptr("user_demand.cumulative_inflow"),dtype=float)[0]
        ),
    }


def preload_runtime() -> str:
    candidates=sorted(LIB.parent.parent.rglob("libjulia.so.1.12"))
    if len(candidates) != 1:
        raise RuntimeError(f"expected one bundled libjulia.so.1.12, found {candidates}")
    ctypes.CDLL(str(candidates[0]),mode=ctypes.RTLD_GLOBAL)
    return str(candidates[0])


def main() -> None:
    api=None
    finalized=False
    try:
        runtime=preload_runtime()
        api=RibasimApi(LIB,LIB.parent)
        api.initialize(str(MODEL))
        respond({"ok":True,"op":"ready","runtime":runtime,"snapshot":snapshot(api)})
        for line in sys.stdin:
            if not line.strip():
                continue
            cmd=json.loads(line)
            op=cmd.get("op")
            if op=="snapshot":
                respond({"ok":True,"op":"snapshot","snapshot":snapshot(api)})
            elif op=="update_until":
                target=float(cmd["time_s"])
                api.update_until(target)
                respond({"ok":True,"op":"update_until","snapshot":snapshot(api)})
            elif op=="finalize":
                if not finalized:
                    api.finalize()
                    finalized=True
                respond({"ok":True,"op":"finalize"})
            elif op=="stop":
                if api is not None and not finalized:
                    api.finalize()
                    finalized=True
                respond({"ok":True,"op":"stop"})
                return
            else:
                raise RuntimeError(f"unknown RM13 worker op {op!r}")
    except BaseException as exc:
        try:
            respond({
                "ok":False,
                "error":str(exc),
                "type":type(exc).__name__,
                "traceback":traceback.format_exc(),
            })
        finally:
            raise


if __name__=="__main__":
    main()
