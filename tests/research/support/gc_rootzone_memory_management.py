from __future__ import annotations
from dataclasses import dataclass
from gc_rootzone_memory import RootZoneMemoryForcing, RootZoneMemoryState
from gc_rootzone_memory_nonlinear import NonlinearRootZoneMemoryOracle

@dataclass(frozen=True)
class ManagementDecision:
    request_m: float
    delivered_m: float
    shortage_m: float

@dataclass(frozen=True)
class ManagedWindowResult:
    decision: ManagementDecision
    hydraulic: object
    next_request_m: float

def irrigation_decision(committed_root_storage_m: float, target_storage_m: float, available_supply_m: float) -> ManagementDecision:
    if target_storage_m < 0 or available_supply_m < 0:
        raise ValueError("target and supply must be nonnegative")
    request=max(0.0,target_storage_m-committed_root_storage_m)
    delivered=min(request,available_supply_m)
    return ManagementDecision(request,delivered,request-delivered)

def run_managed_window(oracle: NonlinearRootZoneMemoryOracle,state0: RootZoneMemoryState,target_storage_m: float,available_supply_m: float,root_external_m: float,lower_external_m: float,interface_head_m: float,dt_day: float,substeps: int) -> ManagedWindowResult:
    d=irrigation_decision(state0.root_storage_m,target_storage_m,available_supply_m)
    forcing=RootZoneMemoryForcing((d.delivered_m+root_external_m)/dt_day,lower_external_m/dt_day)
    h=oracle.solve_prescribed_interface(state0,forcing,interface_head_m,dt_day,substeps)
    nxt=max(0.0,target_storage_m-h.state.root_storage_m)
    return ManagedWindowResult(d,h,nxt)
