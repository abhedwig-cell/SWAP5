# VQ-1e3 production TX/TIME execution admission

**Workstream:** VQ  
**Slice:** VQ-1e3  
**Current corrected-reference oracle:** `B1.10`  
**Production code changed:** no

## Purpose

VQ-1e3 is the boundary between qualifying verification infrastructure and actually running the transaction/generic-time suite against SWAP5 production physics.

The current repository does not yet contain an admitted B2 reference seam or a non-synthetic production `QualificationAdapter` binding. VQ-1e3 therefore implements and qualifies the **execution-admission gate** now, but deliberately does not load an adapter or execute model physics.

## Required predecessor chain

Production execution is impossible unless both earlier gates pass:

```text
VQ-1d  admitted exact B2 reference seam/result contract
   -> VQ-1e2 admitted non-synthetic production adapter binding
      -> VQ-1e3 execution admission
         -> only then load adapter and run production TX/TIME suite
```

The VQ-1e3 gate reruns VQ-1e2; a candidate cannot bypass the production-binding gate by merely declaring an adapter loader.

## Canonical suite

Execution admission requires the exact `VQ-TX-TIME-SUITE-v1` case set:

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

Missing, extra or duplicate case identities fail admission. The adapter protocol must be `VQ-QualificationAdapter-v1`.

## No premature physics claim

Before actual production execution, the candidate must state exactly:

```text
production_execution_claimed          false
b2_physics_status                     NOT_EVALUATED
production_mass_tolerance_qualified   false
```

The admission gate itself always returns `production_physics_executed = false`. A successful admission is permission to start production execution; it is not a physics result.

## Current repository state

The current B1.10 oracle is qualified. The separate SWAP-004 candidate is staged but not admitted and does not modify the B2 production observation. No callable SWAP5/B2 reference seam or production adapter implementation is integrated.

```text
B1.10 corrected-reference oracle          PASS
VQ-1d B2 target admission                  BLOCKED
VQ-1e2 production binding admission        BLOCKED
VQ-1e3 production execution admission      BLOCKED
production physics executed                false
B2 transaction qualification               NOT_EVALUATED
B2 generic-time qualification              NOT_EVALUATED
production mass tolerance qualified         false
```

Expected current failure:

```text
production_adapter_binding_not_admitted
```

This is a qualified fail-closed state, not a model failure.

## Self-qualification

`tools/vq/test_production_execution_gate.py` verifies that the gate rejects:

- a blocked predecessor binding;
- a missing adapter loader;
- a missing factory symbol;
- an adapter protocol mismatch;
- an incomplete TX/TIME suite;
- duplicate case identities;
- premature production/physics claims;
- stored evidence drift.

A complete temporary loader fixture can pass **execution admission** without being imported or executed. That confirms gate logic only.

## Architecture invariants

VQ-1e3 directly guards invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 29 and 30. It keeps the verification adapter outside the kernel and prevents tests from silently changing physics, time semantics or mass accounting.

## Next safe action after admission

Once TX/HY/RT integrate a real reference seam and non-synthetic binding on one exact commit, rerun VQ-1d, VQ-1e2 and VQ-1e3. Only after all three admit the same production target may the existing 11-case harness be instantiated against that adapter. The resulting production evidence must then record PASS/FAIL per case and independently recomputed unrounded mass accounting; it must never inherit the synthetic fixture PASS status.
