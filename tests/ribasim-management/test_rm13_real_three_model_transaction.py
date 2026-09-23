from __future__ import annotations

import math
import os
import shutil
import sys
import tempfile
from pathlib import Path

import netCDF4
import numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"ribasim-management"/"support"))

# Import F-GC44 one-cell helpers under the canonical closeout profile.
os.environ["FGC44_CLOSEOUT_ONECELL"]="1"
os.environ["FGC44_CLOSEOUT_COMPATIBLE_SOLVER"]="1"
from test_fgc44_real_swap_modflow_end_to_end import (  # noqa: E402
    Binding, Term, CountingKernel, build_model, read_modflow_component_balance,
    DAY_TO_S, AREA_M2, FLUX_TOL,
)
from fgc44_real_swap_ctypes import Fgc44RealSwap  # noqa: E402
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher  # noqa: E402
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus  # noqa: E402
from rm13_management_ctypes import Rm13Management  # noqa: E402

RIBASIM_ROOT=Path(os.environ["RM13_RIBASIM_ROOT"]).resolve()
sys.path.insert(0,str(RIBASIM_ROOT/"python"/"ribasim_api"))
from ribasim_api import RibasimApi  # noqa: E402

WINDOW_DAY=1.0e-4
WINDOW_S=8.64
REQUEST_DEPTH_CM=0.0036
IRRIGATION_RATE_CM_DAY=36.0
SURFACE_VOLUME_M3=3.6e-5
RIBASIM_ORIGIN_ID=130013
DEPTH_TOL=1.0e-8
VOLUME_TOL=1.0e-10
HEAD_REPLAY_TOL=1.0e-10


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def make_ribasim_api_copy(source_lib: Path, dep_dir: Path, tag: str, workdir: Path) -> RibasimApi:
    # JuliaC's release library may resolve sibling runtime files relative to
    # $ORIGIN. Give each candidate a distinct main-library inode/global state
    # while preserving the exact official release dependency tree.
    candidate_dir=workdir/tag
    candidate_dir.mkdir(parents=True)
    for entry in dep_dir.iterdir():
        target=candidate_dir/entry.name
        if entry.resolve()==source_lib.resolve():
            shutil.copy2(entry,target)
        else:
            target.symlink_to(entry)
    target=candidate_dir/source_lib.name
    return RibasimApi(target,candidate_dir)


def ribasim_snapshot(api: RibasimApi) -> tuple[float,float,float]:
    t=float(api.get_current_time())
    level=float(np.asarray(api.get_value_ptr("basin.level"),dtype=float)[0])
    supply=float(np.asarray(api.get_value_ptr("user_demand.cumulative_inflow"),dtype=float)[0])
    return t,level,supply


def read_allocation_depth(model_dir: Path) -> tuple[float,float]:
    files=list(model_dir.rglob("allocation.nc"))
    require(len(files)==1,f"expected one allocation.nc, found {files}")
    with netCDF4.Dataset(files[0]) as ds:
        allocated=np.asarray(ds.variables["allocated"][:],dtype=float)
        supplied=np.asarray(ds.variables["supplied"][:],dtype=float)
        alloc_values=allocated[np.isfinite(allocated)]
        supply_values=supplied[np.isfinite(supplied)]
        require(alloc_values.size>=1,"allocation output has no finite allocated value")
        require(supply_values.size>=1,"allocation output has no finite supplied value")
        alloc_rate=float(alloc_values[-1])
        supplied_rate=float(supply_values[-1])
    alloc_depth=alloc_rate*WINDOW_S/AREA_M2*100.0
    supplied_depth=supplied_rate*WINDOW_S/AREA_M2*100.0
    return alloc_depth,supplied_depth


def run_groundwater_candidate(
    *,
    libmf6:Path,
    swaplib:Path,
    swap:Fgc44RealSwap,
    hcof:float,
    rhs:float,
    href:float,
    publish:bool,
) -> dict[str,float|int]:
    with tempfile.TemporaryDirectory(prefix="rm13-mf6-") as tmp:
        workdir=Path(tmp)
        build_model(workdir,href)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        final_head=None; final_q_swap=None; final_q_gw=None; final_iterations=None
        current_hcof=hcof; current_rhs=rhs
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),"wrong MODFLOW version")
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            accepted_xold=session.accepted_xold.copy()

            for outer in range(1,min(40,session.max_solve_iterations)+1):
                status,it=session.publish_and_solve_iteration(
                    [Binding(7001,1,1)],[Term(7001,current_hcof,current_rhs)]
                )
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,f"missing MODFLOW iterate {outer}")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),"MODFLOW XOLD drifted")
                head=float(it.head_m[0])
                q_gw=(current_hcof*head-current_rhs)/(AREA_M2*DAY_TO_S)
                q_swap=swap.trial(head)
                q_diag,_,dq_swap_dh,tangent_available=swap.last_trial_response()
                require(abs(q_diag-q_swap)<=64*np.finfo(float).eps*max(1.0,abs(q_swap)),"trial q mismatch")
                require(tangent_available and math.isfinite(dq_swap_dh) and dq_swap_dh<0.0,
                        "real SWAP physical tangent unavailable")
                residual=q_swap-q_gw
                require(all(math.isfinite(x) for x in (head,q_gw,q_swap,dq_swap_dh,residual)),
                        "nonfinite coupled iterate")
                if it.modflow_converged and abs(residual)<=FLUX_TOL:
                    final_head=head; final_q_swap=q_swap; final_q_gw=q_gw; final_iterations=outer
                    break
                swap.discard()
                current_hcof=dq_swap_dh*AREA_M2*DAY_TO_S
                current_rhs=current_hcof*head-q_swap*AREA_M2*DAY_TO_S

            require(final_head is not None,"irrigated real SWAP + MODFLOW candidate did not converge")
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)

            if publish:
                require(swap.swap_preflight(),"Richards SWAP preflight failed")
                swap.prepare_ledger()
                require(swap.ledger_preflight(),"groundwater ledger preflight failed")
                require(session.timestep_ready_for_finalize(),"MODFLOW timestep not ready")
                require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
                swap.commit_swap()
                swap.commit_ledger()
            else:
                swap.discard()

            raw.finalize(); initialized=False
            expected_api=final_q_swap*AREA_M2*DAY_TO_S
            balance=read_modflow_component_balance(workdir,expected_api)
            require(balance[6],"MODFLOW native component balance gate failed")
            require(balance[7],"MODFLOW API component gate failed")
            return {
                "head":float(final_head),
                "q_swap":float(final_q_swap),
                "q_gw":float(final_q_gw),
                "iterations":int(final_iterations),
                "mf_balance_residual":float(balance[2]),
                "api_component":float(balance[4]),
            }
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


def main()->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["RM13_SWAP_LIB"]).resolve()
    ribasim_model=Path(os.environ["RM13_RIBASIM_MODEL"]).resolve()
    ribasim_lib=Path(os.environ["RM13_LIBRIBASIM"]).resolve()
    ribasim_dep=ribasim_lib.parent
    require(libmf6.is_file(),"missing MODFLOW shared library")
    require(swaplib.is_file(),"missing SWAP shared library")
    require(ribasim_model.is_file(),"missing Ribasim model")
    require(ribasim_lib.is_file(),"missing exact-release libribasim")

    management=Rm13Management(swaplib)
    requested=management.initialize()
    require(abs(requested-REQUEST_DEPTH_CM)<=DEPTH_TOL,"SWAP management request changed")
    require(management.state()[0]==0,"management origin revision not zero")

    with tempfile.TemporaryDirectory(prefix="rm13-ribasim-libs-") as libtmp:
        libtmp_path=Path(libtmp)
        accepted=make_ribasim_api_copy(ribasim_lib,ribasim_dep,"accepted",libtmp_path)
        candidate_a=make_ribasim_api_copy(ribasim_lib,ribasim_dep,"candidate_a",libtmp_path)
        candidate_b=make_ribasim_api_copy(ribasim_lib,ribasim_dep,"candidate_b",libtmp_path)

        accepted.initialize(str(ribasim_model))
        origin_snapshot=ribasim_snapshot(accepted)
        require(abs(origin_snapshot[0])<=1e-12,"Ribasim accepted origin not t0")
        require(abs(origin_snapshot[1]-1.0)<=1e-10,"Ribasim accepted level changed")
        require(abs(origin_snapshot[2])<=VOLUME_TOL,"Ribasim accepted supply ledger nonzero")

        # Candidate A is explicitly rejected after full real execution.
        candidate_a.initialize(str(ribasim_model))
        candidate_a.update_until(WINDOW_S)
        a_snapshot=ribasim_snapshot(candidate_a)
        require(abs(a_snapshot[0]-WINDOW_S)<=1e-9,"candidate A endpoint")
        a_depth=a_snapshot[2]/AREA_M2*100.0
        require(abs(a_depth-REQUEST_DEPTH_CM)<=DEPTH_TOL,"candidate A physical supply")
        candidate_a.finalize()
        alloc_a,output_supply_a=read_allocation_depth(ribasim_model.parent)
        require(abs(alloc_a-REQUEST_DEPTH_CM)<=DEPTH_TOL,"candidate A allocation")
        require(abs(output_supply_a-REQUEST_DEPTH_CM)<=DEPTH_TOL,"candidate A allocation output supplied")
        require(ribasim_snapshot(accepted)==origin_snapshot,"discarded Ribasim candidate changed accepted witness")

        # Candidate B remains live and provisional through all other model preflights.
        candidate_b.initialize(str(ribasim_model))
        candidate_b.update_until(WINDOW_S)
        b_snapshot=ribasim_snapshot(candidate_b)
        b_depth=b_snapshot[2]/AREA_M2*100.0
        require(abs(b_depth-a_depth)<=DEPTH_TOL,"same-origin Ribasim physical replay")
        require(abs(b_snapshot[1]-a_snapshot[1])<=HEAD_REPLAY_TOL,"same-origin Ribasim level replay")
        require(ribasim_snapshot(accepted)==origin_snapshot,"candidate B changed accepted Ribasim witness")

        net_a,rate_a=management.prepare_candidate(
            ribasim_origin_id=RIBASIM_ORIGIN_ID,
            ribasim_origin_revision=0,
            allocated_depth_cm=alloc_a,
            supplied_depth_cm=b_depth,
            source_level_margin_m=0.1,
            level_difference_threshold_m=0.02,
            low_storage_factor=1.0,
        )
        require(management.preflight(),"management candidate A preflight")
        require(abs(net_a-b_depth)<=DEPTH_TOL,"zero-cover Rutter gross/net identity")
        require(abs(rate_a-IRRIGATION_RATE_CM_DAY)<=1e-10,"management gross rate")
        management.discard()
        require(management.state()[0]==0,"discarded management candidate mutated origin")

        net_b,rate_b=management.prepare_candidate(
            ribasim_origin_id=RIBASIM_ORIGIN_ID,
            ribasim_origin_revision=0,
            allocated_depth_cm=alloc_a,
            supplied_depth_cm=b_depth,
            source_level_margin_m=0.1,
            level_difference_threshold_m=0.02,
            low_storage_factor=1.0,
        )
        require(management.preflight(),"management replay candidate preflight")
        require(abs(net_b-net_a)<=DEPTH_TOL and abs(rate_b-rate_a)<=1e-12,
                "management same-origin replay drift")

        top_flux=-net_b/WINDOW_DAY
        require(abs(top_flux+IRRIGATION_RATE_CM_DAY)<=1e-10,"Richards top irrigation flux")

        swap=Fgc44RealSwap(swaplib)
        hcof,rhs,href=swap.initialize_forced(WINDOW_DAY,1.0e-6,top_flux)
        swap_origin=swap.state()
        require(swap_origin==(0,0.0,0,0.0),"Richards/GW origin changed before coupling")

        e1=swap.e1_diagnostics()
        require(bool(e1["mass_complete"]),"irrigated predictor mass accounting incomplete")
        expected_predictor_in=(IRRIGATION_RATE_CM_DAY+1.0e-6)*WINDOW_DAY
        require(abs(float(e1["total_in_native"])-expected_predictor_in)<=1e-10,
                "real Richards predictor did not book irrigation top inflow exactly once")

        first=run_groundwater_candidate(
            libmf6=libmf6,swaplib=swaplib,swap=swap,hcof=hcof,rhs=rhs,href=href,publish=False
        )
        require(swap.state()==swap_origin,"rejected Richards+MODFLOW candidate mutated accepted state")

        second=run_groundwater_candidate(
            libmf6=libmf6,swaplib=swaplib,swap=swap,hcof=hcof,rhs=rhs,href=href,publish=True
        )
        require(abs(float(first["head"])-float(second["head"]))<=HEAD_REPLAY_TOL,
                "groundwater endpoint replay drift")
        require(abs(float(first["q_swap"])-float(second["q_swap"]))<=FLUX_TOL,
                "groundwater transfer replay drift")

        # At this point MODFLOW, Richards SWAP and groundwater ledger are published.
        # Management and surface-water state were still provisional until all those
        # preflights and the coupled solve succeeded.
        require(management.preflight(),"management preflight lost before publication")
        management.commit()
        management_state=management.state()
        require(management_state[0]==1,"management commit revision")
        require(abs(management_state[3]-b_depth)<=DEPTH_TOL,"management accepted supplied depth")
        require(abs(management_state[4]-net_b)<=DEPTH_TOL,"management accepted net irrigation")

        # Candidate B is now the accepted Ribasim state. Finalize only after the
        # outer publication point, then verify its allocation output as a
        # post-publication consistency check.
        accepted_surface_snapshot=b_snapshot
        candidate_b.finalize()
        alloc_b,output_supply_b=read_allocation_depth(ribasim_model.parent)
        require(abs(alloc_b-alloc_a)<=DEPTH_TOL,"candidate B allocation replay drift")
        require(abs(output_supply_b-b_depth)<=DEPTH_TOL,"candidate B output physical supply drift")
        require(ribasim_snapshot(accepted)==origin_snapshot,"original Ribasim witness mutated")
        accepted.finalize()

    richards_state=swap.state()
    require(richards_state[0]==1 and richards_state[2]==1,
            "Richards SWAP and groundwater ledger did not commit exactly once")
    surface_volume=b_depth/100.0*AREA_M2
    require(abs(surface_volume-SURFACE_VOLUME_M3)<=VOLUME_TOL,"surface transfer volume")
    require(abs(net_b/100.0*AREA_M2-surface_volume)<=VOLUME_TOL,
            "surface donor/receiver ledger mismatch")
    require(abs(float(second["q_swap"])-float(second["q_gw"]))<=FLUX_TOL,
            "groundwater action/reaction mismatch")

    print(f"RM13_SURFACE_REQUEST_DEPTH_CM={requested:.17g}")
    print(f"RM13_SURFACE_ALLOCATED_DEPTH_CM={alloc_b:.17g}")
    print(f"RM13_SURFACE_SUPPLIED_DEPTH_CM={b_depth:.17g}")
    print(f"RM13_SURFACE_TRANSFER_M3={surface_volume:.17g}")
    print(f"RM13_RICHARDS_TOP_FLUX_CM_PER_DAY={top_flux:.17g}")
    print(f"RM13_COUPLED_HEAD_M={float(second['head']):.17g}")
    print(f"RM13_GROUNDWATER_Q_SWAP_M_PER_S={float(second['q_swap']):.17g}")
    print(f"RM13_GROUNDWATER_Q_GW_M_PER_S={float(second['q_gw']):.17g}")
    print(f"RM13_GROUNDWATER_LEDGER_EXCHANGE_M={richards_state[3]:.17g}")
    print(f"RM13_RIBASIM_ACCEPTED_LEVEL_M={accepted_surface_snapshot[1]:.17g}")
    print("RM13_RIBASIM_REJECT_REPLAY=PASS")
    print("RM13_MANAGEMENT_REJECT_REPLAY=PASS")
    print("RM13_RICHARDS_MODFLOW_REJECT_REPLAY=PASS")
    print("RM13_SURFACE_WATER_LEDGER=PASS")
    print("RM13_GROUNDWATER_LEDGER=PASS")
    print("RM13_EXACTLY_ONCE_SWAPP_PUBLICATION=PASS")
    print("RM13 REAL SWAP MODFLOW RIBASIM TRIANGLE GATE PASS")


if __name__=="__main__":
    main()
