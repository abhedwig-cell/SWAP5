# F-PE-ELASTIC61 — two-level adaptive Reference-oracle fallback preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC60 — QUALIFIED_ADAPTIVE_NESTED_ORACLE_WITH_RESIDUAL_COVERAGE_BLOCKER`

Parent postimage:
`research/f-pe-elastic60-adaptive-richardson-oracle@6df73d9976b6a55048a19b0370266d270b9bcdf1`

Canonical authority:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Question

Can a conservative two-level nested Reference bound recover part of the 36
ELASTIC60 residual cases that lack three successful nested oracle levels,
without weakening the independent physical envelope?

## Frozen controller and physical envelope

Unchanged:
- alpha = `0.17320259355765216`;
- C-SAFE Binf limit = `0.05773585599727987 cm`;
- head error limit = `0.01 cm`;
- theta error limit = `1e-5`;
- terminal bottom-flux relative error limit = `1%`;
- integrated bottom-exchange relative error limit = `0.5%`;
- hard mass remains separate.

## Oracle levels

Evaluate the same nested Reference levels:
`N = 2,4,8,16,32,64`.

ELASTIC61 does not alter their solver settings.

## Two-level candidate

For any consecutive successful pair `N,2N`, define the observed refinement
difference `D = |O_N-O_2N|` for each physical metric.

Use the finer endpoint `O_2N`.

Frozen conservative unresolved-tail candidate:

`tail_2 <= 3 * D`.

Rationale:
ELASTIC60 preregistered a maximum accepted contraction factor 0.75. If future
increments contract geometrically no slower than 0.75, the unresolved tail
after the finer endpoint is bounded by
`0.75/(1-0.75) * D = 3D`.

ELASTIC61 does not assume this relation without validation.

## Validation before residual application

The two-level `3D` rule must first be tested only on the 60 ELASTIC60
three-level-qualified cases.

For each such case:
1. identify the exact ELASTIC60 selected triple `N,2N,4N`;
2. form the two-level candidate using only `N,2N`;
3. test whether the known `4N` endpoint lies within the `3D` tail bound for
   head, theta, terminal bottom flux and integrated exchange;
4. test whether the C-SAFE candidate plus the two-level conservative tail bound
   satisfies the unchanged physical envelope.

No residual case contributes to validation or selection of the factor 3.

If any of the 60 validation cases fails the two-level rule, the fallback is
falsified and is not applied to residual cases.

## Residual application

Only if validation passes all 60 cases:

For each of the 36 ELASTIC60 residual accepted points:
1. choose the finest consecutive successful pair among
   32/64, 16/32, 8/16, 4/8, 2/4;
2. both levels must pass independent mass;
3. compute candidate-to-fine error plus `3D` for all four physical metrics;
4. qualify only when all frozen physical limits pass;
5. if no consecutive successful pair exists, return
   `TWO_LEVEL_ORACLE_UNAVAILABLE`.

No non-consecutive pair may be substituted.

## Gates

A1. ELASTIC60 replay remains:
- 96 C-SAFE accepted;
- 96 exhausted;
- 60 three-level-qualified;
- 36 three-level-unavailable.

A2. The two-level factor is exactly 3 and is never refit.

A3. Validation uses exactly the 60 parent three-level-qualified cases and no
residual cases.

A4. The known third-level endpoint is inside the two-level 3D bound for every
validation metric in all 60 cases.

A5. All validation C-SAFE candidate conservative bounds satisfy the unchanged
physical envelope.

A6. Residual application occurs only after A4-A5 pass.

A7. Every residual qualification uses the finest consecutive successful pair.

A8. Mass gates remain independent and hard.

A9. O0/O2 C-SAFE decisions remain identical.

A10. Zero production `src/**` changes.

## Decision

ELASTIC61 may qualify a research-only two-level oracle fallback or falsify that
route.

It does not authorize production temporal-budget admission or controller
integration.
