# MP-4 MultiSWAP workload and benchmark catalog

**Workstream:** MP  
**Status:** ACTIVE, catalog qualified; production execution pending per workload  
**Evidence-start baseline:** `3b19f079a0a744e576f752c4b3e0d7e7ac72603b`  
**Integration re-read:** `8f921df513ed5f7c4f6a4dee2a274ac2031a3fb4`  
**Affected invariants:** 6, 13, 16, 23, 24, 25, 26, 27, 30

## Purpose

MP-4 turns the MP-1 benchmark families into a versioned workload catalog before large performance measurements begin.

The central rule is that a benchmark name is not enough. Each workload must state:

- what physical/reference configuration it represents;
- whether it is actually executable and qualified;
- which scale is intended;
- which measurements are required;
- which dependency currently blocks execution, if any.

This prevents performance work from filling missing physical configuration with convenient but undocumented defaults.

The machine-readable catalog is `benchmarks/performance/workload-catalog.json` and is validated by `tools/performance/mp_workloads.py`.

## Reference policy

The catalog distinguishes three reference levels:

- `B0`: immutable official SWAP 4.3.1 audit baseline;
- `B1.2`: current corrected legacy reference after the MP-4 integration re-read;
- `SWAP5-reference`: future full-accuracy SWAP5 reference mode.

Performance records must identify the exact reference snapshot used. B1 snapshots are immutable historical identities: a future B1.3 does not silently relabel a benchmark that was actually run against B1.1 or B1.2. The validator therefore accepts explicit `B1.<number>` identities while the catalog's `corrected_legacy` field points to the current snapshot.

## Catalog states

A workload can be present before it is executable. MP-4 therefore makes readiness explicit.

| Status | Meaning |
| --- | --- |
| `shadow-executable` | Can be executed in current shadow tooling, but is not yet a SWAP5 production benchmark. |
| `parameter-locked` | Source parameters are fixed, but a complete executable physical case is not yet qualified. |
| `runtime-blocked` | Needs stable RT batching/template/worker facilities. |
| `policy-blocked` | Needs a qualified numerical execution policy before the benchmark is meaningful. |
| `template-blocked` | Needs qualified comparable model templates. |
| `ready` | Fully specified and qualified for the intended benchmark use. |

The validator deliberately does not equate `parameter-locked` with `ready`.

## Benchmark families

### MP-B01: single-column decomposition

`MP-B01-HUPSEL-SINGLE` anchors the first single-column decomposition workload to the supplied `cases/1.hupselbrook` case.

Its current status is `shadow-executable`. MP-3A established measurement-disabled versus measurement-enabled equality for selected `.bal` and `.blc` outputs in the GNU shadow experiment, but this is not yet a SWAP5 production qualification.

### MP-B02: homogeneous scaling

`MP-B02-HOMOGENEOUS-SCALING` defines nominal column counts of 64, 1024 and 16384 using one qualified physical template.

It is `runtime-blocked` until RT provides stable template, batch and worker identities. Replication must preserve per-column physics. MP may not make columns more homogeneous by changing their physical configuration.

### MP-B03: mixed templates

`MP-B03-MIXED-TEMPLATES` is intended to measure scheduling and batching overhead when several qualified homogeneous templates coexist.

It remains `runtime-blocked` until at least two real templates exist. The benchmark must measure template composition rather than hide physical heterogeneity inside one batch.

### MP-B04: B12 heavy-clay stress profile

The inspected SWAP 4.3.1 distribution contains exactly one `B12` occurrence, the Staringreeks 2018 hydraulic parameter row in `data/soil/Staringreeks_2018.csv`:

```text
B12,0.01,0.529749,0.016562,1.090671,2.245895,179.6716,-4.493581,0
```

MP-4 locks this source row and its no-EOL SHA-256:

```text
8f6b214ba7894dd49be927c9384a80168f0ad05fabeb48b2f8d1330ef916e59e
```

The stored parameter mapping is:

| Parameter | Value |
| --- | ---: |
| `ORES` | 0.01 |
| `OSAT` | 0.529749 |
| `ALFA` | 0.016562 |
| `NPAR` | 1.090671 |
| `KSATFIT` | 2.245895 |
| `KSATEXM` | 179.6716 |
| `LEXP` | -4.493581 |
| `H_ENPR` | 0.0 |

The CSV row does not by itself define a complete SWAP case. In particular it does not specify the full vertical profile, discretization, initial state, forcing, boundary conditions, crop/process switches or any extra parameter required by an enabled optional process.

For that reason `MP-B04-B12-HYDRAULIC-STRESS` is deliberately `parameter-locked`, not executable or ready. The validator fails if the B12 map changes or if this incomplete workload is promoted to `ready`.

This is the key MP-4 result for B12: the difficult hydraulic material is now reproducibly identified without fabricating the rest of the physics.

### MP-B05: execution-class routing

`MP-B05-EXECUTION-CLASS-ROUTING` will compare `normal`, `relaxed` and `fallback` routes only after those policies exist and are VQ-qualified.

It remains `policy-blocked`. MP does not define a fallback merely to make a benchmark faster.

### MP-B06: optional-physics cost

`MP-B06-OPTIONAL-PHYSICS-COST` will quantify incremental persistent-state, scratch and CPU cost for optional modules.

It remains `template-blocked` until comparable qualified templates exist. The compared templates must differ by an explicitly named physical module rather than by an undocumented bundle of settings.

## Validator behaviour

`tools/performance/mp_workloads.py` checks at minimum:

1. catalog schema version;
2. unique workload IDs;
3. presence of MP-B01 through MP-B06;
4. known readiness states;
5. explicit B0, exact B1 snapshot or SWAP5 reference identities;
6. non-empty measurement requirements;
7. exact B12 source row and SHA-256;
8. exact B12 parameter mapping;
9. prohibition on promoting the incomplete B12 workload to `ready`.

The tool can also emit a readiness summary. At MP-4 creation there is one shadow-executable workload, one parameter-locked workload and four workloads blocked on future runtime/policy/template integration.

## What MP-4 does not claim

MP-4 does not claim:

- a CPU performance baseline;
- a complete executable B12 case;
- that B12 is the worst possible soil;
- that any particular solver or fallback is preferred;
- that the nominal scale points are final production sizing targets;
- that B0 and B1.2 are physically interchangeable for every workload;
- any GPU speedup potential.

## Integration boundary

- **VQ** owns physical qualification, mass-balance acceptance and reference comparisons.
- **RT** owns actual template, worker, batch and execution-class identities.
- **HY** owns solver observation events and hydraulic solver behaviour.
- **TX** owns committed state, retry and acceptance events.
- **MP** owns benchmark workload identity, performance measurements and cost distributions.

## Next safe step

MP-5 should assemble the first **fully executable difficult-column fixture** from qualified model ingredients. B12 is the preferred candidate, but the missing physical choices must be made from an existing qualified case or an explicit VQ-owned fixture specification. MP must not invent those choices merely to obtain a slow benchmark.

If the required B12 physical fixture is not yet available, MP can proceed independently with MP-B01 repeatability and measurement-overhead experiments while preserving the catalog status of B12 as `parameter-locked`.
