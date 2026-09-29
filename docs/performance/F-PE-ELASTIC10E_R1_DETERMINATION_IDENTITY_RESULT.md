# F-PE-ELASTIC10E-R1 — settlement-determination identity reconciliation result

Date: 2026-09-29

Status: QUALIFIED_PROVENANCE_RECONCILIATION

Parent:
- F-PE-ELASTIC10D frozen BHR-GT object authority;
- F-PE-ELASTIC10E target corpus;
- F-PE-ELASTIC11A target-schema authority.

Workflow:
`F-PE-ELASTIC10E-R1 determination identity reconciliation`

Run:
`36532519843`

Qualified head:
`8d540320d392dd83349b472d34a2b17d76e0123e`

Artifact:
`f-pe-elastic10e-r1-reconciled-targets`

Artifact id:
`11017006232`

Artifact digest:
`sha256:cacb502dce1782e89ca8fa70c0c4aba90970856aedbbfee72fd857385dde08b5`.

## Trigger and defect classification

The historical ELASTIC10D readiness classifier matched both:

- wrapper `settlementCharacteristicsDetermination`;
- inner physical `SettlementCharacteristicsDetermination`.

That produced two classifier records for each one physical determination.

The defect is classified as:

`RESEARCH_PROVENANCE_IDENTITY_DUPLICATION`.

It did not duplicate raw BRO object bytes and did not duplicate mechanical target
calculations, because the ELASTIC10E extractor itself already traversed only the
exact inner physical tag.

## Identity reconciliation

The preregistered pair reconciliation passed exactly:

- historical classifier records: `100`;
- physical settlement determinations: `50`;
- unmatched records: `0`;
- non-identical wrapper/inner classifier pairs: `0`;
- frozen physical R2 determinations: `29`;
- frozen physical R3 determinations: `21`.

Authority file:

`docs/performance/evidence/F-PE-ELASTIC10E_DETERMINATION_AUTHORITY.json`.

For each BRO object, the authority now stores:

- physical determination index;
- frozen determination-level readiness;
- the two historical classifier indices that collapsed to that identity;
- object-level readiness separately.

## Extractor rebinding

The target extractor now accepts an explicit determination-authority input.

For every physical determination it:

1. requires a frozen authority record;
2. requires the physical source-order index to match;
3. compares the observed structural route with the frozen R2/R3 route;
4. fails closed on disagreement;
5. writes determination-level `authority_readiness`;
6. preserves object-level readiness separately as `object_readiness`.

Mixed-readiness objects are therefore represented correctly rather than
implicitly inheriting their object-level maximum readiness.

## Numerical postimage preservation

The corrected extraction was compared against the successful pre-reconciliation
artifact from run `36531232195`.

The complete preregistered numerical target tuple set is unchanged for:

- BRO-ID;
- physical determination index;
- route;
- step index;
- stress endpoints;
- strain endpoints;
- signed stress/strain deltas;
- `mv`;
- `Ssk` in m^-1;
- `Ssk` in cm^-1.

Markers:

- `F_PE_ELASTIC10E_R1_HISTORICAL_RECORDS=100`;
- `F_PE_ELASTIC10E_R1_PHYSICAL_DETERMINATIONS=50`;
- `F_PE_ELASTIC10E_R1_AUTHORITY_ROUTES=R2:29,R3:21`;
- `F_PE_ELASTIC10E_R1_VALID_TARGETS=47`;
- `F_PE_ELASTIC10E_R1_VALID_ROUTES=R2:29,R3:18`;
- `F_PE_ELASTIC10E_R1_REJECTIONS=3`;
- `F_PE_ELASTIC10E_R1_NUMERICAL_POSTIMAGE=PASS`;
- `F_PE_ELASTIC10E_R1=PASS`.

The three rejected R3 candidates remain exactly the same rejection identities and
reasons as before reconciliation.

## Scientific consequence

No physical target value changes.

The qualified mechanical corpus remains:

- 47 valid targets;
- 29 valid R2 targets;
- 18 valid R3 targets;
- 3 retained R3 zero/nonpositive-secants.

The reconciliation changes provenance precision only.

Therefore the quantitative conclusions in F-PE-ELASTIC10E remain valid, while
future predictor work must use determination-level authority from this result.

## Predictor boundary

The existing F-PE-ELASTIC11B predictor-corpus preregistration remains valid.

Its object-grouped calibration/holdout split is independent of this correction.

No predictor fitting is authorized by F-PE-ELASTIC10E-R1.

## Decision

Classification:

`DETERMINATION_IDENTITY_RECONCILED_NUMERICAL_CORPUS_PRESERVED`.

F-PE-ELASTIC10E-R1 is closed and qualified.
