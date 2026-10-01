# F-PE-MIQUAL01 result — broad post-admission moving-interface qualification

Date: 2026-10-01

Status:

`MIQUAL01_REFERENCE_COVERAGE_INSUFFICIENT`

Qualification execution:

- workflow run: `36819373048`;
- job: `110231401065`;
- workflow conclusion: SUCCESS;
- scientific classification emitted by the frozen runner: `MIQUAL01_REFERENCE_COVERAGE_INSUFFICIENT`.

Execution-correction authority:

- first run `36819254055` is `EXECUTION_INVALID_BEFORE_FIXTURE_EXECUTION`;
- it exposed no fixture results;
- the rerun changed only the compile-helper USE-regex word boundary.

Canonical authority remained:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

## Frozen-bank outcome

Reference-valid: 5/8.

Reference-valid hydraulic archetypes: B01, B12, O05.

Reference-valid cases:

- B01_N64_T49;
- B12_N64_T49;
- O05_N64_T49;
- B12_N32_T25;
- O05_N32_T25.

Reference-invalid cases:

- O14_N64_T49: reference retry/failure at interval 286;
- B01_N32_T25: reference retry/failure at interval 3457;
- O14_N32_T25: reference retry/failure at interval 2866.

All three reference-invalid cases remained physically mass-clean up to their last accepted interval, with maximum recorded ledgers around 1.19e-15 cm. Their blocker is reference nonlinear solvability under the frozen MAXIT16 evidence profile, not mass accounting.

## Classification reason

The preregistration required:

- at least 6/8 reference-valid cases;
- at least three of four hydraulic archetypes represented.

Only the second condition passes.

Therefore MIQUAL01 must classify:

`MIQUAL01_REFERENCE_COVERAGE_INSUFFICIENT`.

No threshold is changed after exposure.

## Manager evidence boundary

The MIQUAL01 runner intentionally did not execute adaptive holdouts after the reference-coverage gate failed.

Therefore MIQUAL01 establishes no new positive or negative claim about moving-interface manager physics or performance.

In particular, the O14 and B01/N32 failures are not manager failures.

## Consequence

The five reference-valid cases form an exposure-safe successor set because no adaptive results were produced for them in MIQUAL01.

A successor may preregister those five cases for direct full-versus-manager qualification without replacing a failed adaptive holdout.

O14 remains outside that successor until its full-reference solvability is addressed for a separate reason.

## Production boundary

No production change.

The canonically admitted moving-interface manager remains explicit opt-in.

`LEGACY_NUMERICS` remains production default.
