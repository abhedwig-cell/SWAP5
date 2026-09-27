# F-PE-BASE01 closeout — base q/state Richards solve decomposition

Date: 2026-09-27

Status: `CLOSED_NO_EXACT_BASE_SOLVE_TARGET`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Parent authority:
`integration/f-ci-canonical@c79ea4d7efb580eeb55b61a4e93b4bc6f01bfc96`

Current qualification authority:
- exercised branch head: `c5f1881d3d95695993ab6420e232adb32c9df60b`;
- workflow run: `36306634228`;
- P0: PASS;
- P1: PASS;
- P1B: PASS;
- P2: PASS as an executed comparison, with the candidate rejected by its frozen advancement rule.

## Purpose

BASE01 followed LIVE01 after the production-admitted c=0.65 path showed that unavoidable exact live corrector trials, rather than discarded-trial count, are the remaining SWAP-side performance problem.

BASE01 is observation/research only. No production `src/**` modification is admitted.

## P0 — participant/backend boundary

PASS.

Current-head aggregate:

- forcing materialization: `1.58%`;
- serialized Reference backend: `80.81%`;
- participant postprocessing: `17.27%`.

The backend therefore remains far above the preregistered 60% gate for deeper decomposition.

## P1 — q/state HeadCalc decomposition

PASS with preserved discrete trajectory:

- transaction calls: 52;
- accepted substeps: 52;
- attempts: 72;
- retries: 20;
- temporal rejections: 20;
- solver rejections: 0;
- nonlinear iterations: 236;
- backtracking attempts: 236.

Current-head aggregate:

- HeadCalc: `40.99%` of backend;
- constitutive work: about `16.53%` of backend when mapped from nested HeadCalc timing;
- backtracking loop: about `11.90%`;
- residual/vector: about `3.04%`;
- linear solve: about `2.31%`;
- Jacobian: about `1.58%`.

No isolated inner-HeadCalc family clears the 20% aggregate-backend selection gate.

## P1B — non-HeadCalc backend decomposition

PASS.

Current-head aggregate:

- backend: `831,307 ns`;
- HeadCalc: `39.69%`;
- temporal-indicator/certificate evaluation: `22.16%`;
- model-other: `12.47%`;
- kernel-other: `8.22%`;
- transaction-other: `4.71%`;
- transaction clone: `2.66%`;
- canonical preparation: `2.65%`;
- canonical-other: `1.77%`;
- transaction context: `1.01%`;
- kernel clone: `0.84%`;
- kernel post: `0.41%`.

Temporal indicator is the only isolated measured family clearing the 20% gate and it has a concrete exact-preserving candidate, so exactly that candidate advanced to P2.

## P2 — temporal-indicator demand specialization

Semantic identity: PASS.

Performance advancement: FAIL.

Current-head paired result:

- temporal-indicator gain: `10.52%`, below required 15%;
- serialized-backend gain: `3.88%`, above required 3%;
- total q/state trial gain: `2.60%`;
- max absolute q difference: `0`;
- retry/nonlinear path unchanged.

The P2 rule requires both the temporal-component and backend gates to pass.

Therefore:

`REJECT_NO_COMPOSED_RUNTIME_GAIN`.

The positive backend and total-trial timing is retained as evidence. It does not justify post-hoc relaxation of the preregistered temporal gate.

## Final interpretation

The remaining current exact q/state cost is distributed.

There is no measured exact-preserving BASE01 candidate that simultaneously:

1. owns a sufficiently large fraction of current live backend runtime; and
2. satisfies its preregistered composed-runtime qualification rule.

The obvious smaller families are below the selection gate. The one family that cleared the cost gate produced a semantically clean candidate, but that candidate missed its frozen temporal-speed threshold.

BASE01 therefore does not manufacture another optimization by relaxing thresholds after measurement.

## Deferred evidence, not selected successors

- accepted-direction work remains material at about 19% of exact trial cost from LIVE01, but missed its frozen 20% primary gate;
- constitutive work is material but below the BASE01 full-backend gate;
- discarded-trial solve elimination remains useful only for future reuse-rich coupling workloads;
- AHL/direct-retention remains a separate bounded representation line and is not admitted here by inference;
- approximate/practical modes remain separate from this exact-preserving workunit;
- the P2 demand-specialization candidate may be revisited only under a new preregistered question, not by changing BASE01 gates.

## Final decision

`F-PE-BASE01 = CLOSED_NO_EXACT_BASE_SOLVE_TARGET`

No production source change.

No change to c=0.65, temporal floor, BALTOL02, retry scale, Richards equations, nonlinear tolerances, tangent mathematics, MODFLOW equations, mass authority or publication ownership.
