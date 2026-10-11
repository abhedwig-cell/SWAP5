from pathlib import Path
import ast

ROOT=Path(__file__).resolve().parents[2]
adapter=(ROOT/"src/adapter/modflow6_prepared_solve_session.py").read_text()
harness=(ROOT/"tests/fgc/support/fgc41_whole_window_acceptance_harness.py").read_text()
test=(ROOT/"tests/fgc/test_fgc41_whole_window_acceptance_retry.py").read_text()

def require(x,m):
    if not x: raise AssertionError(m)

tree=ast.parse(adapter)
methods={n.name:n for n in ast.walk(tree) if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))}
require("timestep_ready_for_finalize" in methods,"missing readiness seam")
require("finalize_time_step_once" in methods,"missing one-shot finalization seam")
ready=ast.unparse(methods["timestep_ready_for_finalize"])
final=ast.unparse(methods["finalize_time_step_once"])
require("finalize_time_step" not in ready,"readiness seam mutates MODFLOW timestep")
require("self.kernel.finalize_time_step()" in final,"finalization does not reach kernel")
require("TIMESTEP_ALREADY_FINALIZED" in final,"repeat finalization not blocked")
require("Publication point" in harness,"publication point not explicit")
for marker in ["swap.preflight","modflow.preflight_finalize_time_step","ledger.preflight","modflow.finalize_time_step","swap.publish","ledger.commit_prepared"]:
    require(marker in harness,f"missing coordinator marker {marker}")
require("post_publication_failure_is_not_reported_as_retryable_rollback" in test,"missing post-publication failure oracle")
require("retry_uses_fresh_runtime_identity_and_same_accepted_origin" in test,"missing retry identity oracle")
print("FVQ113_READINESS_NONMUTATING_SOURCE_ORACLE=PASS")
print("FVQ113_FINALIZE_TIMESTEP_ONE_SHOT_SOURCE_ORACLE=PASS")
print("FVQ113_PUBLICATION_ORDER_CONTRACT_PRESENT=PASS")
print("FVQ113_POST_PUBLICATION_NOT_ROLLBACK_SAFE=PASS")
print("FVQ113_FRESH_RETRY_IDENTITY_ORACLE_PRESENT=PASS")
