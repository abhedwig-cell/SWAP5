# PPA-WU05-A8 result — production macropore hydraulic views / FMR integration

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_FMR_SINGLE_COLUMN_ADMISSION_CANDIDATE

Canonical reconciliation base: `integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

Selective qualification postimage: `e364f03cd247ade34a58074da37cd0dd147c31ac`

Qualification workflow: `.github/workflows/ppa-wu05a8-selective-admission.yml`

Qualification run: `36821243957` — SUCCESS

## Qualified scope

- standard `swmbf=1` macropore route;
- serialized single-column FMR;
- Reference Richards only;
- immutable FMR macropore physical configuration;
- dynamic hydraulic views derived from accepted matrix/macropore state;
- outer macropore/Richards coupling through source/sink overlay;
- inner Richards request keeps `macropore_active=.false.`;
- candidate macropore state remains tentative until kernel commit;
- rejected/discarded candidate does not mutate committed state;
- committed persistence/restart deep-copies the seven continuation fields;
- restart next-candidate replay is identical within the qualified fixture;
- external full/half temporal acceptance uses the bounded physical temporal-error route; discrete `ICpBtDm` topology mismatch fails closed.

## Preservation / receipts

The selective exact-postimage gate compiles and runs O0 and O2 and covers:

- inactive Reference-Richards preservation;
- active real-Richards macropore coupling;
- FMR admission and execution;
- mass-accounting completion;
- candidate-only publication;
- discard + checkpoint replay;
- commit;
- persistence export/restore;
- restart continuation replay.

## Deliberate non-admitted scope

- perched saturated-zone macropore physics;
- surface-connected macropore top input when separate rain/irrigation/melt/ponding/runon forcing is unavailable;
- rapid drainage in the first FMR admission slice;
- dynamic crack-geometry displacement feedback within one corrector;
- RossFast macropore route;
- parallel/concurrent MultiSWAP macropore execution.

These routes remain fail-closed or outside this admission claim.

## Lifecycle

implemented -> persisted -> tested -> qualified

Canonical admission is not claimed by this record.
