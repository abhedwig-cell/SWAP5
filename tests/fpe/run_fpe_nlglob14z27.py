#!/usr/bin/env python3
from pathlib import Path
import json,re
p=Path("tests/fpe/run_fpe_nlglob14z26_segment.py")
s=p.read_text()

checks={
  "state_vector_fixed_16":"h=h0[:]" in s and "r=[0.0]*16" in s,
  "jacobian_fixed_16":"jac=[[0.0]*16 for _ in range(16)]" in s,
  "jacobian_columns_fixed_16":"for j in range(16):" in s,
  "linear_solution_fixed_16":"x=[0.0]*n" in s and "n=len(b)" in s,
  "upper_n_changes_residual_partition":"for i in range(upper_n):" in s and "j=upper_n" in s,
  "upper_n_does_not_size_jacobian":"jac=[[0.0]*upper_n" not in s and "range(upper_n)" not in s.split("jac=[[0.0]*16 for _ in range(16)]",1)[1][:300]
}
fixed=all(checks.values())
out={
 "classification":"FIXED_DIMENSION_RESEARCH_SOLVE" if fixed else "AMBIGUOUS_DIMENSION",
 "aggregate":"QUALIFIED_Z27_RESEARCH_HARNESS_NOT_PERFORMANCE_SHAPED" if fixed else "NLGLOB14Z27_DIMENSION_AMBIGUOUS",
 "checks":checks,
 "physical_node_count":16,
 "jacobian_dimension":16 if fixed else None,
 "speedup_from_active_block_not_measured":fixed
}
print("F_PE_NLGLOB14Z27_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
assert fixed
print("F_PE_NLGLOB14Z27=PASS")
