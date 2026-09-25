# F-PE-NEWTON-CANDIDATE01 — exact Reference candidate/backtracking decomposition closeout

Date: 2026-09-25

Status: `CLOSED_NO_PRODUCTION_PATCH_HANDOFF_F_AHL`

Production parent: admitted F-PE-PLANVALID01 postimage `df664f56cf09ee8479701f15fe10ee02d31a9536`.

PR: #611.

No production source was modified by this workunit.

## Question

Which exact subcomponents of one Reference backtracking candidate dominate runtime, and is there a bounded exact non-representation repair worth admitting without changing Newton mathematics, candidate sequence, tolerances, failure timing, mass or transaction semantics?

## Frozen cases

The workunit uses repository-backed PUB-P2E04 Reference cases with B01 material and Se=0.65.

Easy case:

- dt = 0.0016 day;
- nominal forcing;
- converged;
- 3 nonlinear iterations;
- 3 Jacobian builds;
- 3 linear solves;
- 3 backtracking attempts;
- 4 constitutive evaluations;
- 3 candidate-demand evaluations.

Hard case:

- dt = 0.0001 day;
- drying forcing;
- retry advised;
- 16 nonlinear iterations;
- 16 Jacobian builds;
- 16 linear solves;
- 114 backtracking attempts;
- 115 constitutive evaluations;
- 114 candidate-demand evaluations.

No production tolerance or solver policy was changed.

## O2 gprof result

Qualified profile run lineage includes workflow `36149557319` = PASS.

Easy:

- HeadCalc self: about 41% of sampled total;
- tridiagonal solve: about 24%;
- candidate hydraulic demand: about 6% self, about 14% inclusive in the HeadCalc call graph.

Hard:

- HeadCalc self: about 29% of sampled total;
- candidate hydraulic demand: about 8% self, about 41% inclusive in the HeadCalc call graph;
- tridiagonal solve: about 8%.

The hard case changes the cost structure fundamentally: candidate hydraulic demand grows from 3 to 114 calls, while linear solves grow only from 3 to 16.

## No-inline attribution

Workflow `36149557407` = PASS.

The no-inline build was used only as attribution evidence, not as a production timing authority.

Easy:

- candidate hydraulic demand about 9.5% inclusive;
- tridiagonal solve about 20% inclusive.

Hard:

- candidate hydraulic demand about 20.4% inclusive;
- tridiagonal solve approximately negligible in sampled self time;
- the largest remaining cost stays inside HeadCalc candidate/residual/control work.

The two profiles agree on the structural conclusion:

> high-backtracking runtime is not linear-solver dominated; hydraulic candidate demand becomes a major named child cost, while the remaining cost is distributed inside the candidate update/residual/control path.

Exact percentages are not portable claims because gprof is sampling-based and compiler/inlining choices affect attribution.

## Residual reduction candidate

A separate microbenchmark measured the current three residual reductions:

`dot_product(residual,residual) + sum(residual) + maxval(abs(residual))`

against one combined scalar scan.

Results:

| nodes | three intrinsics | one loop | isolated reduction |
| ---: | ---: | ---: | ---: |
| 4 | 4.81 ns | 2.79 ns | ~42% |
| 60 | 72.10 ns | 47.55 ns | ~34% |
| 200 | 351.78 ns | 200.65 ns | ~43% |

The one-loop checksum matched in this benchmark.

This candidate is **not admitted**.

Reasons:

1. on the actual 4-node hard profiling fixture the absolute saving is only about 2 ns per candidate;
2. even 114 candidates therefore buy only a few tenths of a microsecond;
3. a production rewrite could change floating reduction ordering and therefore convergence/failure timing near strict thresholds;
4. the expected benefit is too small to justify that semantic qualification surface.

Classification: `MEASURABLE_BUT_NOT_WORTH_PRODUCTION_RISK`.

## Source reconciliation

The current explicit-conductivity candidate loop performs:

1. candidate head update;
2. candidate hydraulic demand, usually theta-only on the measured route;
3. candidate theta assignment;
4. head-gradient update;
5. residual recomputation through `vector_F(2)`;
6. three residual reductions;
7. progress test and possible factor reduction.

Jacobian construction and the tridiagonal solve happen once per outer Newton iteration, not once per rejected candidate.

This explains the PROFILE02 finding that backtracking count predicts runtime more strongly than Newton iteration count.

## Decision

No bounded non-representation exact production repair is justified from this workunit.

The strongest scalable named candidate cost is hydraulic candidate demand.

Reducing that cost by changing hydraulic representation belongs to F-AHL by governance.

The remaining HeadCalc candidate/residual/control work is numerically necessary on the current algorithm, while the obvious exact micro-optimization in residual reductions is too small and too close to convergence semantics to justify a production patch.

## Handoff to F-AHL

NEWTON-CANDIDATE01 narrows the F-AHL performance target.

F-AHL should report candidate-path performance separately for:

- theta-only candidate demand;
- accepted-candidate capacity/derivative demand;
- initial/full hydraulic tuple;
- terminal evaluation.

The performance value must be evaluated under both:

- easy trajectories with only a few candidate calls;
- high-backtracking trajectories with O(100) candidate calls.

A representation that saves modest time per theta(h) evaluation can have large total value specifically in high-backtracking regimes.

Derivative consistency remains required wherever C=dtheta/dh enters Newton/Jacobian work.

## RossFast relation

RossFast is not reopened here.

The result does clarify the comparison question: any RossFast advantage on difficult cases should be interpreted partly as avoiding or restructuring the Reference candidate/backtracking explosion, not merely as a cheaper tridiagonal solve.

## Practical-mode relation

No approximation was implemented.

For a later practical mode, the largest performance leverage remains reducing the number/cost of difficult candidate trajectories rather than relaxing already-small residual reduction or application overhead.

## Closeout verdict

`F-PE-NEWTON-CANDIDATE01 = CLOSED_NO_EXACT_NONREPRESENTATION_PATCH`

`PRIMARY_HANDOFF = F-AHL candidate theta-demand performance under high backtracking`

No further production work is authorized in NEWTON-CANDIDATE01 without new evidence of a material exact non-representation hotspot.
