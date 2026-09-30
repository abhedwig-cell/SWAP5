# F-PE-ELASTIC61 — two-level adaptive Reference-oracle fallback result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic61-two-level-oracle`

Qualified postimage:
`6e04982888db3a122d82dceae8b578a3615cc617`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36696358816`

Job:
`109825161820`

Conclusion:
SUCCESS.

## Question

Can a conservative two-level Reference fallback recover part of the 36
ELASTIC60 accepted cases for which no three-level nested Reference oracle was
available, without weakening the frozen independent physical envelope?

## Frozen authorities

Unchanged from ELASTIC60:
- global scaling alpha = `0.17320259355765216`;
- C-SAFE Binf limit = `0.05773585599727987 cm`;
- head error limit = `0.01 cm`;
- theta error limit = `1e-5`;
- terminal bottom-flux relative limit = `1%`;
- integrated bottom-exchange relative limit = `0.5%`;
- hard mass remains separate.

Reference levels:
`N = 2,4,8,16,32,64`.

Two-level unresolved-tail candidate:
`tail_2 <= 3*D`.

The factor 3 was frozen before residual application and was not refit.

## Parent replay

ELASTIC60 controller/oracle counts reproduced exactly:

- C-SAFE accepted: `96`;
- C-SAFE exhausted: `96`;
- three-level-qualified accepted cases: `60`;
- three-level-unavailable accepted cases: `36`.

A1 parent replay: PASS.

## Validation before residual use

The two-level `3D` rule was first tested only on the 60 parent
three-level-qualified cases.

For each parent-selected triple `N,2N,4N`, the candidate two-level rule used
only `N,2N` and had to bound the known `4N` endpoint for:

- pressure head;
- water content;
- terminal bottom flux;
- integrated bottom exchange.

Results:

- validation cases: `60`;
- tail-bound failures: `0`;
- physical-envelope failures: `0`.

Thus the preregistered validation gate passed completely before any residual
case was evaluated.

A2 frozen factor: PASS.
A3 validation-only derivation: PASS.
A4 third-level containment: PASS.
A5 physical-envelope validation: PASS.

## Residual application

Only after successful validation was the two-level rule applied to the 36
three-level-unavailable accepted cases.

Results:

- residual cases: `36`;
- finest consecutive successful pair available: `24`;
- no consecutive successful pair: `12`;
- physical-envelope pass among pair-available cases: `24 / 24`;
- physical-envelope failures: `0`.

Therefore the fallback recovers:

`24 / 36 = 66.7%`

of the residual coverage gap.

Combined independent-oracle coverage becomes:

`60 + 24 = 84 / 96 = 87.5%`

of all C-SAFE accepted cases.

The remaining `12 / 96 = 12.5%` accepted cases remain unqualified and fail
closed because even two consecutive successful Reference levels are not
available.

## Per-profile outcome

### profile 11060

- accepted: 24;
- parent three-level-qualified: 24;
- residual: 0.

Coverage remains:
`24 / 24`.

### profile 10260

- accepted: 24;
- parent three-level-qualified: 12;
- residual: 12;
- two-level pair available: 12;
- physical pass: 12.

Coverage improves:
`12 / 24 -> 24 / 24`.

### profile 8016

- accepted: 24;
- parent three-level-qualified: 9;
- residual: 15;
- pair available: 3;
- no pair: 12;
- physical pass: 3.

Coverage improves:
`9 / 24 -> 12 / 24`.

The remaining coverage blocker is concentrated here.

### profile 3030

- accepted: 24;
- parent three-level-qualified: 15;
- residual: 9;
- pair available: 9;
- physical pass: 9.

Coverage improves:
`15 / 24 -> 24 / 24`.

## Conservative physical bounds

Every validated or recovered case remained inside all frozen physical limits.

Representative recovered bounds include:

- head bounds of order `2e-4 ... 6e-4 cm`;
- theta bounds of order `1e-6 ... 3e-6`;
- terminal bottom-flux relative bound `0` in the reported recovered cases;
- integrated-exchange bound at roundoff scale.

These remain comfortably within:
- head `0.01 cm`;
- theta `1e-5`;
- terminal bottom-flux `1%`;
- integrated exchange `0.5%`.

## Interpretation

ELASTIC60 showed that requiring three successful nested Reference levels leaves
36 accepted C-SAFE cases without an independent oracle.

ELASTIC61 shows that a separately validated two-level conservative fallback can
recover most of that gap without tuning on the residual cases.

The strongest result is structural:

1. factor 3 is frozen from the parent contraction envelope;
2. it validates on all 60 independent three-level cases;
3. only then is it applied to residual cases;
4. every pair-available residual case passes the unchanged physical envelope;
5. no-pair cases remain fail closed.

The fallback therefore improves coverage without weakening the independent
physical qualification contract.

## Remaining blocker

Twelve accepted cases still lack even two consecutive successful Reference
levels.

Those cases are all in profile `8016` within the current bank.

ELASTIC61 does not qualify them.

The remaining problem is therefore no longer generic Reference contraction.
It is a material/state-specific Reference solvability gap.

## Decision

Classification:

`QUALIFIED_TWO_LEVEL_REFERENCE_ORACLE_FALLBACK_WITH_RESIDUAL_SOLVABILITY_BLOCKER`.

Independent-oracle coverage:
`84 / 96 = 87.5%`.

No production admission is authorized.

The next bounded workunit should attribute the remaining 12 no-pair cases and
determine whether they share one solver-local numerical floor or require a
different independent oracle construction.

No relaxation of hard mass acceptance, physical budgets or C-SAFE is permitted.
