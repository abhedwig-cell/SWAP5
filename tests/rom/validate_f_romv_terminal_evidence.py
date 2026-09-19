#!/usr/bin/env python3
from __future__ import annotations
import json, subprocess
from pathlib import Path

PREIMAGE="d5587a650007e96e9f6008a179ac4bdf0cf77218"
EXPECTED={
  "docs/science/F-ROMV_COMPUTATIONAL_VALUE_GONOGO.md":"790869e446bdabddd147a4c1db95f15bb19cbfcf",
  "integration/f-rom/F-ROMV_MINIMAL_DISCRIMINATING_EXPERIMENT.json":"259af88fc6febf918b1d5214bc4442fc261a3834",
  "integration/f-rom/F-ROMV_MDE_STAGE1_PREREGISTRATION.json":"a9e51756cb9ac738a38e91ddd57f035cb7a09bc6",
  "integration/f-rom/F-ROMV_MDE_STAGE1_RESULT.json":"340685ea0cfb782b7d5ecbcff8a64ee1991f7911",
  "integration/f-rom/F-ROMV_MDE_STAGE1_STATUS.json":"ae6d67ee18294862a2f44c39e9b5c1dc8640b480",
  "docs/science/F-ROMV_MDE_STAGE1_RESULT.md":"a1eb388886632bd4226b0f5202ff327d079e5ef7",
}

def git(*args: str) -> str:
    return subprocess.check_output(["git",*args],text=True).strip()

def require(c: bool, msg: str) -> None:
    if not c:
        raise SystemExit(msg)

git("merge-base","--is-ancestor",PREIMAGE,"HEAD")
changed=[x for x in git("diff","--name-only",f"{PREIMAGE}...HEAD").splitlines() if x]
require(not [p for p in changed if p.startswith("src/") or p.startswith("reference/")],
        "production/reference mutation present")

for path,sha in EXPECTED.items():
    require(Path(path).exists(),f"missing imported authority {path}")
    require(git("hash-object",path)==sha,f"authority blob drift {path}")

status=json.loads(Path("integration/f-rom/F-ROMV_STATUS.json").read_text())
stage=json.loads(Path("integration/f-rom/F-ROMV_MDE_STAGE1_STATUS.json").read_text())
result=json.loads(Path("integration/f-rom/F-ROMV_MDE_STAGE1_RESULT.json").read_text())
manifest=json.loads(Path("integration/f-rom/F-ROMV_CANONICAL_EVIDENCE_MANIFEST.json").read_text())

require(status["phase"]=="CLOSED_NO_GO_UNDER_CURRENT_PROPOSITION","terminal phase drift")
require(status["terminal_stage"]["decision"]=="STOP_SIMPLE_TEMPLATE_LOCAL_ROM","terminal decision drift")
require(status["governance"]["production_rom_authorized"] is False,"production ROM authorized")
require(status["governance"]["rom2_authorized"] is False,"ROM2 authorized")
require(status["governance"]["cross_material_rom"]=="NOT_AUTHORIZED","cross-material ROM authorized")

require(stage["decision"]=="STOP_SIMPLE_TEMPLATE_LOCAL_ROM","stage decision drift")
require(result["decision"]=="STOP_SIMPLE_TEMPLATE_LOCAL_ROM","result decision drift")
kill=result["early_kill_triggers"]
require(kill["structural_mass_gate_failure"] is False,"mass-ledger result drift")
require(kill["wrong_nonzero_bottom_flux_sign_in_domain"] is True,"flux-sign kill missing")
require(kill["flow_reversal_timing_error_gt_one_step"] is True,"reversal kill missing")
require(kill["nonfinite_or_invalid_in_domain_reduced_transition"] is True,"physical-state kill missing")

term=manifest["terminal_adjudication"]
require(term["f_romv_closed"] is True,"manifest closure drift")
require(term["production_rom_authorized"] is False,"manifest production ROM drift")
require(term["direct_performance_comparator_stage_executed"] is False,"performance stage incorrectly executed")
require(manifest["admission_scope"]=="EVIDENCE_AND_RESEARCH_AUTHORITY_ONLY","scope drift")

print("F_ROMV_TERMINAL_EVIDENCE_GATE=PASS")
