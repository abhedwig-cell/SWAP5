# F-PE-LIVE01 P2 result — temporal-retry cost bound

Date: 2026-09-27

Status: `PASS_NO_TEMPORAL_RETRY_SUCCESSOR`

PR:
`#656 — F-PE-LIVE01: required live-trial cost rebaseline`

Current-head authority:
- head: `5a1945d2c374206527ea1a0c9186c2a348f444ad`;
- workflow run: `36303861366`;
- job: `p2-temporal-retry-cost`;
- conclusion: PASS.

## Harness correction

The first P2 attempt failed before measurement because the research fixture called
`fgc44_live01_policy_floor_c` after participant initialization.

The bridge intentionally freezes this research-only configuration before initialization,
matching the production bootstrap/configuration ownership boundary.

The fixture was corrected by moving only that setter call before
`initialize_configured()`.

No production source, production policy, coefficient, acceptance gate or physical
semantics changed.

## Frozen comparison

Both arms replay exactly the same live prescribed-head population with
accepted-direction production disabled.

PROD:
`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

WIDE:
- same coefficient `0.65`;
- research-only floor `0.02 cm`.

WIDE is not a production candidate.

## Result

Aggregate over the 12 difficult live groups:

- PROD trial time: `893686 ns`;
- WIDE trial time: `897793 ns`;
- `R_retry = T_PROD / T_WIDE = 0.995425449`;
- bounded retry fraction:
  `-0.004595574` (about -0.46%);
- max relative q difference: `0`;
- PROD retries: `20`;
- WIDE retries: `20`;
- PROD attempts: `72`;
- WIDE attempts: `72`.

Thus the wider floor does not remove a single temporal retry in this frozen live matrix.

The reason is that the history-dependent term, not the `1e-5 cm` floor, controls
the effective budget in the retrying cases.

The measured runtime difference is noise-scale and slightly negative.

## Gate

Preregistered advancement required:

1. aggregate retry-bound fraction >= 20%;
2. max relative q difference <= 0.1%.

Observed:

- runtime gate: FAIL;
- q gate: PASS.

Decision:

`DO_NOT_ADVANCE_TEMPORAL_RETRY_AS_PRIMARY_SUCCESSOR`

## Interpretation

Temporal rejections remain present in the live matrix, but changing the floor is not
a useful performance lever for them.

P2 does not justify:
- changing c=0.65;
- changing the 1e-5 cm production floor;
- relaxing the temporal acceptance envelope;
- opening a separate floor-tuning workunit.

The remaining performance target is the base q/state Richards solve itself.

