# F-PE-NLGLOB14Z34 closeout — production-shaped moving-interface manager prototype seam

Date: 2026-09-30

Final status:

`QUALIFIED_Z34_MANAGER_SEAM_READY`

Qualification authority:

- workflow run `36768767332`;
- seam-smoke job `110069502514`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z34 closes positively.

The production/runtime architecture already has the required substrate for a non-default adaptive moving-interface manager:

- full accepted state remains sole physical authority;
- reduced request/state is derived scratch;
- production reference workspace supports reduced active dimension;
- reduced candidates can be rematerialized to full shape;
- exact full fallback is explicit;
- fallback reason and active dimension are typed diagnostics;
- failed reduced trials do not leak into accepted state.

No new transaction architecture or parallel solver stack is required.

## Implemented seam

New research prototype source:

`src/runtime/mod_moving_interface_manager.f90`.

It provides:

- active-view derivation;
- reduced-request construction;
- full-candidate materialization;
- explicit reduced/full-fallback/bypass result selection;
- typed manager diagnostics.

The module does not commit physical state.

Commit authority remains outside the manager under the existing transaction layer.

## Smoke authority

The focused smoke validates:

- 16-node full accepted state;
- 13-node reduced request/workspace;
- full-shaped reduced candidate publication;
- reduced route selection;
- forced exact full fallback;
- explicit fallback reason;
- no accepted-state mutation on failed reduced path;
- explicit full-dimension bypass.

## Strategic consequence

The remaining work is no longer architectural.

The next workunit should bind the already-qualified reduced moving-interface physics behind this seam on a small production-shaped executable fixture.

Do not broaden immediately to BOFEK-wide or application-scale holdouts.

First prove the real manager route with:

1. eligible reduced solve;
2. full candidate materialization;
3. transaction-safe acceptance;
4. forced fallback;
5. ineligible bypass;
6. typed active-dimension/fallback diagnostics;
7. physical comparison to full reference;
8. focused work/timing diagnostics.

## Direct successor

Open:

`F-PE-NLGLOB14Z35 — production-shaped manager physical binding smoke`.

Z35 should be a focused executable integration workunit.

It should reuse the Z29/Z31R reduced physics and the Z34 manager seam, not redesign either.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z34

BRANCH: `research/f-pe-nlglob14z34-manager-prototype-seam`

RESULT POSTIMAGE BEFORE CLOSEOUT: `aed8f7f697695dd0ae6939ecb05f675626087e27`

QUALIFICATION STATUS: `QUALIFIED_Z34_MANAGER_SEAM_READY`

NEXT SAFE STEP: Z35 production-shaped manager physical binding smoke.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
