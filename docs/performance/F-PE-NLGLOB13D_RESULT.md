# F-PE-NLGLOB13D result — same-origin h/8 falsification

Date: 2026-09-29

Status:

`NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED`

Canonical base:

`integration/f-ci-canonical@dc12c52ea71e136cd9ea0573980915b8618ca7d6`

Final qualification authority:

- workflow run: `36558791581`;
- job: `109374338130`;
- conclusion: SUCCESS.

Earlier run `36558488567` established the same negative direction, but the final authority is the later protocol-corrected postimage above.

## Frozen question

Does one additional bounded same-origin subdivision level, from a failing h/4 child to h/8, make the five remaining O05/TG near-saturation targets retention-admissible?

No h/16 or recursive subdivision was permitted.

## Coverage

PASS.

All five frozen targets executed without process failure:

- HEAD, dt 0.00025 d;
- HEAD, dt 0.000125 d;
- HEAD, dt 0.0000625 d;
- RUNOFF, dt 0.00025 d;
- RUNOFF, dt 0.000125 d.

Exact rollback/origin identity is inherited from NLGLOB13C1/C2.

Smooth TIMEINT16C authority remains preserved:

- median refined top-head order about `2.04787`;
- median refined top-theta order about `2.04787`;
- smooth qualification gate PASS.

Physical mass remains within unchanged authority:

- max accepted-interval ledger about `2.24e-14 cm`;
- max cumulative ledger about `1.25e-14 cm`.

## Result

The first same-origin h/8 child is retention-admissible in:

`1 / 5`

targets.

It remains inadmissible in:

`4 / 5`

targets.

No target completes the full horizon under the bounded candidate:

`0 / 5`.

No process failure, nonfinite-state failure or physical-mass failure is observed.

## Frozen classification

`NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED`.

The preregistered negative gate applies because at least 3/5 first h/8 children remain inadmissible. The observed count is 4/5.

## Interpretation

The near-saturation TG accepted-state defect contracts under temporal refinement, as established by NLGLOB13C2, and one of the five remaining targets crosses into admissibility at h/8.

However, four of five same-origin targets remain inadmissible.

Therefore simple subdivision depth through a bounded h/8 level is not a general repair for this line.

The failure is not caused by:

- endpoint nonconvergence;
- mass imbalance;
- route mismatch;
- nonfinite state;
- loss of smooth second-order behavior.

The remaining issue is the accepted TG temporal construction at the saturation boundary.

## Consequence

Do not open h/16 or adaptive recursive subdivision as a continuation of this workunit.

A successor must use a different temporal construction tied explicitly to the saturation boundary, while preserving:

- provider-consistent endpoint coefficient staging;
- unchanged accepted-state mass accounting;
- no accepted-theta clipping;
- smooth second-order authority away from the event;
- explicit route/event semantics.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
