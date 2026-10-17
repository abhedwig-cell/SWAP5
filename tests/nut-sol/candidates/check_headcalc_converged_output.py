#!/usr/bin/env python3
"""Source guard only: actual numerical admission requires compiled production tests."""
from pathlib import Path
s=(Path(__file__).resolve().parents[3]/"src/legacy/b1_10_port/headcalc.f90").read_text()
assert "parameter_set, accepted_top_result)" in s
assert "intent(out), optional :: accepted_top_result" in s
assert "if (present(accepted_top_result)) accepted_top_result = soil_water_top_boundary_result_t()" in s
publication=s.index("accepted_top_result = provider_dynamic_top_result")
converged=s.rfind("if (.NOT.flnonconv) then",0,publication)
assert converged>=0 and publication>converged
assert "provider_dynamic_top_result%runoff_resolved" in s[converged:publication]
assert "provider_dynamic_top_result%candidate_ponding_depth-state%pond" in s[converged:publication]
assert "ctx%control%request_dt_reduction = .TRUE." in s[publication:]
assert s.count("accepted_top_result = provider_dynamic_top_result")==1
print("HEADCALC_CONVERGED_OUTPUT_SOURCE_GUARD=PASS (static only)")
