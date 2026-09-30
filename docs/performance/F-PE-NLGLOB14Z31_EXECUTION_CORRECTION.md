# F-PE-NLGLOB14Z31 execution correction — run 36751697504

Date: 2026-09-30

Status: `EXECUTION_INVALID_FOR_FINAL_Z31_CLASSIFICATION`

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@a9bf62afd08b30087c3385709f94e4143d9de006`

Research postimage before persistence:

`research/f-pe-nlglob14z31-drift-attribution@1871af9ac6c562e82c6cba8c16b3152f09040412`

## Reason

The first Z31 execution, workflow run `36751697504`, exposed useful diagnostics but did not execute the frozen preregistration completely.

The runner inherited Z30 stop logic for:

- h/theta/top-flux A/B divergence;
- same-nominal-step ownership-event divergence;
- final-tail mismatch.

Those are diagnostic quantities in Z31, not frozen Z31 hard stop conditions.

The Z31 preregistration explicitly allows continuation to 540 d unless a true physical blocker occurs:

- non-finite state;
- reduced reconstruction failure;
- nonlinear solve failure;
- noncontiguous saturated tail;
- ownership jump greater than one face;
- per-interval physical ledger greater than `5e-8 cm`.

Therefore run `36751697504` must not be used for final Z31 classification.

## Preserved evidence

Observed diagnostics from run `36751697504` remain useful evidence, including the strong localization of signed drift to the `13:16` / n=13 regime, but they are not qualification authority.

## Correction boundary

The corrected runner removes only the inherited Z30 diagnostic stop conditions.

No change is made to:

- physical equations;
- constitutive providers;
- moving-interface semantics;
- reconstruction rule;
- dt;
- forcing;
- ledger hard gate;
- attribution bins;
- frozen classification rules.

The corrected rerun is the only candidate final Z31 qualification authority.
