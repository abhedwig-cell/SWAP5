#!/usr/bin/env python3
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RG = ROOT / "integration" / "f-rg"
status = json.loads((RG / "F-RG03_STATUS.json").read_text())
metrics = json.loads((RG / "F-RG03_METRICS.json").read_text())
domains = json.loads((RG / "F-RG03_DOMAIN_SNAPSHOT.json").read_text())
deps = json.loads((RG / "F-RG03_DEPENDENCY_AND_EXECUTION_WAVE.json").read_text())
index = json.loads((RG / "F-RG03_CAPABILITY_MAP_INDEX.json").read_text())

assert status["work_unit"] == "F-RG03"
assert status["decision"] == "QUALIFIED_POST_CI59P_SW5_PROGRAM_REBASELINE_AND_PARALLEL_EXECUTION_AUTHORITY"
assert status["frozen_denominator"]["unchanged"] is True
assert status["current_canonical"]["sha"] == "379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b"
assert status["current_canonical"]["tree"] == "556221f62b4fde616981499eba68ef5460f5d83c"
assert status["governance_authorities"]["F-RG01C"]["sha"] == "56b86e29e0960e396059caf47c193440d571b709"
assert status["numbering"]["resolution"].startswith("F-RG03 selected")

caps = []
for name in index["parts"]:
    caps.extend(json.loads((RG / name).read_text())["capabilities"])
ids = [c["id"] for c in caps]
assert len(ids) == 46
assert len(set(ids)) == 46
required = set(index["required_fields"])
for c in caps:
    assert required.issubset(c)

frozen = [c for c in caps if c["frozen_weight"] > 0]
assert len(frozen) == 43
assert math.isclose(sum(c["frozen_weight"] for c in frozen), 100.0, abs_tol=1e-12)
earned = sum(c["frozen_weight"] * c["completion_percent"] / 100.0 for c in frozen)
assert math.isclose(earned, 83.004545454545, abs_tol=1e-10)
assert math.isclose(metrics["overall_program_earned"], earned, abs_tol=1e-10)
assert metrics["restricted_production_baseline_percent"] == 100.0
assert metrics["technical_engine_reported_percent"] == 89.0
assert math.isclose(metrics["overall_program_reported_percent"], 83.004545454545, abs_tol=1e-10)
assert domains["fixed_denominator_authority"]["unchanged"] is True
assert next(d for d in domains["domains"] if d["id"] == "D13")["completion_percent"] == 82.0
assert len(deps["primary_lanes"]) == 4
assert all(x["v1_weight"] == 0.0 for x in deps["isolated_research"])
assert status["production_physics_changed_by_F-RG03"] is False
assert status["production_source_changed_by_F-RG03"] is False
assert status["reference_source_changed_by_F-RG03"] is False
print("FRG03_DENOMINATOR_FROZEN=PASS")
print("FRG03_CAPABILITY_MAP_46_UNIQUE_43_FROZEN=PASS")
print("FRG03_OVERALL_EARNED_83_004545454545=PASS")
print("FRG03_TECHNICAL_REPORTED_89_CEILING=PASS")
print("FRG03_FOUR_PRIMARY_LANES=PASS")
print("FRG03_ZERO_WEIGHT_RESEARCH=PASS")
print("FRG03_DECISION=QUALIFIED_POST_CI59P_SW5_PROGRAM_REBASELINE_AND_PARALLEL_EXECUTION_AUTHORITY")
