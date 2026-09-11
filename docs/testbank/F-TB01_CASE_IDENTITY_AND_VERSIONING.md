# F-TB01 — Case Identity and Versioning

## Stable identity

Registered cases use a stable semantic ID with the case-definition version in the ID, for example:

`SWAP5-TB-RICHARDS-00421-v1`

The numeric `version` field SHALL equal the `-vN` suffix. The suffix is not a run counter. IDs remain human-searchable and globally unique within the SWAP5 testbank.

## Required case metadata

The F-TB01 proof-of-concept registry schema `1.1` machine-enforces the architectural case contract. A registered case SHALL identify at least:

- `case_id`, `version`, `category`, `layer`, `title` and artifact kind;
- active `physics` and `solver`;
- parameter, forcing and initial-state identities and their authority;
- a generic interval identity (`t0`, `t1`, time basis, and whether calendar semantics are genuinely required);
- oracle class, stable oracle ID/version and oracle authority;
- tolerance binding mode and, for locally governed non-exact tolerances, the full governed tolerance metadata;
- provenance and an exact source authority (`repository`, `ref`, commit, tree and primary path);
- separate `test_matrix_authority`, `evidence_authority` and `governance_authority`;
- `admission_purpose`;
- compiler/platform requirements where material;
- `cost_class` and applicable execution profiles;
- mandatory versus optional profile classification;
- qualification/maturity level;
- mass-gate applicability;
- architecture-invariant and negative-path bindings;
- moving-current preservation eligibility;
- lineage and evidence disposition.

The registry does not collapse source, matrix, execution evidence and governance into one authority.

## Maturity levels

Increasing evidence maturity is explicit:

1. `CHARACTERIZATION`
2. `OWNER_TESTED`
3. `INDEPENDENTLY_QUALIFIED`
4. `CANONICAL_PRESERVATION`
5. `RELEASE_MANDATORY`

An owner test is never independently qualified merely because CI is green. `CANONICAL_PRESERVATION` requires explicit rebinding to a later canonical postimage; it is not inferred from historical qualification.

## Admission purposes

Allowed core purposes are:

- `HISTORICAL_QUALIFICATION`
- `MOVING_CURRENT_PRESERVATION`
- `BROAD_RELEASE_REGRESSION`
- `OWNER_VERIFICATION`
- `CHARACTERIZATION`

The purpose describes evidence semantics, not merely the runner profile.

## Tolerance migration and anti-reinterpretation rule

Three registry modes are allowed:

- `EXACT_OR_HARD_ONLY`: the case has no qualified-soft threshold binding;
- `GOVERNED_BINDINGS`: every non-exact threshold is registered with stable ID/version, class, quantity/unit, meaning, scope, rationale, provenance, owner and evidence;
- `INHERITED_PINNED_AUTHORITY`: a migration-only binding for an already qualified existing asset whose tolerances remain owned by its exact pinned authority.

`INHERITED_PINNED_AUTHORITY` is not a loophole for bare tolerances. It is allowed only to register pre-existing source-bound evidence without inventing or reinterpreting its numerical limits in F-TB01. It names the authority from which acceptance semantics are inherited and carries no fabricated local tolerance records. Such a registry entry cannot, by this registration act alone, be promoted to `RELEASE_MANDATORY`. A future release-mandatory catalog must materialize or otherwise mechanically bind the governed tolerance versions it depends on.

Water mass conservation remains a separate hard gate and can never be relaxed through any tolerance mode.

## Immutability and semantic change

Once qualification evidence is frozen, the qualified case definition is immutable. A semantic change to physics, input identity, interval semantics, source, target/oracle, tolerance, expected difference class, state semantics or coverage scope creates a new case version. The new version records:

- predecessor case ID;
- reason for change;
- disposition of old evidence;
- whether results remain comparable;
- new exact source, matrix, evidence and governance authorities.

Cosmetic registry corrections that cannot affect execution or interpretation may be handled by registry revision, but SHALL NOT rewrite frozen historical evidence.

## Historical evidence versus current preservation

Historical evidence proves exactly:

`candidate source authority × frozen test matrix × exact execution/evidence authority × governance disposition`.

A later canonical source is a new source authority. Reusing a historical case as moving-current preservation requires an explicit current binding and, when source-sensitive assumptions changed, a reviewed delta-revalidation. Otherwise `current_preservation_eligible` is false.

## Frozen matrices and reports

A matrix manifest is versioned/content-addressable through Git commit/tree/blob authority. It lists exact case versions, oracle/tolerance versions or explicitly pinned inherited authorities, and profile semantics. Execution reports name the source authority, matrix authority, case version, evidence purpose, oracle/tolerance binding and separate execution/governance authorities. Reported totals are calculated from the executed manifest and SHALL NOT be hand-entered as claims of scientific coverage.

## F-TB01 proof-of-concept limitation

F-TB01 validates that this metadata model, registry validation and report contract are practical on a small set of existing assets. It does not requalify the scientific content, tolerance values or governance conclusions owned by those assets and does not claim the full scientific catalog is complete.
