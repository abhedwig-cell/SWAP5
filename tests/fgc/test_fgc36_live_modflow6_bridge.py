from __future__ import annotations

import math
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
from modflow6_xmi_package_adapter import (
    Modflow6XmiAdapterStatus,
    Modflow6XmiPackageAdapter,
)


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


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def require_close(actual: float, expected: float, tolerance: float, message: str) -> None:
    if not math.isfinite(actual) or abs(actual - expected) > tolerance:
        raise AssertionError(
            f"{message}: actual={actual:.16g}, expected={expected:.16g}, tol={tolerance:.3g}"
        )


def test_real_fgc34_bridge_fail_closed(publisher: Fgc34CtypesPublisher) -> None:
    bad_bindings = [Binding(groundwater_cell_id=7001, package_slot=2, modflow_node_id=2)]
    terms = [Term(groundwater_cell_id=7001, hcof_m2_per_day=-0.1, rhs_m3_per_day=-0.06)]

    nodelist = np.array([91], dtype=np.int32)
    hcof = np.array([11.0], dtype=np.float64)
    rhs = np.array([21.0], dtype=np.float64)
    nbound = np.array([1], dtype=np.int32)

    before = (nodelist.copy(), hcof.copy(), rhs.copy(), nbound.copy())
    status = publisher(bad_bindings, terms, 1, nodelist, hcof, rhs, nbound)

    require(status == 3, f"expected real F-GC34 INVALID_BINDING=3, got {status}")
    require(np.array_equal(nodelist, before[0]), "NODELIST mutated on rejected F-GC34 call")
    require(np.array_equal(hcof, before[1]), "HCOF mutated on rejected F-GC34 call")
    require(np.array_equal(rhs, before[2]), "RHS mutated on rejected F-GC34 call")
    require(np.array_equal(nbound, before[3]), "NBOUND mutated on rejected F-GC34 call")

    print("FGC36_REAL_FGC34_FAIL_CLOSED=PASS")


def build_live_model(workdir: Path) -> None:
    sim = flopy.mf6.MFSimulation(
        sim_name="FGC36_LIVE",
        version="mf6",
        sim_ws=str(workdir),
    )
    flopy.mf6.ModflowTdis(
        sim,
        time_units="DAYS",
        nper=1,
        perioddata=[(1.0, 1, 1.0)],
    )
    flopy.mf6.ModflowIms(
        sim,
        complexity="SIMPLE",
        outer_dvclose=1.0e-12,
        inner_dvclose=1.0e-12,
        outer_maximum=100,
        inner_maximum=100,
    )

    gwf = flopy.mf6.ModflowGwf(
        sim,
        modelname="GWF_1",
        save_flows=True,
    )
    flopy.mf6.ModflowGwfdis(
        gwf,
        nlay=1,
        nrow=1,
        ncol=3,
        delr=1.0,
        delc=1.0,
        top=1.0,
        botm=0.0,
    )
    flopy.mf6.ModflowGwfic(gwf, strt=0.5)
    flopy.mf6.ModflowGwfnpf(
        gwf,
        icelltype=0,
        k=1.0,
        save_flows=True,
    )
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={
            0: [
                ((0, 0, 0), 1.0),
                ((0, 0, 2), 0.0),
            ]
        },
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(
        gwf,
        maxbound=1,
        pname="API_SWAP",
        filename="api_swap.api",
    )
    sim.write_simulation(silent=True)


def test_live_modflow6(
    libmf6: Path,
    publisher: Fgc34CtypesPublisher,
) -> None:
    with tempfile.TemporaryDirectory(prefix="fgc36-live-") as tmp:
        workdir = Path(tmp)
        build_live_model(workdir)

        mf6 = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
        try:
            mf6.initialize()
            initialized = True

            version = mf6.get_version()
            require("6.8.0" in version, f"unexpected live MODFLOW version: {version!r}")

            adapter = Modflow6XmiPackageAdapter(mf6, "GWF_1", "API_SWAP")
            status = adapter.acquire_after_initialize()
            require(
                status == Modflow6XmiAdapterStatus.OK,
                f"F-GC35 initial live acquisition failed: {adapter.last_error}",
            )

            pre_nodelist = adapter.view.nodelist
            pre_nodelist_address = int(pre_nodelist.ctypes.data)

            mf6.prepare_time_step(0.0)
            status = adapter.refresh_after_prepare_time_step()
            require(
                status == Modflow6XmiAdapterStatus.OK,
                f"F-GC35 live post-prepare refresh failed: {adapter.last_error}",
            )

            require(
                adapter.view.nodelist is not pre_nodelist,
                "live NODELIST pointer was not reacquired after prepare_time_step",
            )

            bindings = [
                Binding(
                    groundwater_cell_id=7001,
                    package_slot=1,
                    modflow_node_id=2,
                )
            ]
            terms = [
                Term(
                    groundwater_cell_id=7001,
                    hcof_m2_per_day=-0.1,
                    rhs_m3_per_day=-0.06,
                )
            ]

            status = adapter.publish_via_fgc34(bindings, terms, publisher)
            require(
                status == Modflow6XmiAdapterStatus.OK,
                f"live F-GC34 publication failed: {adapter.last_error}",
            )
            require(adapter.last_publisher_status == 0, "real F-GC34 did not return success")

            view = adapter.view
            require(view is not None, "live package view disappeared")
            require(int(view.nodelist[0]) == 2, "live NODELIST publication mismatch")
            require_close(float(view.hcof[0]), -0.1, 0.0, "live HCOF publication mismatch")
            require_close(float(view.rhs[0]), -0.06, 0.0, "live RHS publication mismatch")
            require(int(view.nbound[0]) == 1, "live NBOUND publication mismatch")
            # xmipy may return a fresh NumPy view object that aliases the same
            # MODFLOW kernel memory after allocation/refresh.  Therefore the old
            # Python object may observe later writes.  The contract is that the
            # publisher receives the refreshed object, not that an old alias is
            # immutable.
            require(
                view.nodelist is not pre_nodelist,
                "publisher-visible NODELIST is not the refreshed post-prepare view",
            )
            print(
                "FGC36_NODELIST_VIEW_REFRESH_ADDRESS="
                f"{pre_nodelist_address}->{int(view.nodelist.ctypes.data)}"
            )

            status = adapter.close_before_prepare_solve()
            require(
                status == Modflow6XmiAdapterStatus.OK,
                f"live solve-boundary close failed: {adapter.last_error}",
            )

            head_address = mf6.get_var_address("X", "GWF_1")
            head = mf6.get_value_ptr(head_address)

            mf6.prepare_solve(1)
            converged = False
            for _ in range(100):
                if mf6.solve(1):
                    converged = True
                    break
            require(converged, "live MODFLOW6 solve did not converge")
            mf6.finalize_solve(1)

            expected_middle_head = 1.06 / 2.1
            require_close(
                float(head[1]),
                expected_middle_head,
                1.0e-9,
                "live MODFLOW6 middle-cell head does not consume F-GC34 HCOF/RHS as expected",
            )

            live_flux = float(view.hcof[0]) * float(head[1]) - float(view.rhs[0])
            expected_flux = -0.1 * expected_middle_head + 0.06
            require_close(
                live_flux,
                expected_flux,
                1.0e-12,
                "live API flux relation mismatch",
            )
            require(live_flux > 0.0, "live API boundary did not retain positive infiltration sign")

            mf6.finalize_time_step()
            mf6.finalize()
            initialized = False

            print("FGC36_OFFICIAL_MODFLOW680_LOADED=PASS")
            print("FGC36_LIVE_XMIPY_POINTERS=PASS")
            print("FGC36_REAL_FGC34_LIVE_PUBLICATION=PASS")
            print("FGC36_LIVE_MODFLOW_SOLVE_CONVERGED=PASS")
            print("FGC36_ANALYTICAL_HEAD_CLOSURE=PASS")
            print("FGC36_LIVE_SIGN_CLOSURE=PASS")
        finally:
            if initialized:
                mf6.finalize()


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    bridge_library = Path(os.environ["FGC34_BRIDGE_LIB"]).resolve()

    require(libmf6.is_file(), f"LIBMF6 does not exist: {libmf6}")
    require(bridge_library.is_file(), f"FGC34 bridge library does not exist: {bridge_library}")

    publisher = Fgc34CtypesPublisher(bridge_library)
    test_real_fgc34_bridge_fail_closed(publisher)
    test_live_modflow6(libmf6, publisher)

    print("FGC36_LIVE_MODFLOW6_BRIDGE_GATE=PASS")


if __name__ == "__main__":
    main()
