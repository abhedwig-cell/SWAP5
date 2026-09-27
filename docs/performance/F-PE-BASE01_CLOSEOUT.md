# F-PE-BASE01 closeout — base q/state Richards solve decomposition

Date: 2026-09-27

Status: `CLOSED_NO_EXACT_BASE_SOLVE_TARGET`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Parent authority:
`integration/f-ci-canonical@c79ea4d7efb580eeb55b61a4e93b4bc6f01bfc96`

## Purpose

BASE01 followed LIVE01 after the current production-admitted c=0.65 path showed that unavoidable exact live corrector trials, rather than discarded-trial count, are the remaining SWAP-side performance problem.

BASE01 was observation/research only. No production `src/**` modification is admitted.

## P0 — participant/backend boundary

PASS.

Current-canonical exact trial decomposition:

- forcing materialization: about 1.7%;
- serialized Reference backend: about 83.3%;
- participant postprocessing: about 14.8%.

The backend therefore passed the preregistered 60% gate for deeper decomposition.

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

Representative current P1 authority:

- HeadCalc: about 43.8% of backend;
- constitutive work: about 17.9% of backend when mapped from the nested HeadCalc timing;
- backtracking loop: about 13.4%;
- residual/vector: about 3.2%;
- linear solve: about 2.7%;
- Jacobian: about 1.5%.

No isolated inner-HeadCalc family cleared the 20% aggregate-backend selection gate.

## P1B — non-HeadCalc backend decomposition

PASS.

Current-head authority run `36306105717`:

- backend: `503,943 ns`;
- HeadCalc: 41.81%;
- temporal-indicator/certificate evaluation: 22.36%;
- model-other: 11.40%;
- kernel-other: 7.63%;
- transaction-other: 4.94%;
- transaction clone: 2.69%;
- canonical preparation: 2.46%;
- canonical-other: 1.80%;
- transaction context: 1.37%;
- kernel clone: 0.67%;
- kernel post: 0.47%.

Temporal indicator was the only isolated measured family clearing the 20% gate and had a concrete exact-preserving candidate, so exactly that candidate advanced to P2.

## P2 — temporal-indicator demand specialization

Semantic identity: PASS.

Performance advancement: FAIL.

Observed in the first authority run:

- temporal-indicator gain: `12.31%`, below required 15%;
- backend gain: `0.60%`, below required 3%;
- total q/state trial: about `0.61%` slower;
- max absolute q difference: 0;
- retry/nonlinear path unchanged.

Independent current-head replay `36306634228`:

- temporal-indicator gain: `10.52%`, again below required 15%;
- backend gain: `3.88%`;
- total q/state trial gain: `2.60%`;
- max absolute q difference: 0;
- retry/nonlinear path unchanged.

The composed timing varies, but the selected component itself fails its frozen 15% local gain gate in both independent measurements.

Decision:
`REJECT_NO_COMPOSED_RUNTIME_GAIN`.

## Final interpretation

The remaining current exact q/state cost is distributed.

There is no measured exact-preserving BASE01 candidate that simultaneously:

1. owns a sufficiently large fraction of current live backend runtime; and
2. demonstrates a composed runtime benefit large enough to justify a production change.

The obvious smaller families are either below the preregistered gate or have already been shown historically to have weak composition value.

Therefore BASE01 does not manufacture another optimization by relaxing thresholds or combining unrelated small changes.

## Deferred evidence, not selected successors

- accepted-direction work remains material at about 19% of exact trial cost from LIVE01, but missed its frozen 20% primary gate;
- constitutive work is material but below the BASE01 full-backend gate;
- discarded-trial solve elimination remains useful only for future reuse-rich coupling workloads;
- AHL/direct-retention remains a separate bounded representation line and is not admitted here by inference;
- approximate/practical modes remain separate from this exact-preserving workunit.

## Final decision

`F-PE-BASE01 = CLOSED_NO_EXACT_BASE_SOLVE_TARGET`

No production source change.

No change to c=0.65, temporal floor, BALTOL02, retry scale, Richards equations, nonlinear tolerances, tangent mathematics, MODFLOW equations, mass authority or publication ownership.
