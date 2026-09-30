# F-PE-PZG23-02 — post-qualification closure

Date: 2026-09-30

Status: CLOSED_ACCEPTED_HISTORY_CAUSE_FALSIFIED

Canonical baseline:
`integration/f-ci-canonical@021abc51216909de90e992ee917838e3725da1ad`

Qualified research authority:
- branch: `research/f-pe-pzg23-02-history-falsification`;
- qualified postimage: `d0d5b15217854c96bb57a586720da725428952d0`;
- result commit: `eb3e1c1894870f79388bb1ffca1e3a60decd2b7d`;
- workflow run: `36761908554`;
- job: `110046331564`;
- conclusion: SUCCESS.

## Closed result

For both localized pZg23 second-interval failures:

- ORIGINAL fails;
- RECON_SAME_HISTORY fails with the same failure class and solver-work signature;
- RECON_ZERO_HISTORY also fails.

Therefore:

`ACCEPTED_TEMPORAL_HISTORY_CAUSE = FALSIFIED`.

The failures are not caused by hidden solver/warm-start state outside the
committed carrier either, because exact same-history reconstruction reproduces
the production failure.

The remaining bounded cause class is:

`ACCEPTED_PHYSICAL_STATE / LOCAL_NONLINEAR_REGIME`.

## Preserved boundaries

No production source changed.

Do not:

- reset history in production;
- remove temporal history from the admitted mode-7 route;
- widen the 0.20 cm budget;
- relax hard mass;
- relax solver/balance tolerances;
- use reconstruction as a production workaround.

## Closure

F-PE-PZG23-02 is closed.

A successor attribution, if pursued, may focus only on solver-local behavior of
the first failing interval-B substep for origins 10 and 11.
