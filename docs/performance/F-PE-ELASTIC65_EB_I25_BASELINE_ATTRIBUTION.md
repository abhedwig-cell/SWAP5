# F-PE-ELASTIC65 — EB-I25 baseline attribution

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_BASELINE_ATTRIBUTION

Canonical production baseline:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Attribution branch:
`research/f-pe-elastic65-eb-i25-baseline-attribution`

Workflow run:
`36710908244`

Purpose:
determine whether the EB-I25 preservation failure observed while qualifying
ELASTIC65 is caused by the mode-7 C-SAFE production binding or already exists
on the unchanged canonical production tree.

## Method

The attribution branch was created directly from the exact canonical head.

Only the stale hand-written source list in
`tests/fkt/run_fkt22_eb_i25_preservation_gate.sh` was made
dependency-complete. No `src/**` file was changed.

The workflow explicitly verified:

`HEAD:src == integration/f-ci-canonical:src`.

Marker:

`F_PE_ELASTIC65_EBI25_BASELINE_PRODUCTION_IDENTITY=PASS`.

The resulting executable therefore uses the exact canonical production source
tree while allowing the previously stale EB-I25 runner to compile against the
current module dependency graph.

## Result

The dependency-complete canonical baseline compiles through the complete
serialized backend and then fails at the same runtime assertion observed on the
ELASTIC65 admission branch:

`EB_I25_TEST_FAIL external full-half outflow fixture rejected before commit`.

The failing fixture is:

- bottom mode 2;
- swkimpl=0;
- `TX_TEMPORAL_EXTERNAL_FULL_HALF`;
- no model temporal indicator budget;
- soil-temperature active;
- positive top-flux outflow fixture.

It is not the ELASTIC65 mode-7 model-certificate route.

Earlier assertions in the same canonical execution pass:

- `EB_I25_TWO_HALF_ACCEPTED_AGGREGATION=PASS`;
- `EB_I25_MISSING_TOP_DONOR_FAIL_CLOSED=PASS`.

## Attribution

The EB-I25 outflow assertion failure is reproduced with bit-identical canonical
production source.

Therefore it is a pre-existing canonical preservation/test issue and cannot be
attributed to ELASTIC65.

Classification:

`PRE_EXISTING_CANONICAL_EB_I25_OUTFLOW_FIXTURE_FAILURE_NOT_ELASTIC65_REGRESSION`.

This result does not repair or waive the EB-I25 issue. It only establishes
ownership attribution.

ELASTIC65 admission must not modify the EB-I25 expected semantics merely to make
its PR green. The EB-I25 issue should be routed separately to its owning line.

For ELASTIC65, the relevant preservation evidence remains:

- its exact-head owner qualification;
- F-KT22 serialized compile closure;
- F-KT22 serialized runtime closure;
- Ross12 serialized production preservation;
- mode-2 and mode-5 preservation within the ELASTIC65 owner suite.

The pre-existing EB-I25 failure is recorded but is not evidence of a regression
on the ELASTIC65 dependency surface.
