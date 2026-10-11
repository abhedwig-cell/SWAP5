import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
from fgc39_prepared_solve_service_harness import *
from fgc41_whole_window_acceptance_harness import *
from fgc42_live_whole_window_service_harness import *

class Swap:
    def __init__(self,events): self.e=events; self.origin=("accepted",7); self.candidate=None
    def capture_origin(self): self.e.append("swap-origin"); return self.origin
    def build_predictor_response(self,o): assert o is self.origin; self.e.append("predictor"); return AffineResponse(1.,0.,1.)
    def corrector_trial_from_origin(self,o,h): assert o is self.origin; self.candidate=("candidate",h); self.e.append("corrector"); return SwapCorrector(self.candidate,h,0.)
    def discard_candidate(self,c): self.e.append("swap-discard-trial"); return True
    def preflight(self,c,i): self.e.append("swap-preflight"); return c is self.candidate
    def publish(self,c,i): self.e.append("swap-publish"); return c is self.candidate
    def discard(self,c): self.e.append("swap-discard-publication")
class GW:
    def __init__(self,e): self.e=e; self.solve_final=False
    def open_window(self): self.e.append("gw-open"); return True
    def solve_iteration(self,r): self.e.append("gw-solve"); return GroundwaterIterate(True,1.,0.,True)
    def finalize_converged_solve(self): self.solve_final=True; self.e.append("gw-finalize-solve"); return True
    def invalidate_abandoned_solve(self): self.e.append("gw-invalidate")
    def preflight_finalize_time_step(self,i): self.e.append("gw-timestep-preflight"); return self.solve_final
    def finalize_time_step(self,i): self.e.append("gw-finalize-timestep"); return self.solve_final
    def invalidate_for_retry(self): self.e.append("gw-invalidate")
class Ledger:
    def __init__(self,e,expected): self.e=e; self.expected=expected
    def preflight(self,i): self.e.append("ledger-preflight"); return i==self.expected
    def commit_prepared(self,i): self.e.append("ledger-commit"); return i==self.expected
    def abort_prepared(self): self.e.append("ledger-abort")

def ident(): return WindowIdentity(41,9,0.,1.)

def test_complete_service_preserves_solver_then_publication_order():
    e=[]; i=ident(); s=Swap(e); g=GW(e); l=Ledger(e,i)
    r=run_live_whole_window_service(s,g,l,i,ServiceConfig(1e-12,2))
    assert r.published and r.acceptance_status==AcceptanceStatus.OK
    assert e==["swap-origin","predictor","gw-open","gw-solve","corrector","gw-finalize-solve","swap-preflight","gw-timestep-preflight","ledger-preflight","gw-finalize-timestep","swap-publish","ledger-commit"]

def test_coupling_failure_never_reaches_publication():
    class BadGW(GW):
        def solve_iteration(self,r): self.e.append("gw-solve"); return GroundwaterIterate(False,0.,0.,False,"bad")
    e=[]; i=ident(); r=run_live_whole_window_service(Swap(e),BadGW(e),Ledger(e,i),i,ServiceConfig(1e-12,1))
    assert r.request_smaller_window and not r.published
    assert not any(x in e for x in ["swap-preflight","gw-timestep-preflight","ledger-preflight","gw-finalize-timestep","swap-publish","ledger-commit"])

def test_publication_preflight_failure_invalidates_without_publication():
    e=[]; i=ident(); wrong=WindowIdentity(41,10,0.,1.)
    r=run_live_whole_window_service(Swap(e),GW(e),Ledger(e,wrong),i,ServiceConfig(1e-12,2))
    assert r.request_smaller_window and not r.published
    assert "gw-finalize-solve" in e and "ledger-abort" in e and "gw-invalidate" in e
    assert "gw-finalize-timestep" not in e and "swap-publish" not in e and "ledger-commit" not in e
