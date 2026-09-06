# VQ-1e1 transaction and generic-time verifier harness

**Workstream:** VQ  
**Slice:** VQ-1e1  
**Current corrected-reference oracle:** `B1.10`  
**Production code changed:** no

VQ-1e1 makes the transaction/generic-time qualification logic executable before a real B2 production seam exists, while preventing verifier self-tests from being mistaken for physics qualification.

The harness defines `QualificationAdapter.run_interval(request)` and executes:

```text
TX-ROLLBACK-01
TX-COMMIT-01
TX-ACCOUNT-01
TX-RERUN-01
TX-BC-REPLAY-01
TX-WARM-01
TIME-00
TIME-06
TIME-18
TIME-36
TIME-SPLIT
```

It checks rollback preservation of committed state, exactly-once commit/accounting, deterministic rerun, exact forcing replay, warm-start separation and exact generic interval identity. `TIME-SPLIT` additionally tests state continuity and exact equivalence only for the deterministic additive fixture.

Every accepted fixture result is passed through the VQ-1d3 canonical result validator, so VQ-1e1 does not create a second mass/result interpretation.

The fixture result is explicitly scoped:

```text
qualification_scope                  VERIFIER_HARNESS_ONLY
b2_physics_status                    NOT_EVALUATED
production_physics_executed          false
production_mass_tolerance_qualified  false
```

Fault-injection tests prove the harness rejects rollback mutation, duplicate commit, rejected-trial double accounting, rerun nondeterminism, forcing drift, warm-start physical-state substitution, calendar snapping, non-composable split behaviour and evidence drift.

The exact fixture comparator for `TIME-SPLIT` is not a production tolerance. Real B2 transaction and generic-time qualification begins only after a non-synthetic production bridge passes VQ-1e2 and VQ-1e3 execution admission.

This slice exercises verifier logic for invariants 7, 8, 9, 13, 23, 25, 26, 29 and 30 without claiming production compliance.
