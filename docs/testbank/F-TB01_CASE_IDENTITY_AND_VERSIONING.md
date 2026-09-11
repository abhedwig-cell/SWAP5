# F-TB01 — Case Identity and Versioning

## Stable identity

Registered cases use stable semantic IDs, for example:

`SWAP5-TB-RICHARDS-00421-v1`

The suffix is the case-definition version, not a mutable run counter. IDs remain human-searchable and globally unique within the SWAP5 testbank.

## Required case metadata

A case record SHALL identify at least:

- `case_id`, `version`, `category`, `layer`, `title`;
- active `physics` and `solver`;
- parameter, forcing and initial-state identities;
- generic `interval` (`t0`, `t1`, units/calendar only if required);
- oracle binding and tolerance bindings;
- provenance;
- `source_authority` (`repo`, `ref`, exact `commit`, exact `tree`, referenced `path` where applicable);
- `test_matrix_authority`;
- `evidence_authority`;
- `admission_purpose`;
- compiler/platform requirements where material;
- `cost_class` and execution profiles;
- optional/mandatory status;
- qualification/maturity level;
- mass-gate applicability;
- lineage and supersession information.

## Maturity levels

Increasing evidence maturity is explicit:

1. `CHARACTERIZATION`
2. `OWNER_TESTED`
3. `INDEPENDENTLY_QUALIFIED`
4. `CANONICAL_PRESERVATION`
5. `RELEASE_MANDATORY`

An owner test is never labelled independently qualified merely because it is green in CI. `CANONICAL_PRESERVATION` requires explicit rebinding to a later canonical postimage; it is not inferred from historical qualification.

## Admission purposes

Allowed core purposes:

- `HISTORICAL_QUALIFICATION`
- `MOVING_CURRENT_PRESERVATION`
- `BROAD_RELEASE_REGRESSION`
- `OWNER_VERIFICATION`
- `CHARACTERIZATION`

The purpose is evidence semantics, not just a runner profile.

## Immutability and semantic change

Once qualification evidence is frozen, the qualified case definition is immutable. A semantic change to physics, input identity, target/oracle, tolerance, expected difference class, state semantics or coverage scope creates a new case version. The new version records:

- predecessor case ID;
- reason for change;
- disposition of old evidence;
- whether results are comparable;
- new exact matrix/source/evidence authorities.

Cosmetic metadata corrections that cannot affect execution or interpretation may be handled by registry revision, but SHALL NOT rewrite the historical frozen evidence record.

## Historical evidence versus current preservation

Historical evidence proves exactly:

`candidate source authority × frozen test matrix × exact evidence authority`.

A later canonical source is a new source authority. Reusing a historical case as a moving-current preservation test requires either (a) a matrix explicitly designed to be source-independent, or (b) explicit `delta_revalidation` showing that source-sensitive assumptions remain valid. Otherwise `current_preservation_eligible` is false.

## Frozen matrices

A matrix manifest is versioned and content-addressable through Git commit/tree/blob authority. It lists exact case versions, oracle/tolerance versions and profile semantics. Reported totals are calculated from the executed manifest and SHALL NOT be hand-entered as claims of coverage.