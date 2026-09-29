# F-PE-NLGLOB14Q closeout — first-retreat transactional shadow TG solve

Date: 2026-09-29

Final status:

`NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`

Qualification authority:

- run `36588192089`;
- job `109474317758`;
- conclusion: SUCCESS.

## Closure

NLGLOB14Q closes positively.

At every one of the 12 qualified first-retreat origins, exactly one full-column provider-consistent TG interval can be evaluated under the actual dry surface-flux forcing.

All shadow trials:

- converge without solver retry;
- remain finite;
- preserve FLUX route consistency from origin through accepted candidate;
- have independent dry-phase mass ledgers at roundoff scale;
- are fully rolled back;
- leave the persistent saturated-KLAG control trajectory unchanged and mass-clean.

## Saturation after the shadow interval

All 12 successful TG shadow candidates still contain 13 saturated nodes.

Therefore one ordinary TG interval is numerically admissible while the lower saturated block remains.

NLGLOB14Q does not establish that continued TG ownership is stable.

## Scientific conclusion

The first-retreat event has now passed three increasingly strong tests:

1. full-column provider-origin admissibility;
2. full-column TG predictor admissibility;
3. one-interval transactional TG solve admissibility.

The unresolved question is persistence of TG ownership after that handoff.

A release policy must still demonstrate that committing the handoff does not produce immediate saturation-event re-entry or repeated TG/KLAG chatter.

## Direct successor

Open:

`F-PE-NLGLOB14R — accepted first-retreat handoff and re-entry falsification`.

The successor must remain research/test-only.

It should:

1. commit exactly one TG interval at the qualified first-retreat handoff;
2. thereafter allow the existing event-aware TG policy to operate normally;
3. preserve the NLGLOB14N3 retry-as-bracket rule;
4. record mode transitions and saturation-event root attempts;
5. fail closed on repeated immediate TG <-> saturated-mode chatter;
6. compare mass and final accepted trajectory against the persistent-KLAG control;
7. leave production defaults unchanged.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Q

BRANCH: `research/f-pe-nlglob14q-retreat-shadow-tg-solve`

STATUS: closed positive transactional shadow qualification

TEST STATUS: 12-case shadow TG bank PASS

QUALIFICATION STATUS: `NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`

NEXT SAFE STEP: preregister accepted first-retreat handoff/re-entry falsification.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
