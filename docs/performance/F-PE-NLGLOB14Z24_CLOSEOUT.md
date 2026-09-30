# F-PE-NLGLOB14Z24 closeout — moving-interface chatter is internal to SWAP

Date: 2026-09-30

Final status:

`QUALIFIED_Z24_CHATTER_INTERNAL_TO_SWAP_COUPLING_RELEVANCE_NOT_ESTABLISHED`

Qualification authority:

- workflow run `36722000431`;
- contract-audit job `109909196397`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

## Closure

Z24 closes positively as a contract-boundary result.

The current admitted groundwater-coupling surface exchanges:

- hydraulic head;
- coupling-window identity;
- whole-window water exchange / paired interface flux;
- candidate/prepared publication state.

It does not expose moving-interface ownership, saturated-tail identity, interface-face index or ownership-change events.

No current authority maps one fine TIMEINT17/NLGLOB interval one-to-one onto one groundwater coupling window.

Therefore the repeated internal chatter established by Z20-Z22 is not, under the current coupling contract, itself an external groundwater publication event stream.

## Consequence

Do not modify the groundwater coupling API to solve this issue.

The unresolved question is internal:

- does repeated ownership chatter materially cost runtime;
- does it alter any accepted physical result beyond event bookkeeping;
- does it pollute internal diagnostics enough to justify an implementation response.

Only if one of those is demonstrated should an internal anti-chatter implementation be considered.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z24

BRANCH: `research/f-pe-nlglob14z24-coupling-surface-relevance`

RESEARCH POSTIMAGE BEFORE CLOSEOUT: `f978626be3c300aae582dd79bd913d06c8a8bfe1`

QUALIFICATION RUN: `36722000431`

QUALIFICATION STATUS: `QUALIFIED_Z24_CHATTER_INTERNAL_TO_SWAP_COUPLING_RELEVANCE_NOT_ESTABLISHED`

NEXT SAFE STEP: preregister an internal chatter-cost/effect attribution workunit using the qualified Z22 event sequences and unchanged accepted physical trajectory.

## Production boundary

No production source/default change.

`LEGACY_NUMERICS` remains production default.
