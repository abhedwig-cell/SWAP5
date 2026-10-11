from __future__ import annotations

import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))

from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_xmi_package_adapter import Modflow6XmiAdapterStatus, Modflow6XmiPackageAdapter


@dataclass(frozen=True)
class Binding:
    groundwater_cell_id: int
    package_slot: int
    modflow_node_id: int


@dataclass(frozen=True)
class Term:
    groundwater_cell_id: int
    hcof_m2_per_day: float
    rhs_m3_per_day: float


def require(ok: bool, message: str) -> None:
    if not ok:
        raise AssertionError(message)


def build_model(workdir: Path) -> None:
    sim = flopy.mf6.MFSimulation(sim_name="FVQ110", version="mf6", sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim, time_units="DAYS", nper=1, perioddata=[(1.0, 1, 1.0)])
    flopy.mf6.ModflowIms(
        sim,
        complexity="SIMPLE",
        outer_dvclose=1.0e-12,
        inner_dvclose=1.0e-12,
        outer_maximum=100,
        inner_maximum=100,
    )
    gwf = flopy.mf6.ModflowGwf(sim, modelname="GWF_1", save_flows=True)
    flopy.mf6.ModflowGwfdis(
        gwf, nlay=1, nrow=1, ncol=4, delr=1.0, delc=1.0, top=1.0, botm=0.0
    )
    flopy.mf6.ModflowGwfic(gwf, strt=0.5)
    flopy.mf6.ModflowGwfnpf(gwf, icelltype=0, k=1.0, save_flows=True)
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={0: [((0, 0, 0), 1.0), ((0, 0, 3), 0.0)]},
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(
        gwf, maxbound=2, pname="API_SWAP", filename="api_swap.api"
    )
    sim.write_simulation(silent=True)


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    bridge = Path(os.environ["FGC34_BRIDGE_LIB"]).resolve()
    require(libmf6.is_file(), "missing official libmf6")
    require(bridge.is_file(), "missing F-GC34 bridge")

    publisher = Fgc34CtypesPublisher(bridge)

    with tempfile.TemporaryDirectory(prefix="fvq110-") as tmp:
        workdir = Path(tmp)
        build_model(workdir)
        mf6 = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
        try:
            mf6.initialize()
            initialized = True
            require("6.8.0" in mf6.get_version(), "wrong MODFLOW version")

            adapter = Modflow6XmiPackageAdapter(mf6, "GWF_1", "API_SWAP")
            require(
                adapter.acquire_after_initialize() == Modflow6XmiAdapterStatus.OK,
                adapter.last_error,
            )
            mf6.prepare_time_step(0.0)
            require(
                adapter.refresh_after_prepare_time_step() == Modflow6XmiAdapterStatus.OK,
                adapter.last_error,
            )

            # Deliberately shuffled caller order; slots are the publication authority.
            bindings = [
                Binding(groundwater_cell_id=8202, package_slot=2, modflow_node_id=3),
                Binding(groundwater_cell_id=8101, package_slot=1, modflow_node_id=2),
            ]
            terms = [
                Term(groundwater_cell_id=8101, hcof_m2_per_day=-0.2, rhs_m3_per_day=-0.08),
                Term(groundwater_cell_id=8202, hcof_m2_per_day=-0.3, rhs_m3_per_day=0.03),
            ]

            require(
                adapter.publish_via_fgc34(bindings, terms, publisher)
                == Modflow6XmiAdapterStatus.OK,
                adapter.last_error,
            )
            view = adapter.view
            require(view is not None, "missing live API view")
            require(int(view.nbound[0]) == 2, "NBOUND != 2")
            require(np.array_equal(view.nodelist[:2], np.array([2, 3], dtype=np.int32)), "NODELIST mismatch")
            require(np.array_equal(view.hcof[:2], np.array([-0.2, -0.3])), "HCOF mismatch")
            require(np.array_equal(view.rhs[:2], np.array([-0.08, 0.03])), "RHS mismatch")

            require(
                adapter.close_before_prepare_solve() == Modflow6XmiAdapterStatus.OK,
                adapter.last_error,
            )

            head = mf6.get_value_ptr(mf6.get_var_address("X", "GWF_1"))
            mf6.prepare_solve(1)
            converged = False
            for _ in range(100):
                if mf6.solve(1):
                    converged = True
                    break
            require(converged, "live 2-slot MODFLOW solve did not converge")
            mf6.finalize_solve(1)

            # Independent steady-state equations:
            # (2-HCOF_2) h2 - h3 = h_left - RHS_2
            # -h2 + (2-HCOF_3) h3 = h_right - RHS_3
            matrix = np.array([[2.2, -1.0], [-1.0, 2.3]], dtype=np.float64)
            forcing = np.array([1.08, -0.03], dtype=np.float64)
            expected = np.linalg.solve(matrix, forcing)
            actual = np.asarray(head[1:3], dtype=np.float64).copy()
            require(
                np.allclose(actual, expected, rtol=0.0, atol=1.0e-9),
                f"analytical 2x2 closure failed: actual={actual}, expected={expected}",
            )

            q2 = float(view.hcof[0]) * float(head[1]) - float(view.rhs[0])
            q3 = float(view.hcof[1]) * float(head[2]) - float(view.rhs[1])
            require(np.isfinite(q2) and np.isfinite(q3), "nonfinite live API flux")
            require(q2 < 0.0 and q3 < 0.0, f"unexpected independent flux signs: q2={q2}, q3={q3}")

            mf6.finalize_time_step()
            mf6.finalize()
            initialized = False

            print("FVQ110_OFFICIAL_MODFLOW680_LOADED=PASS")
            print("FVQ110_TWO_SLOT_LIVE_PUBLICATION=PASS")
            print("FVQ110_SHUFFLED_IDENTITY_MAPPING=PASS")
            print("FVQ110_LIVE_MODFLOW_SOLVE_CONVERGED=PASS")
            print("FVQ110_TWO_BY_TWO_ANALYTICAL_HEAD_CLOSURE=PASS")
            print("FVQ110_TWO_SLOT_LIVE_FLUX_SIGN=PASS")
            print("FVQ110_INDEPENDENT_LIVE_BRIDGE_GATE=PASS")
        finally:
            if initialized:
                mf6.finalize()


if __name__ == "__main__":
    main()
