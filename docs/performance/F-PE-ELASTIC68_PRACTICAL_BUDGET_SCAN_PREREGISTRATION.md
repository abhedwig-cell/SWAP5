# F-PE-ELASTIC68 — practical mode-7 application head-budget scan

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Parent:
F-PE-ELASTIC67 bounded physical temporal-budget closure.

Purpose:
stop treating the deliberately strict TEMPORAL04 research bound of 0.01 cm as
an implicit application target and directly screen a small set of explicit
caller-owned mode-7 head budgets for practical accuracy/work trade-off.

This workunit does not reopen the residual Reference-oracle blocker and does
not modify production code, solver tolerances, Richards physics, ELAS
parameters, alpha, C-SAFE semantics or hard mass policy.

## Frozen bank

Reuse the ELASTIC55 four-profile bank, unchanged:

- four selected BOFEK/BRO profiles;
- h0 = -75, -20, +2, +10 cm;
- forcing delta = -0.05, -0.035, +0.035, +0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- frozen dt ladder from 0.015625 down to 0.00006103515625 day;
- swkimpl=0;
- mode 7;
- frozen alpha = 0.17320259355765216.

No new material selection or case fitting.

## Budget arms

Evaluate exactly:

- 0.01 cm;
- 0.02 cm;
- 0.05 cm;
- 0.10 cm;
- 0.20 cm.

For each origin and arm, emulate the admitted forward-only C-SAFE selection:
visit the frozen dt ladder from coarse to fine and accept the first successful
full solve with an available indicator satisfying

alpha * Binf <= head_budget.

Do not assume monotonic Binf contraction.

## Screening metrics

For each arm record:

- number of accepted/exhausted origins;
- mean and maximum rejected coarser levels before acceptance;
- accepted-dt distribution;
- nonlinear-iteration work proxy on accepted full solves;
- availability of a successful full/two-half comparison at the accepted dt;
- accepted-row full-vs-two-half max head discrepancy;
- accepted-row full-vs-two-half max theta discrepancy.

The full/two-half quantities are local temporal sensitivity diagnostics, not a
replacement independent oracle.

## Practical screening envelope

For candidate selection only, freeze:

- full-vs-two-half head discrepancy <= 0.10 cm;
- full-vs-two-half theta discrepancy <= 1e-4;
- no reduction in accepted-origin count relative to the 0.01-cm arm;
- no source or solver-policy change.

These bounds are application-screening criteria, not universal SWAP accuracy
claims.

## Selection rule

An arm is screening-feasible if every accepted origin with an available
full/two-half diagnostic stays inside both practical discrepancy bounds.

Among feasible arms:

1. maximize accepted-origin count;
2. then minimize total rejected coarser levels;
3. if multiple arms are within 5% of the minimum rejection count, select the
   smallest head budget among those arms.

This deliberately avoids selecting a looser budget without a material work
benefit.

A selected arm is only a production-admission candidate. It must still pass a
separate production-shaped validation with the real ELASTIC65 mass-first
transaction path before any application policy is admitted.

## Stop conditions

Close without a candidate if:

- no arm improves practical work/completion over 0.01 cm;
- a candidate arm violates the frozen screening envelope;
- the result depends on one ELAS regime;
- source changes are required to obtain the result.

Do not create ELASTIC69-style oracle work from this scan. Any residual oracle
question remains outside this practical line.
