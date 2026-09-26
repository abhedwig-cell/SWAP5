# F-PE-TEMPORAL03 P2 result — independent fixed-substep Reference oracle

Date: 2026-09-26

Status: `ORACLE_BLOCKED_BY_SHORT_DURATION_REFERENCE_SOLVER_FAILURE`

## Protocol

P2 attempted to construct an independent temporal oracle from the exact same P0 dynamic physical origins.

The temporal certificate was removed from the oracle path.

The full 1e-4 day corrector window was split into fixed equal Reference-floor substeps:

- N = 8;
- N = 16;
- N = 32.

The initial qualification set covered B01-wet, O05-wet, O14-wet and O14-mid, both dynamic history directions, and corrector offsets +/-0.001 and +/-0.01 cm.

## Result

No point produced a complete 8/16/32 oracle hierarchy.

Instrumentation localized the failure to the physical Reference-floor solve:

`KERNEL_REFERENCE_FLOOR_STATUS_SOLVER_FAILED = 204`

For the overwhelming majority of level/point combinations the first fixed substep fails immediately (`I=1`). A small number reach one accepted substep and fail at `I=2`.

The failure occurs before a valid floor candidate or mass result is available for the failed substep.

Therefore:

- this is not a temporal-certificate rejection;
- this is not an oracle comparison failure;
- the proposed fixed-substep Reference oracle cannot currently be constructed because the physical solver itself loses robustness as the imposed step duration is reduced.

## Relation to REPRO02

This independently reproduces the numerical behavior already exposed by the transaction retry cascade:

1. a larger/full-duration physical solve can converge;
2. temporal rejection requests a shorter duration;
3. sufficiently short-duration Reference solves can become nonlinear-failed.

P2 shows that this behavior is not specific to the canonical transaction wrapper. It also appears on the certificate-free Reference-floor path used for the independent oracle.

## Consequence

The P2 oracle acceptance gate is not met.

No N=32 solution is designated as truth.

No candidate temporal budget can be physically qualified from TEMPORAL03.

## Stop condition

The preregistered stop condition is triggered:

> fixed-substep refinement itself is nonconvergent because of a solver pathology.

This requires a separate solver diagnostic/repair line before temporal-policy admission can continue.

## Decision

Stop TEMPORAL03 policy qualification here.

Preserve P0-P1C dynamic-history evidence as characterization.

Open a separate workunit for the short-duration Reference Richards convergence pathology.

No production temporal-policy change is authorized.