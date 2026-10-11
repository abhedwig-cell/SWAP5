from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"src"/"adapter"))

from modflow6_groundwater_application_service import (
    GroundwaterApplicationCorrectorBatch,
    GroundwaterApplicationPlanView,
    GroundwaterApplicationServiceConfig,
    GroundwaterApplicationServiceStatus,
    run_groundwater_application_window,
)
from modflow6_prepared_solve_session import PreparedSolveIteration, PreparedSolveStatus

SRC=(ROOT/"src"/"adapter"/"modflow6_groundwater_application_service.py").read_text()
LOW=SRC.lower()

def require(x,msg):
    if not x:
        raise AssertionError(msg)

for forbidden in (
    "7001","7002","fgc44","fgc45","fgc46","fgc47",
    "86400.0","area_fraction","q_u_at_reference_m_per_s","dq_u_dh_per_s",
    "reference_volume_flux_m3_per_day",
    "compose_modflow6_multiswap_cell_response",
    "compose_modflow6_linear_boundary_term",
):
    require(forbidden not in LOW,f"production service hardcodes downstream authority: {forbidden}")

require("modflow6preparedsolvesession" in LOW,"prepared-solve backend not consumed")
require("evaluate_groundwater_fluxes" in LOW,"runtime-owned groundwater flux evaluation absent")
require("relinearize_terms" in LOW,"runtime-owned physical relinearization absent")
require("all(" in LOW and "flux_tolerance_m_per_s" in LOW,"all-cell convergence predicate absent")

pub=LOW.split("def _publish_converged_window",1)[1]
order=[pub.index(x) for x in (
    "runtime.swap_preflight",
    "runtime.prepare_ledgers",
    "runtime.ledgers_preflight",
    "groundwater.timestep_ready_for_finalize",
    "groundwater.finalize_time_step_once",
    "runtime.commit_swaps",
    "runtime.commit_ledgers",
)]
require(order==sorted(order),"publication ordering changed")
require("groundwaterapplicationpublicationinvarianterror" in pub,"post-publication hard-failure class absent")

@dataclass(frozen=True)
class B:
    groundwater_cell_id:int
    package_slot:int
    modflow_node_id:int

@dataclass(frozen=True)
class T:
    groundwater_cell_id:int
    hcof_m2_per_day:float
    rhs_m3_per_day:float
    valid:bool=True

class R:
    def __init__(self,events):
        self.events=events
        self.calls=0
        self.discards=0
    def materialize_plan(self):
        return GroundwaterApplicationPlanView(
            bindings=(B(11,1,1),B(22,2,2)),
            terms=(T(11,1.0,2.0),T(22,1.0,2.0)),
            cell_ids=(11,22),
        )
    def capture_origins(self): return True
    def evaluate_groundwater_fluxes(self,terms,heads): return (0.0,0.0)
    def trial_cell_heads(self,heads):
        self.calls+=1
        if self.calls==1:
            return GroundwaterApplicationCorrectorBatch(True,(2.0e-6,-2.0e-6),(0.0,0.0))
        return GroundwaterApplicationCorrectorBatch(True,(0.0,0.0),(0.0,0.0))
    def discard_candidates(self):
        self.discards+=1
        return True
    def relinearize_terms(self,heads,q,dq): return (T(11,1.0,3.0),T(22,1.0,3.0))
    def swap_preflight(self):
        self.events.append("swap_preflight"); return True
    def prepare_ledgers(self):
        self.events.append("ledger_prepare"); return True
    def ledgers_preflight(self):
        self.events.append("ledger_preflight"); return True
    def abort_prepublication(self): return True
    def commit_swaps(self):
        self.events.append("swap_commit"); return True
    def commit_ledgers(self):
        self.events.append("ledger_commit"); return True

class G:
    def __init__(self,events):
        self.events=events
        self.i=0
        self.finalized=False
        self.published=False
    def acquire_after_prepare_time_step(self): return PreparedSolveStatus.OK
    def open_prepared_solve(self): return PreparedSolveStatus.OK
    def publish_and_solve_iteration(self,bindings,terms):
        self.i+=1
        return PreparedSolveStatus.OK, PreparedSolveIteration(
            iteration=self.i,
            modflow_converged=True,
            head_m=np.array([1.0,2.0],dtype=float),
            accepted_head_old_m=np.array([1.0,2.0],dtype=float),
        )
    def finalize_prepared_solve(self):
        self.finalized=True
        self.events.append("finalize_solve")
        return PreparedSolveStatus.OK
    def timestep_ready_for_finalize(self):
        self.events.append("modflow_preflight")
        return self.finalized and not self.published
    def finalize_time_step_once(self):
        self.published=True
        self.events.append("modflow_commit")
        return PreparedSolveStatus.OK
    def invalidate_without_finalize(self): self.events.append("invalidate")

events=[]
runtime=R(events)
groundwater=G(events)
result=run_groundwater_application_window(
    runtime,groundwater,GroundwaterApplicationServiceConfig(1.0e-9,3)
)
require(result.status==GroundwaterApplicationServiceStatus.OK and result.published,"independent service execution")
require(result.iterations==2,"opposite cell residuals were incorrectly cancelled")
require(runtime.discards==1,"nonconverged candidate not discarded")
sequence=[events.index(x) for x in (
    "finalize_solve","swap_preflight","ledger_prepare","ledger_preflight",
    "modflow_preflight","modflow_commit","swap_commit","ledger_commit",
)]
require(sequence==sorted(sequence),"behavioral publication order")

print("FVQ123_NO_TOPOLOGY_SPECIFIC_BRANCHES=PASS")
print("FVQ123_NO_FGC40_FGC33_MATH_DUPLICATION=PASS")
print("FVQ123_RUNTIME_PORT_OWNS_EVALUATION_AND_REANCHOR=PASS")
print("FVQ123_OPPOSITE_CELL_RESIDUALS_DO_NOT_CANCEL=PASS")
print("FVQ123_CONJUNCTIVE_ALL_CELL_CONVERGENCE=PASS")
print("FVQ123_PREFLIGHT_BEFORE_PUBLICATION=PASS")
print("FVQ123_MODFLOW_THEN_SWAP_THEN_LEDGER_ORDER=PASS")
print("FVQ123_POST_PUBLICATION_HARD_FAILURE_CONTRACT=PASS")
print("F-VQ123 F-GC49C INDEPENDENT QUALIFICATION PASS")
