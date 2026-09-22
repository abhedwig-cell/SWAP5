from __future__ import annotations
import math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/"tests"/"research"/"support"))
from gc_rootzone_memory import RootZoneMemoryParameters,RootZoneMemoryState
from gc_rootzone_memory_nonlinear import NonlinearRootZoneMemoryOracle
from gc_rootzone_memory_management import irrigation_decision,run_managed_window
P=RootZoneMemoryParameters(.20,.10,.50,.25,.100,8.,.200); O=NonlinearRootZoneMemoryOracle(P,4.0)
def close(a,b,t=2e-10):
    if not math.isclose(a,b,rel_tol=0,abs_tol=t): raise AssertionError((a,b))
def run(w=.08,a=.02,root=0.,hl=8.,H=8.,target=.10):
    return run_managed_window(O,RootZoneMemoryState(w,hl),target,a,root,0.,H,1.,4096)
def test_full_supply_frozen_request():
    r=run();close(r.decision.request_m,.02);close(r.decision.delivered_m,.02);close(r.decision.shortage_m,0)
def test_partial_supply_shortage_diagnostic_only():
    r=run(a=.005);close(r.decision.shortage_m,.015)
    if hasattr(r.hydraulic.state,"shortage_m"): raise AssertionError("shortage leaked into physical state")
def test_identical_accepted_root_state_gives_identical_next_request():
    target=.10; w=.08
    # Equal total root input, but one history labels more of it irrigation and the other rain.
    a=run_managed_window(O,RootZoneMemoryState(w,8.),target,.005,.015,0.,8.,1.,4096)
    b=run_managed_window(O,RootZoneMemoryState(w,8.),target,.020,0.,0.,8.,1.,4096)
    close(a.hydraulic.state.root_storage_m,b.hydraulic.state.root_storage_m)
    close(a.next_request_m,b.next_request_m)
    if not a.decision.shortage_m>b.decision.shortage_m: raise AssertionError("histories not distinct")
def test_rain_can_erase_next_demand_after_shortage():
    r=run(a=.005,root=.030)
    if not r.decision.shortage_m>0: raise AssertionError()
    close(r.next_request_m,0.0)
def test_loss_after_full_supply_creates_next_demand():
    # Negative external root term is a prescribed physical loss in this analytical ledger.
    r=run(a=.02,root=-.010)
    if not r.next_request_m>0: raise AssertionError(r.next_request_m)
def test_request_is_frozen_from_committed_state():
    d=irrigation_decision(.08,.10,.05);close(d.request_m,.02);close(d.delivered_m,.02)
    r=run(a=.05,root=-.015)
    close(r.decision.request_m,.02);close(r.decision.delivered_m,.02)
def test_managed_input_booked_once_and_swap_ledger_closes():
    r=run(a=.013,root=.004,H=7.97)
    close(r.hydraulic.swap_mass_error_m,0)
    close(r.hydraulic.swap_external_input_m,r.decision.delivered_m+.004)
def test_groundwater_transfer_remains_only_interface_exchange():
    r=run(a=.01,H=8.10,hl=8.0)
    if not r.hydraulic.interface_exchange_m<0: raise AssertionError()
    close(r.hydraulic.swap_total_storage_change_m,r.decision.delivered_m-r.hydraulic.interface_exchange_m)
def test_transactional_repeatability():
    s=RootZoneMemoryState(.08,8.)
    a=run_managed_window(O,s,.10,.01,.003,0.,8.,1.,4096)
    _=run_managed_window(O,s,.10,.02,-.005,0.,8.1,1.,4096)
    b=run_managed_window(O,s,.10,.01,.003,0.,8.,1.,4096)
    if a!=b: raise AssertionError("trial order changed result")
def main():
    ts=[test_full_supply_frozen_request,test_partial_supply_shortage_diagnostic_only,test_identical_accepted_root_state_gives_identical_next_request,test_rain_can_erase_next_demand_after_shortage,test_loss_after_full_supply_creates_next_demand,test_request_is_frozen_from_committed_state,test_managed_input_booked_once_and_swap_ledger_closes,test_groundwater_transfer_remains_only_interface_exchange,test_transactional_repeatability]
    for t in ts:t();print(t.__name__+"=PASS")
    print("GC_RZM05_TESTS=9/9");print("GC_RZM05_GATE=PASS")
if __name__=="__main__":main()
