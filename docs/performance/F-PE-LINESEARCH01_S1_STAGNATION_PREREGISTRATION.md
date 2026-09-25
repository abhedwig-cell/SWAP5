# F-PE-LINESEARCH01-S1 — bitwise stagnation early-exit screen

Date: 2026-09-25

Parent observation head: `f1fafd3efe309e75106874464ab500f8a337538c`.

Status: `PREREGISTERED_TEST_ONLY`

## Observed trigger

In the frozen hard B01 case:

- Newton iterations 1 and 2 accept factor 1;
- iterations 3 through 16 reject factor 1;
- already at factor 1/3, the candidate pressure-head vector is bitwise identical to the iteration start:
  - `DHMAX = 0`;
  - `NCHANGED = 0`;
- all smaller factors through 1/2187 are therefore also no-ops;
- the same exhausted pattern repeats for 14 outer Newton iterations.

## Candidate rule

Test only, no production patch yet.

After forming a backtracking candidate and recomputing its residual, declare numerical stagnation only when all conditions hold:

1. no pressure-head element changed bitwise relative to `old_head`;
2. candidate residual inner-product metric did not improve: `sump >= sumold`;
3. `Fmax` is still above the compartment balance criterion.

When this occurs:

- stop trying smaller backtracking factors;
- stop further outer Newton iterations;
- follow the existing nonconvergence / timestep-reduction return path.

The Richards equations, Newton correction, tolerances and mass criteria are unchanged.

## Qualification before any production consideration

Compare baseline and candidate over the frozen PUB-P2E04 162-case Reference census.

Required:

- identical terminal class for all 162 cases;
- identical failed stage for all 162 cases;
- identical accepted-case outputs within the existing census authority;
- no accepted case may trigger the stagnation shortcut;
- count saved nonlinear iterations and backtracking candidates;
- paired runtime on the frozen hard case.

A changed failure/retry timing is expected and is the explicit subject of this workunit. A changed accepted endpoint or case classification is a blocker.
