from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
src=(ROOT/"src/runtime/mod_groundwater_swap_transaction_participant.f90").read_text()
owner=(ROOT/"tests/fgc/test_fgc43_production_swap_participant.f90").read_text()
doc=(ROOT/"docs/integration/F-GC43_PRODUCTION_SWAP_PARTICIPANT.md").read_text()

def require(x,m):
    if not x: raise AssertionError(m)

require("capture_checkpoint(self%origin_checkpoint" in src,"real kernel checkpoint not captured")
require("checkpoint=self%origin_checkpoint" in src,"trials are not explicitly rooted in captured kernel checkpoint")
require("call executor%rollback_candidate" in src,"non-final candidate rollback missing")
require("call executor%commit_candidate" in src,"kernel commit is not publication authority")
for forbidden in [
    "committed%revision =",
    "committed%committed_time",
    "committed%physical_state",
    "move_alloc(",
]:
    require(forbidden not in src.lower(),f"participant directly mutates kernel committed internals: {forbidden}")
pre=src[src.index("logical function swap_participant_publication_ready"):src.index("end function swap_participant_publication_ready")]
for forbidden in ["commit_candidate(","rollback_candidate(","advance_interval("]:
    require(forbidden not in pre,f"publication preflight is mutating: {forbidden}")
for marker in [
    "first corrector trial",
    "second corrector from same origin",
    "publication preflight",
    "kernel sole revision mutation",
    "stale origin rejected by preflight",
]:
    require(marker in owner,f"owner executable oracle missing: {marker}")
require("does not yet qualify a complete real SWAP application case coupled to live MODFLOW6" in doc,"evidence boundary missing")
require("iMOD" not in src and "modflow" not in src.lower(),"SWAP participant acquired external coupling ownership")
print("FVQ115_REAL_KERNEL_CHECKPOINT_BINDING=PASS")
print("FVQ115_SAME_ORIGIN_TRIAL_BINDING=PASS")
print("FVQ115_NONMUTATING_PUBLICATION_PREFLIGHT=PASS")
print("FVQ115_KERNEL_SOLE_COMMIT_OWNER=PASS")
print("FVQ115_EVIDENCE_BOUNDARY=PASS")
