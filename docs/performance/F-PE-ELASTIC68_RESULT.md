# F-PE-ELASTIC68 — practical mode-7 application head-budget scan result

Date: 2026-09-30

Status: QUALIFIED_BOUNDED_APPLICATION_POLICY_CANDIDATE

Branch:
`research/f-pe-elastic68-practical-budget-scan`

Qualified postimage:
`80c2f895451a85a8cd63360feddd9434659b8a0d`

Canonical authority:
`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Workflow run:
`36728946761`

Job:
`109933079466`

Conclusion:
SUCCESS.

## Purpose

Replace the deliberately strict TEMPORAL04 research benchmark of 0.01 cm with a
small practical screen of explicit caller-owned mode-7 head budgets.

No production code, solver tolerance, Richards physics, ELAS parameterization,
alpha, hard mass policy or C-SAFE semantics changed.

## Frozen bank

Unchanged ELASTIC55 four-profile bank:

- profiles 11060, 10260, 8016, 3030;
- h0 = -75, -20, +2, +10 cm;
- forcing delta = -0.05, -0.035, +0.035, +0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- mode 7, swkimpl=0;
- frozen forward-only dt ladder;
- alpha = 0.17320259355765216.

O0/O2 identity passed.

## Global five-arm scan

| head budget | accepted | exhausted | rejected coarser levels | paired diagnostics | max local dh | max local dtheta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.01 cm | 96 | 96 | 1002 | 90 | 5.78e-4 cm | 1.12e-6 |
| 0.02 cm | 115 | 77 | 890 | 98 | 9.13e-3 cm | 3.71e-6 |
| 0.05 cm | 148 | 44 | 682 | 111 | 2.11e-2 cm | 4.04e-5 |
| 0.10 cm | 158 | 34 | 578 | 131 | 3.84e-2 cm | 6.14e-5 |
| 0.20 cm | 160 | 32 | 499 | 138 | 3.84e-2 cm | 6.14e-5 |

All paired diagnostics at every arm remain inside the preregistered practical
screen:

- local full-vs-two-half head discrepancy <= 0.10 cm;
- local full-vs-two-half theta discrepancy <= 1e-4.

## Universal-policy result

The preregistered universal selection gate also required regime-independent
acceptance behavior.

That gate fails for every arm above 0.01 cm.

The reason is structurally informative rather than a physical-budget failure:

- OFF remains at 8 accepted origins per profile;
- FIXED_1E6 and especially GENERATED gain completion as the head budget is
  relaxed.

Therefore one universal mode-7 head budget is not the correct application
abstraction for this bank.

The preregistered universal-policy result is negative.

## GENERATED route

The GENERATED route is separately relevant because the generated ELAS
application chain is already canonically admitted through ELASTIC44/45 and is
the intended soil-parameter-driven elastic-storage route.

Across 64 GENERATED origins:

| head budget | accepted | exhausted | rejected coarser levels | mean rejected levels | max local dh | max local dtheta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.01 cm | 32 | 32 | 334 | 5.219 | 5.78e-4 cm | 1.12e-6 |
| 0.02 cm | 50 | 14 | 260 | 4.063 | 9.13e-3 cm | 3.71e-6 |
| 0.05 cm | 64 | 0 | 150 | 2.344 | 2.11e-2 cm | 4.04e-5 |
| 0.10 cm | 64 | 0 | 110 | 1.719 | 3.84e-2 cm | 6.14e-5 |
| 0.20 cm | 64 | 0 | 69 | 1.078 | 3.84e-2 cm | 6.14e-5 |

Relative to 0.01 cm, the 0.20-cm arm:

- increases completion from 32/64 to 64/64;
- reduces rejected coarser levels from 334 to 69;
- reduces that retry/refinement proxy by about 79%;
- keeps the observed maximum local head discrepancy below 0.04 cm;
- keeps the observed maximum local theta discrepancy below 6.2e-5.

0.20 cm also reduces rejected levels materially relative to 0.10 cm while not
increasing the observed maximum local head or theta discrepancy in this bank.

## Decision

Classification:

`QUALIFIED_GENERATED_ELAS_MODE7_APPLICATION_HEAD_BUDGET_0P20_CANDIDATE`.

The bounded candidate is:

`GENERATED ELAS + mode7 + swkimpl=0 + admitted temporal history + explicit caller-owned head budget = 0.20 cm`.

This is an application-policy candidate, not a universal SWAP default.

It is not a claim that 0.20 cm is physically optimal or that larger values
would fail. The scan deliberately stops at the preregistered upper arm because
the practical objective was to identify a useful bounded operating point, not
to maximize allowable error.

## Production relation

No new production mechanism is required.

Canonical ELASTIC65 already admits:

explicit positive caller-owned head budget
-> frozen alpha normalization
-> existing mass-first refine/recheck transaction path.

Canonical ELASTIC44/45 already admit the generated soil-parameter-driven ELAS
application chain.

Therefore 0.20 cm can be supplied through already admitted mechanisms without
changing solver or physics code.

A future canonical application-profile record may name 0.20 cm as the bounded
GENERATED/MultiSWAP-MODFLOW policy value. That record must keep:

- hard mass unchanged;
- alpha unchanged;
- C-SAFE unchanged;
- swkimpl=0;
- GENERATED ELAS scope explicit;
- no extrapolation to OFF, FIXED_1E6 or arbitrary optional-process
  combinations.

## Closure

The practical budget-calibration question is closed for this research line.

Do not continue with broader oracle completion or additional budget arms merely
to seek a more permissive value.

The useful production-facing result is the bounded 0.20-cm GENERATED
application-policy candidate.
