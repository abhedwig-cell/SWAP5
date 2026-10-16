# F-PE-PROFILE06 closeout — difficult Richards practical stack

Date: 2026-09-26

Status: `CLOSED_MEASURED_DIFFICULT_STACK_COMPLEMENTARY`

PR:
`#640 — F-PE-PROFILE06: difficult Richards practical-stack characterization`

Branch:
`work/f-pe-profile06-difficult-richards`

Parent:
`F-PE-PROFILE05R2`

## Closure

PROFILE06 establishes where the retained practical modes matter.

On difficult 20-step Richards transients, A2C reduces nonlinear/backtracking work by roughly 28-34% and delivers material direct-solve runtime gains.

On the real accepted-direction participant route, A1 + A2C is complementary in 5/6 frozen difficult cases.

Aggregate P2 observations:

- median stack speedup versus exact: about 26.74%;
- median A1 speedup: about 21.23%;
- median A2C speedup: about 5.02%;
- median stack incremental speedup versus A1: about 6.89%;
- median stack incremental speedup versus A2C: about 22.53%.

The easy short FGC44 loop from PROFILE05R2 remains a different regime where A2C adds no resolved incremental benefit.

## Remaining measured target

The dominant remaining work on difficult same-origin correctors is the physical Reference Richards solve itself.

A1 reuses most tangent evaluations:

- about 3555 reuse events per 4000 trials;
- about 445 fresh tangent evaluations.

But every trial still executes a physical solve to obtain the response/candidate state.

A2C makes that solve cheaper where the nonlinear trajectory is difficult, but does not eliminate repeated solves.

## Decision

Do not spend another workunit reducing tangent arithmetic.

The next line should test whether intermediate same-origin corrector responses can be served from a bounded response representation while preserving an exact final solve before commit.

That is an approximation/coupling-policy question, not an exact solver optimization.

It requires a separate preregistered workunit with:

- response-only semantics distinct from candidate-state ownership;
- bounded head-displacement/age validity;
- exact fallback;
- exact final validation solve before commit;
- exchange/tangent error characterization;
- coupled iteration robustness;
- mass/ledger preservation at commit.

No such implementation is admitted by PROFILE06.
