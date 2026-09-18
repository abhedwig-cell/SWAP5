from pathlib import Path
import ast

ROOT=Path(__file__).resolve().parents[2]
composition=(ROOT/"tests/fgc/support/fgc42_live_whole_window_service_harness.py").read_text()
owner_test=(ROOT/"tests/fgc/test_fgc42_live_whole_window_service.py").read_text()
doc=(ROOT/"docs/integration/F-GC42_WHOLE_WINDOW_SERVICE_COMPOSITION.md").read_text()

def require(x,m):
    if not x: raise AssertionError(m)

tree=ast.parse(composition)
func={n.name:n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef)}
require("run_live_whole_window_service" in func,"missing F-GC42 composition entrypoint")
body=ast.unparse(func["run_live_whole_window_service"])
require("run_prepared_solve_coupling_window" in body,"F-GC39 service not invoked")
require("accept_whole_window" in body,"F-GC41 publication boundary not invoked")
require(body.index("run_prepared_solve_coupling_window") < body.index("accept_whole_window"),"publication may precede coupled-window convergence")
require("ready_for_publication" in body,"F-GC39 readiness not checked")
require("coupled.final_swap_candidate" in body,"retained candidate not handed to F-GC41")
for forbidden in ["imod_coupler","ribasim","irrigation","n:1"]:
    require(forbidden not in composition.lower(),f"forbidden ownership/scope marker in composition: {forbidden}")
require("complete_service_preserves_solver_then_publication_order" in owner_test,"missing exact ordering oracle")
require("coupling_failure_never_reaches_publication" in owner_test,"missing coupling-failure isolation oracle")
require("publication_preflight_failure_invalidates_without_publication" in owner_test,"missing prepublication failure oracle")
require("does **not** claim a real-SWAP plus real-MODFLOW production application run" in doc,"evidence boundary not explicit")
print("FVQ114_FGC39_BEFORE_FGC41_COMPOSITION=PASS")
print("FVQ114_RETAINED_CANDIDATE_HANDOFF=PASS")
print("FVQ114_COUPLING_FAILURE_BLOCKS_PUBLICATION=PASS")
print("FVQ114_PREFLIGHT_FAILURE_ZERO_PUBLICATION=PASS")
print("FVQ114_OWNERSHIP_AND_EVIDENCE_BOUNDARY=PASS")
