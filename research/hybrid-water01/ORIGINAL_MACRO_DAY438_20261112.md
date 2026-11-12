# Day 438: accepted cached residual fails a fresh same-state evaluation

Baseline: canonical `20fc1a56dcee2c741e6d97de51d59e9852cbc07c`, after PR1654.
This is a bounded research observation, not a physics repair or reference promotion.
Production model source, initial native files, execution order and tolerances are
unchanged. The final accepted step has a concrete coupled-residual inconsistency.

## Hypothesis and preselected acceptance evidence

The whole481 trajectory has a 79.511365659cm groundwater discrepancy on day438.
One selected discriminator asks whether its final accepted solver step actually
continues without convergence, or instead converges on a frozen residual which
fails a fresh evaluation of the original coupled operator on the same state.
The selected owner record predates execution. Only original432to438 is executed:
one source-identical control and one observer, 20-second cap each, no full runs.
The original432 native package is verified against its original build/input binding.
No checkpoint is rebound and the observer publishes no source-bound day package.

The observer adds only a research call at the original convergence/nonconvergence
return branches. At the final438 endpoint a Linux fork clones the complete live
Fortran state, including the original step origin, flags, rates and iteration
workspace. Only that child calls the unmodified original vector_F(1,hgrad).
It logs original/current residual vectors and criteria, then exits without normal
Fortran cleanup. The child has a 2-second alarm. The parent waits, keeps its state
and retains the original accepted physics. The snapshot is taken before original
macro cleanup. There is no reconstruction from daily averages or a foreign state.

Control and observer both reproduce all retained physical433to438 daily records,
including pressure, all stocks, fluxes, balances and retry counts exactly. Both
raw native endpoint files, result.end and full S5MAC006 macro.bin, are byte-exact
between the two executions. This directly qualifies observation noninterference
on the selected trajectory; it does not qualify scientific equivalence.

## Observed result and decision

Ubuntu26.04 run [43167302507](https://github.com/abhedwig-cell/SWAP5/actions/runs/43167302507),
job131012065925, PASS at source `fe11b65305189d10f210c59da6622ace5648c4df`.
Control takes 6.027seconds, observer 5.841seconds; both stay below 20seconds.
This is total controller/model wall time, not isolated solver CPU or runtime parity.

| Final accepted-step property | Observed value |
| --- | --- |
| Original branch | Converged, not continue-without-convergence |
| Original time1900 at step start | 36232.999922441741 |
| Step length | 7.756941163949982e-5days = 6.701997166seconds |
| Nodes / bottom condition / iterations | 112 / original Cauchy3 / 12 |
| Original flunsatok flags / macro rate-reduction level | All three TRUE / 0 |
| Cached maximum compartment residual | 5.801720215359296e-12 |
| Unchanged original local criterion | 1e-6 |
| Fresh maximum compartment residual | 4.319762946264734 |
| Fresh / local criterion | 4319762.946 |
| Cached total residual | 3.419538743164509e-12 |
| Unchanged original total criterion | 1e-5 |
| Fresh total residual | -42.977539768372964 |
| Nodes failing the original local criterion | 38; largest at node81 |

The hypothesis of final-step continuation without convergence is falsified for
this endpoint. The solver declares convergence with all three original cache flags
TRUE, but its accepted cached residual is inconsistent with an original fresh
coupled residual at the identical soil state. A closed daily inventory cannot
establish pressure accuracy. The legacy freeze policy, rather than a changed
physical tolerance, is a concrete numerical consistency defect to address.

The fresh operator calls both original top-boundary and macropore updates; the
observation establishes their coupled residual discrepancy, not a separate
attribution to an individual flux formula. It does not prove how much of the
79.511cm groundwater difference arises from this endpoint or establish a new
scientific reference. Earlier steps and the actual original-reference pressure
trajectory are not independently qualified by this one snapshot. All previous
failed comparisons and full-run results retain their exact scopes.

## Preserved source, build and native identity

`original-macro-day438-evidence.zip` is the complete raw Actions artifact13920197946,
2440771bytes, SHA256
`d66b55a4368a3d6b519590557fc4feae8ab8be3271912d8ed68e9320f43a7f63`.
It preserves actual original/observed executables, observation source/C helper,
compiler/link commands, original native input, both raw endpoints, all daily
records and the full residual vectors. Metadata is recorded separately in
ORIGINAL_MACRO_DAY438_ARTIFACT_20261112.json; the original481 evidence archive
retains the verified whole-period journal and initial432 package.

Raw endpoint SHA256 values are:

- result.end: `a7c69f9264499ace2f450f690a2e826a559c1f0f69812f4c6cc52cf8e01cb27d`
- macro.bin: `543a8c2242924b21521b4b564ee947dc84cede0da386fee1e7e93d00adbefc3f`

Actual start command at the executed source was:

```sh
python3 -B research/hybrid-water01/probe_macro_day438.py --provider "$RUNNER_TEMP/provider" --proof "$RUNNER_TEMP/proof" --output "$RUNNER_TEMP/day438"
```

The provider is the unchanged frozen Linux compiler/object closure selected by
PROOF_INDEX.json, not an assumed flat path. The proof is the immutable PR1654
archive. Exact extraction commands and hashes are in the executed workflow;
exact compiler SHA, flags, object closure, original identity and separate observer
identity are in raw RESULT.json/BUILD_LOG.json. Neither builder defaults nor
production source is modified to activate the observer.

From the repository root, independently reproduce the data assessment:

```sh
python -B research/hybrid-water01/audit_macro_day438.py --artifact research/hybrid-water01/original-macro-day438-evidence.zip --metadata research/hybrid-water01/ORIGINAL_MACRO_DAY438_ARTIFACT_20261112.json --output AUDIT.json
```

Compare the parsed result with ORIGINAL_MACRO_DAY438_RESULT_20261112.json.
The auditor launches zero models and verifies original origin, preserved raw
artifact digest, executed-source identity, actual executable/generated source,
all physical control records, complete raw native endpoints, residual vectors
and unchanged original criteria. The current workflow input `hybrid_macro_day438`
with `macro_expected_sha=HEAD` now selects only that preserved-data audit.
Actual model rerun commands remain frozen at the original observation source.

## Follow-through boundary

The decision is to retain the failed scientific qualification and require a
consistent coupled-state solve, not add a day438 gate or raise tolerances.
Earlier repeated provisional-convergence refresh campaigns already failed and
must not be replayed. The next corrective block must evaluate original matrix/
macro rates from explicit start-of-step state and qualify stable coupling with a
short control, mass, rollback and restart proof before a broader run is selected.
The present PR admits only the observation/evidence and its narrowed causal result.
