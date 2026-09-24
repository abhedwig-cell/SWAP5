# Publication experiment manifest contract

Status: **prospective evidence contract**

Purpose: define the minimum metadata that makes a numerical experiment reusable as publication and doctoral evidence without losing chronology, configuration or claim ownership.

This manifest is deliberately stricter than ordinary test or CI metadata. A test may establish that code behaves as specified; a publication experiment must additionally establish what scientific hypothesis was tested, against which comparator, with which analysis rule, and who owns the resulting inference.

## 1. Evidence classes

Every run or run family referenced by the publication programme must use one of:

- `PROSPECTIVE_PRIMARY`: designed after the scientific contract and intended to test a declared primary hypothesis;
- `PROSPECTIVE_SUPPORTING`: prospectively designed, but intended as robustness, sensitivity or explanatory support;
- `RETROSPECTIVE_REEXTRACTION`: historical run/evidence re-analysed for a new publication question;
- `FOUNDATIONAL_QUALIFICATION`: capability/verification evidence reused as prerequisite only;
- `SHARED_INFRASTRUCTURE`: case, harness or telemetry with no primary scientific inference.

Only `PROSPECTIVE_PRIMARY` may be described as a pre-specified primary publication experiment.

## 2. Required manifest fields

Recommended YAML form:

```yaml
experiment:
  experiment_id: PUB-SQ-E3-0001
  run_family_id: PUB-SQ-E3
  title: <short descriptive title>
  evidence_class: PROSPECTIVE_PRIMARY

publication:
  primary_owner: PUB-SQ
  doctoral_rq: RQ2
  thesis_synthesis_relevance: [TS1, TS2]
  excluded_primary_owners: [PUB-ME, PUB-GC, PUB-RC, PUB-SG]

chronology:
  hypothesis_declared_before_run: true
  design_declared_before_run: true
  contract_commit: <commit>
  manifest_commit: <commit>
  created_utc: <timestamp>

question:
  hypothesis_id: H4
  primary_claim_if_supported: <one sentence>
  null_or_falsifying_result: <one sentence>

system:
  repository: abhedwig-cell/SWAP5
  code_commit: <commit>
  reference_commit: <commit or null>
  capability_authorities: [<id@commit>]
  compiler: <name/version>
  build_mode: <O0/O2/etc>
  platform: <machine/runner class>

case:
  case_id: <immutable case id>
  input_digest: <sha256>
  forcing_digest: <sha256 or null>
  initial_state_digest: <sha256>
  geometry_digest: <sha256 or null>
  soil_materials: [<ids>]
  boundary_configuration: <id>

factors:
  <factor_name>: <level>

method:
  candidate_method: <method id>
  comparator: <method id>
  numerical_reference: <definition/id>
  acceptance_tolerances: <authority/id>

outcomes:
  primary_metrics: [<metrics>]
  secondary_metrics: [<metrics>]
  failure_metrics: [<metrics>]

analysis:
  predeclared_transform: <none/log/relative/etc>
  aggregation_rule: <mean/median/max/etc>
  repeat_count: <n>
  exclusion_rule: <rule>
  stopping_rule: <rule>

artifacts:
  raw_output: <path/id>
  telemetry: <path/id>
  logs: <path/id>
  derived_table: <path/id or null>
  candidate_figure: <figure id or null>

result:
  status: NOT_RUN | COMPLETE | INVALID | SUPERSEDED
  conclusion: <filled only after run>
  deviations_from_plan: <filled only after run>
```

## 3. Immutable versus derived data

Publication evidence should separate:

1. **immutable raw run output**;
2. **derived analysis tables**;
3. **manuscript figures/tables**.

A figure should never be the only surviving evidence artifact. It must be reproducible from a derived table, which in turn must be reproducible from immutable run output and its manifest.

## 4. Experiment IDs

Use stable identifiers:

```text
PUB-ME-E<n>-<nnnn>
PUB-SQ-E<n>-<nnnn>
PUB-GC-E<n>-<nnnn>
PUB-RC-E<n>-<nnnn>
PUB-SG-E<n>-<nnnn>
```

Run-family IDs omit the final numeric suffix. The scientific contracts define the `E<n>` experiment classes.

## 5. Replication and timing rules

For deterministic numerical correctness experiments, exact repeated numerical identity may be more informative than statistical replication.

For wall-clock performance experiments:

- use repeated runs;
- record machine/runner class and relevant load constraints;
- randomize or balance method execution order where feasible;
- preserve both CPU/work counters and wall time;
- do not infer solver efficiency from a single timing observation;
- retain failed/retried runs rather than silently excluding them.

The exact repeat count should be chosen and frozen before collecting primary performance evidence.

## 6. Numerical-reference rules

A `numerical_reference` entry must specify how it was constructed. It may not simply be labelled `truth`.

At minimum record:

- solver/method;
- timestep/coupling-window controls;
- convergence tolerances;
- refinement evidence showing the reference is stable enough for the tested comparison;
- whether the same reference is used for all compared methods.

## 7. Deviations

A run remains usable after a protocol deviation only if the deviation is documented before inspecting the affected primary conclusion where practically possible.

Never overwrite the original manifest. Record the deviation and, when necessary, create a superseding experiment ID.

## 8. Negative evidence

A complete prospective experiment that produces a null or unfavorable result remains `COMPLETE`, not `INVALID`.

Use `INVALID` only for failures such as:

- corrupted input/output;
- wrong code authority;
- violated predeclared experimental setup;
- instrumentation failure;
- comparator not actually executed as declared.

Scientific failure of the hypothesis is evidence, not invalidity.

## 9. Figure and table ownership

Before promoting a derived result to a manuscript figure/table, record:

```yaml
manuscript_artifact:
  artifact_id: PUB-GC-F03
  primary_owner: PUB-GC
  claim_supported: <one sentence>
  source_experiment_ids: [PUB-GC-E3-0001, ...]
  reusable_raw_data_by: [PUB-RC]
  prohibited_primary_reuse_by: [PUB-RC, PUB-SG]
```

This preserves the publication firewall even when raw runs are shared.

## 10. Minimum rule for starting publication runs

A run should not be labelled `PROSPECTIVE_PRIMARY` unless, before execution:

- the paper scientific contract exists;
- the hypothesis ID exists;
- the experiment matrix defines the tested factor space;
- the comparator is declared;
- the numerical reference is defined or the run is explicitly a reference-construction run;
- primary metrics are declared;
- claim ownership is declared.

Exploratory runs remain useful, but should be labelled as exploratory/supporting rather than silently promoted later to pre-specified primary evidence.
