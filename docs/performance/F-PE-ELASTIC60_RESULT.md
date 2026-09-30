# F-PE-ELASTIC60 — adaptive nested Reference-oracle qualification result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic60-adaptive-richardson-oracle`

Qualified workflow postimage:
`6726a39abc6c12c7481a8339612d9c2cf61d8915`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36695525493`

Job:
`109822448464`

Conclusion:
SUCCESS.

## Question

Can the ELASTIC58 physical-budget qualification recover broader independent
oracle coverage by selecting the finest successful nested Reference triple
before the small-substep solvability limit?

## Frozen policy

No policy value was changed.

- global scaling alpha = `0.17320259355765216`;
- head limit = `0.01 cm`;
- theta limit = `1e-5`;
- terminal bottom-flux relative limit = `1%`;
- integrated bottom-exchange relative limit = `0.5%`;
- C-SAFE Binf limit = `0.05773585599727987 cm`.

Mass remains a separate hard gate.

## Adaptive oracle

Reference levels:
`N = 2,4,8,16,32,64`.

Candidate triples, finest first:
- 16/32/64;
- 8/16/32;
- 4/8/16;
- 2/4/8.

A triple qualifies only when:
- all three levels complete;
- all three pass independent mass ledgers;
- head, theta, terminal-flux and integrated-exchange refinement each satisfy
  `D2 <= 0.75*D1 + floor`.

No two-level fallback is permitted.

For a qualified triple, the finest endpoint is used and the unresolved
refinement tail is conservatively bounded by `3*D2`.

## Controller replay

The ELASTIC58 C-SAFE bank reproduced exactly:

- accepted: `96`;
- exhausted: `96`;
- fixed N=32 oracle complete: `42`.

Thus the parent controller and fixed-oracle evidence are preserved.

## Adaptive coverage

Adaptive nested-oracle qualification:

- qualified: `60 / 96` accepted points;
- unavailable: `36 / 96`;
- unavailable because no successful three-level triple: `36`;
- unavailable because contraction failed: `0`.

This is a material coverage increase over fixed N=32:

- fixed N=32: `42 / 96 = 43.75%`;
- adaptive triple: `60 / 96 = 62.5%`.

The improvement comes solely from stopping refinement before material/state
dependent small-substep solver failure.

## Triple usage

Across the 60 qualified adaptive oracles:

- 16/32/64: `6`;
- 8/16/32: `36`;
- 4/8/16: `12`;
- 2/4/8: `6`.

The finest possible triple is therefore not universally the correct oracle.
Different profiles/states reach different solvability limits.

## Physical qualification

All `60 / 60` adaptive-oracle-qualified C-SAFE acceptances pass all frozen
physical criteria under the conservative candidate-plus-tail bounds.

Failures:
- head: `0`;
- theta: `0`;
- terminal bottom flux: `0`;
- integrated bottom exchange: `0`;
- independent mass: `0`.

Worst conservative bounds:

- head: `5.031692797246023e-4 cm`;
- theta: `2.576326600500778e-6`;
- terminal bottom-flux relative bound: `0`;
- integrated bottom-exchange relative bound:
  `1.634137694672548e-15`.

The worst head bound is about twenty times below the independent `0.01 cm`
limit.

## Per-profile coverage

### profile 11060
- accepted: 24;
- fixed N=32 complete: 21;
- adaptive qualified: 24;
- unavailable: 0;
- physical failures: 0.

### profile 10260
- accepted: 24;
- fixed N=32 complete: 9;
- adaptive qualified: 12;
- unavailable: 12;
- physical failures: 0.

### profile 8016
- accepted: 24;
- fixed N=32 complete: 0;
- adaptive qualified: 9;
- unavailable: 15;
- physical failures: 0.

### profile 3030
- accepted: 24;
- fixed N=32 complete: 12;
- adaptive qualified: 15;
- unavailable: 9;
- physical failures: 0.

## Contraction result

A particularly important negative finding is:

`contraction_fail = 0`.

Whenever three consecutive nested Reference levels successfully complete, the
preregistered contraction test passes for all four physical metrics.

The remaining blocker is therefore not poor asymptotic behavior of successful
Reference refinements.

It is the absence of three successful nested levels before small-substep solver
solvability is lost.

## Interpretation

ELASTIC59 established that blindly increasing N makes oracle coverage worse.

ELASTIC60 establishes that an adaptive nested oracle is a better independent
Reference construction:

- it respects the material/state-dependent solvability frontier;
- successful nested sequences contract regularly;
- conservative tail bounds remain far inside the pre-existing physical error
  envelope;
- coverage improves materially without changing solver tolerances or physical
  limits.

However, 36 accepted C-SAFE points still cannot supply three successful nested
levels. Those points remain unqualified rather than being silently accepted.

## Decision

Classification:

`QUALIFIED_ADAPTIVE_NESTED_ORACLE_WITH_RESIDUAL_COVERAGE_BLOCKER`.

No production admission is authorized.

The next bounded workunit may investigate a separately preregistered two-level
Reference extrapolation/bound for the 36 residual cases. Such a fallback must
first be validated against the 60 three-level-qualified cases and must not be
retroactively counted inside ELASTIC60.
