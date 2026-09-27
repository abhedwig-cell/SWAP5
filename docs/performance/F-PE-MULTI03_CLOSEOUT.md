# F-PE-MULTI03 closeout — deterministic load-balanced worker-local groundwater scheduling

Date: 2026-09-27

Status: `CLOSED_SCHEDULING_CANDIDATE_QUALIFIED`

PR:
`#664 — F-PE-MULTI03: deterministic load-balanced worker-local groundwater scheduling`

Parent authority:
`F-PE-MULTI02 / PR #662`

Canonical base:
`integration/f-ci-canonical@3a6ecd223b7187d5a6913f9ca47f8596c6de2bf3`

Qualification authority:
- exercised head: `869bdba0d48953f8b11ead632fa8f5fa16ba0ca5`;
- workflow run: `36311612572`;
- strict hybrid job: `p1-hybrid-scheduling`.

## Question

Can deterministic scheduling remove the heterogeneous-ordering performance miss from MULTI02 without changing numerical semantics, worker-local ownership or canonical result order?

Answer:

Yes, using a bounded hybrid scheduler that retains ordinary static assignment when predicted pre-trial load is already balanced and switches to deterministic cost-aware assignment only when the predicted static load ratio exceeds the preregistered threshold.

## P0 — always-on cost-aware scheduling

Rejected as the final candidate.

It removed the adverse-ordering imbalance but exceeded the frozen 2% no-regression allowance on an already balanced ordering.

This negative result is retained and not relaxed after observation.

## P1 — bounded hybrid scheduling

Qualified.

Frozen deterministic rule:

- calculate static worker assignment using only immutable pre-trial predecessor-history cost information;
- calculate predicted max/mean worker load;
- if ratio <=1.20, retain static assignment;
- if ratio >1.20, use deterministic descending-cost least-loaded-bin assignment;
- preserve worker-local mutable backend ownership;
- preserve per-tile result slots and canonical aggregation/publication order.

The threshold 1.20 was frozen before P1 execution and inherited from the earlier load-balance gate.

## Frozen performance gates

N=1,000, both retained history-cost orderings.

Ordering 0, naturally balanced:
- selected scheduler: STATIC;
- predicted 4-worker load ratio: `1.004800`;
- 2-worker speedup: `1.854475x`;
- 4-worker speedup: `2.388483x`;
- selected/static 4-worker speed ratio: `1.002601x`.

Ordering 1, adverse for static assignment:
- selected scheduler: COST_AWARE;
- static predicted 4-worker load ratio: `3.011765`;
- selected predicted 4-worker load ratio: `1.000094`;
- 2-worker speedup: `1.873259x`;
- 4-worker speedup: `2.317263x`;
- selected/static 4-worker speed ratio: `1.078296x`.

Frozen gates:
- 2-worker speedup >=1.5x: PASS for both orderings;
- 4-worker speedup >=2.2x: PASS for both orderings;
- selected scheduler runtime <=1.02 * static runtime: PASS;
- selected predicted max/mean load <=1.20: PASS;
- required scheduler selection by ordering: PASS.

## Numerical and transaction semantics

PASS.

The strict P1 authority compares per-tile serial and selected-scheduler diagnostics and requires exact agreement in:

- q;
- tangent;
- transaction calls;
- accepted substeps;
- attempts;
- retries;
- solver rejections;
- temporal rejections;
- temporal acceptance source;
- internal retries;
- nonlinear iterations;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts.

After discard it also requires:

- accepted origin remains present;
- no candidate remains live;
- committed revision remains unchanged before commit.

No semantic drift was observed.

## Main finding

Worker-local groundwater parallelism is no longer blocked by heterogeneous static work placement.

A deterministic pre-trial scheduler can preserve the already-qualified static path when it is adequate and invoke deterministic cost-aware placement only when a frozen pre-trial imbalance discriminator requires it.

The remaining work is no longer research scheduling qualification.

It is production application-context admission and live coupling integration.

## Decision

`F-PE-MULTI03 = CLOSED_SCHEDULING_CANDIDATE_QUALIFIED`

No production `src/**` change is admitted by MULTI03 itself.

Immediate successor:

`F-PE-MULTI04 — production application-context worker-local groundwater parallel admission`

MULTI04 should production-admit the qualified worker-local ownership plus bounded hybrid deterministic scheduling while preserving the serial/default path until admission closes.

Minimum production qualification:

- application-context integration;
- worker-local mutable backend/workspace lifetime and thread safety;
- participant accepted-origin/candidate isolation;
- deterministic canonical aggregation/publication order;
- exactly-once commit/ledger semantics;
- abort/discard path;
- exact c=0.65 temporal semantics;
- temporal floor = 1e-5 cm;
- BALTOL02;
- retry scale and nonlinear tolerances;
- tangent mathematics;
- live MODFLOW6 coupling;
- PPA-WU01 preservation;
- relevant canonical CI.

Production admission must not infer safety from research scheduling alone.
