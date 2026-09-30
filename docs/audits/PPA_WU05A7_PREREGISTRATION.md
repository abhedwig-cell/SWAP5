# PPA-WU05-A7 preregistration — production shaping and admission-candidate qualification

Date: 2026-09-30

Status: PREREGISTERED / PRODUCTION-SHAPED / NOT_ADMITTED

Baseline: PPA-WU05-A6@6e9346af856f48b2f771280a687d600b602bc4ef

Canonical authority: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b.

## Purpose

Move the qualified A1-A6 macropore research components behind a production-shaped SWAP5 interface without changing the current production reference path unless the option is explicitly enabled.

## Hard invariants

- Full Richards remains available and unchanged as production reference.
- Macropore disabled must preserve current production results bit-for-bit within the qualified test scope.
- No hidden committed state.
- Rejected trials cannot publish macropore state or flux receipts.
- Restart persists only qualified continuation state.
- Numerical coupling policy remains separate from physical process configuration.
- Production admission requires exact postimage qualification; research evidence alone is insufficient.

## Phases

1. locate and freeze existing production seam;
2. add production-shaped macropore option/interface with default disabled;
3. connect typed continuation/restart ownership;
4. connect source-rate bundle through existing source/sink solver seam;
5. add inactive-preservation, accept/reject/retry and restart tests;
6. qualify bounded active single-column cases against A6 research oracle;
7. only then declare production-admission candidate.

## Non-goals

- no MultiSWAP parallel macropore claim;
- no canonical admission in this phase unless all admission gates are green;
- no change to unrelated groundwater/surface/ET capabilities.