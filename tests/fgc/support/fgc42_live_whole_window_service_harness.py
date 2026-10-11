from dataclasses import dataclass
from typing import Any
from fgc39_prepared_solve_service_harness import ServiceStatus, run_prepared_solve_coupling_window
from fgc41_whole_window_acceptance_harness import AcceptanceStatus, WindowIdentity, accept_whole_window

@dataclass
class WholeWindowResult:
    coupled_status: ServiceStatus
    acceptance_status: AcceptanceStatus|None
    published: bool
    request_smaller_window: bool
    failure_stage: str

def run_live_whole_window_service(swap, groundwater, ledger, identity:WindowIdentity, config)->WholeWindowResult:
    coupled=run_prepared_solve_coupling_window(swap,groundwater,config)
    if coupled.status != ServiceStatus.OK or not coupled.ready_for_publication:
        return WholeWindowResult(coupled.status,None,False,coupled.request_smaller_window,coupled.failure_stage)
    candidate=coupled.final_swap_candidate
    accepted=accept_whole_window(candidate,identity,swap,groundwater,ledger)
    return WholeWindowResult(coupled.status,accepted.status,accepted.published,accepted.request_smaller_window,accepted.failure_stage)
