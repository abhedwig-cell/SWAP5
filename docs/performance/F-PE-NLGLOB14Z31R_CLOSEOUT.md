# F-PE-NLGLOB14Z31R closeout — protocol-correct cumulative-drift attribution re-execution

Date: 2026-09-30

Final status:

`QUALIFIED_Z31R_REGIME_LOCALIZED_BIAS`

Qualification authority:

- workflow run `36757619753`;
- HEAD segment-B job `110037948169`;
- RUNOFF segment-B job `110037948275`;
- both jobs SUCCESS;
- both independent trajectories reach 540 d.

Canonical authority:

`integration/f-ci-canonical@c400b02d9956f35c9c20fac09f94b34d5e2ee09f`

## Closure

Z31R closes positively as a protocol-correct attribution result.

Both fixtures independently satisfy the frozen regime-localized-bias classification.

The central mechanistic finding is now narrow:

- tail `12:16` / n=12 is effectively machine-precision neutral;
- the first chatter family is mass-neutral at practical precision;
- measurable long-horizon drift starts in the stable `13:16` / n=13 regime;
- HEAD remains dominated by that n=13 contribution through 540 d;
- RUNOFF subsequently receives a compensating contribution in `14:16` / n=14;
- event timing can shift by a few fine intervals without invalidating one-face ownership geometry or the final ownership regime.

## Architectural conclusion

The adaptive moving-interface manager is not falsified.

Across both protocol-correct 140–540 d trajectories:

- no reconstruction failure occurs;
- no nonlinear solve failure occurs;
- no physical hard gate is violated;
- both routes end at tail `14:16`;
- ordered event directions agree;
- adaptive per-interval mass ledgers remain around 1e-9 cm;
- deterministic solver work is reduced by about 20%.

The remaining issue is therefore a localized stable-regime representation discrepancy, not generic timestep instability, chatter, or transaction failure.

## Direct successor

Open:

`F-PE-NLGLOB14Z32 — stable n=13 interface-equation attribution`.

The successor should freeze the stable `13:16` / n=13 regime and compare full versus reduced candidates from identical accepted origins.

Required decomposition:

1. interface-face flux;
2. guard-node storage increment;
3. guard residual;
4. reconstructed saturated-tail head increments;
5. reconstructed-tail storage contribution;
6. complete nominal interval ledger;
7. full-minus-reduced residual-equation difference.

The target is attribution, not correction.

Do not introduce:

- correction coefficients;
- empirical thresholds;
- mass redistribution;
- anti-chatter logic;
- tolerance widening.

Only after the exact n=13 discrepancy is identified should a separately preregistered correction candidate be considered.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z31R

BRANCH: `research/f-pe-nlglob14z31r-drift-attribution-reexec`

RESULT POSTIMAGE BEFORE CLOSEOUT: `40829817ca9e1fb311fc84434da5fed4639f5ee1`

QUALIFICATION STATUS: `QUALIFIED_Z31R_REGIME_LOCALIZED_BIAS`

NEXT SAFE STEP: Z32 stable n=13 interface-equation attribution.

## Production boundary

No production source/default change.

`LEGACY_NUMERICS` remains production default.
