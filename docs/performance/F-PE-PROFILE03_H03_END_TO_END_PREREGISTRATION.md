# F-PE-PROFILE03-H03 — End-to-end runtime attribution

Date: 2026-09-25

Status: `PREREGISTERED_ACTIVE`

## Purpose

Measure how much the qualified H03 constitutive-reuse repair changes runtime above the focused Reference-solve microbenchmark, without converting the 35.77% local solver result into an unsupported whole-SWAP claim.

Protocol:

`RECONCILE -> BIND WORKLOAD -> PREREGISTER -> PAIRED EXECUTION -> ATTRIBUTE -> QUALIFY -> PERSIST -> CLOSE`

## Source identities

Qualified H03 candidate:

- branch: `work/f-pe-profile02-h03`
- closeout commit: `91f73a32dba236bb2b776900f7f1d8a089bac0a4`
- repair production source: `src/legacy/b1_10_port/headcalc.f90`

H03 baseline for paired comparison:

- PROFILE01 split point: `0b373c6cdaed53e26a1acb917f096bf20256f12a`

Canonical authority at the original split:

- `integration/f-ci-canonical@506c36aab6f84b74dffdf5c37fe572c1e0b46610`

## Existing runtime evidence

PROFILE02 Q6 established, for the qualified three-Newton-iteration Reference solve:

- baseline constitutive evaluations: 7
- candidate constitutive evaluations: 4
- identical physical checksum
- identical nonlinear iterations
- paired mean candidate/baseline runtime ratio: 0.642283280
- paired mean local Reference-solve speedup: 35.771672%
- paired N: 8

This is local solver evidence only.

## Workload reconciliation

The existing MP catalog identifies `MP-B01-HUPSEL-SINGLE` as the intended single-column cost-decomposition workload and records it as `shadow-executable`.

That status is sufficient for legacy/shadow performance infrastructure, but it is not by itself proof that the current SWAP5 Reference application stack can execute the same complete Hupsel production case with the H03 code path active.

Therefore PROFILE03 separates two levels:

### E1 — accepted-interval / application-host attribution

Use an already-qualified SWAP5 Reference application/runtime route containing the real H03 `headcalc` path. Compare baseline and H03 candidate on identical accepted computational work, with paired alternating order.

This level may quantify the fraction of accepted compute runtime saved by H03 before a complete external-input/output SWAP application executable is available.

### E2 — complete SWAP application runtime

Use a full executable single-column production workload from input preparation through final model state, with input and output time reported separately from dynamic compute time.

Preferred workload is Hupsel because:
- exact Hupsel source/fixture authority has been restored in F-APP03;
- MP-B01 already names Hupsel as the representative single-column benchmark;
- the workload has long enough temporal extent to amortize startup noise.

E2 is admissible only when the selected executable demonstrably routes through the current SWAP5 Reference Richards/H03 implementation. A legacy B0 shadow executable cannot establish H03 whole-SWAP speedup because it does not contain the candidate repair.

## Metrics

For each paired variant report:

- wall runtime;
- child CPU runtime where available;
- dynamic compute runtime where available;
- accepted interval count;
- Reference solve count;
- nonlinear iterations;
- constitutive evaluations;
- retries/rejected trials;
- normalized physical output identity;
- timing variance and paired ratio.

Primary H03 attribution:

`whole_compute_saving = 1 - candidate_compute / baseline_compute`

Secondary attribution:

`H03_share_of_total = removed_constitutive_cost / baseline_compute`

The secondary value is diagnostic and must reconcile directionally with the directly measured paired result.

## Gates

1. Baseline and candidate must execute identical physical forcing, process configuration and numerical policy.
2. Physical/model outputs must satisfy the existing qualification criterion for the selected workload.
3. H03 candidate must retain the preregistered constitutive-call reduction.
4. No timing-only instrumentation may alter accepted/rejected trial structure.
5. Paired execution order must alternate.
6. No post-hoc timing outlier deletion.
7. Full-run claims require E2. E1 results must be labelled accepted-interval/application-host attribution.
8. Input and output time must not be conflated with compute-core saving.
9. If no current full SWAP5 application executable routes through H03, persist that as an application-integration blocker rather than substituting a legacy executable.

## Current reconciliation result

The repository currently provides:
- a qualified H03 Reference path;
- paired solver timing;
- MP controlled CPU measurement tooling;
- Hupsel fixture/source authority;
- a legacy/shadow Hupsel benchmark lineage.

What is not yet established by this workunit is a single complete current SWAP5 Hupsel executable proven to route through H03. PROFILE03 must identify or construct that binding before making an E2 whole-SWAP claim.

```text
RECONCILE              = COMPLETE
BIND H03 AUTHORITY      = COMPLETE
PREREGISTER             = COMPLETE
E1 RUNTIME              = NEXT
E2 WHOLE SWAP           = PENDING_EXECUTABLE_BINDING
WHOLE-SWAP SPEEDUP      = NOT_YET_CLAIMED
```

## E1 result — accepted-interval/application-host attribution

Workflow run `36066386431` completed successfully on GNU Fortran 13.3.0, O2.

The E1 harness executes the real FMR serialized Reference application-host path for an external full-half interval. Each interval performs three Reference solves under the transaction/runtime layer. Baseline and candidate were built from the same branch state except that the baseline used `headcalc.f90` from PROFILE01 split commit `0b373c6cdaed53e26a1acb917f096bf20256f12a` and the candidate used the qualified H03 repair.

Eight alternating-order baseline/candidate pairs were measured, 4000 application-host intervals per timing sample.

```text
baseline constitutive evaluations / Reference solve = 3
candidate constitutive evaluations / Reference solve = 2
nonlinear iterations / Reference solve               = 1
physical checksum                                    = identical
paired mean candidate/baseline                       = 0.877376763
paired median candidate/baseline                     = 0.872214271
paired mean speedup                                   = 12.262324 %
paired mean delta                                     = -1711.798219 ns/interval
paired N                                              = 8
E1 paired runtime                                     = PASS
```

Observed baseline interval timings were approximately 13.77-14.23 us per external full-half interval. Candidate timings were approximately 12.10-12.92 us. One candidate sample was visibly slower than the other candidate samples, but it was retained under the preregistered no-post-hoc-outlier-deletion rule.

Interpretation:

- H03 remains materially visible after transaction and application-host overhead are included.
- The local three-iteration Reference-solve Q6 speedup of 35.77% does not transfer one-to-one to the broader interval layer.
- On this simple one-iteration-per-solve accepted-interval route, the directly measured broader speedup is 12.26%.
- This is still not a complete SWAP application or Hupsel end-to-end result. Input parsing, full process composition, long temporal evolution and output emission are not represented by E1.

Current state:

```text
E1 APPLICATION-HOST RUNTIME = PASS
E1 MEAN SPEEDUP             = 12.262324 %
E1 PHYSICAL IDENTITY        = PASS
E1 CALL REDUCTION           = 3 -> 2 per Reference solve
E2 WHOLE SWAP               = NEXT_BIND_EXECUTABLE
WHOLE-SWAP SPEEDUP CLAIM    = NOT YET PERMITTED
```

## E2 binding reconciliation

The complete Hupsel typed-adapter route is now structurally bound to H03.

Current source path:

```text
legacy Hupsel files/application processes
  -> MOD_SoilWater task 2
  -> run_b110_production_task2
  -> try_b110_production_task2
  -> reference_richards_legacy_solver_t
  -> reference_richards_legacy_solve
  -> current src/legacy/b1_10_port/headcalc.f90
```

`mod_b110_production_soil_water_task2.f90` constructs the typed request and instantiates `reference_richards_legacy_solver_t`; the Reference solver binding invokes `headcalc`. The qualified M1-C3 whole-Hupsel route therefore traverses the exact production source changed by H03.

The historical M1-C3 whole-Hupsel qualification established:

- 32,518 accepted physical intervals;
- 32,552 typed Task2 attempts;
- 34 additional retry attempts;
- no accepted-interval fallback;
- exact normalized `result.bal` identity;
- exact normalized `result.blc` identity.

Therefore E2 is architecturally valid for measuring H03.

### Reproducibility blocker found

The prior whole-Hupsel PASS was recorded as an `external_exact_asset_execution`. The exact SWAP 4.3.1 archive used for that run is not persisted in this repository, no workflow artifact remains attached to the recorded owner qualification run, and the complete external whole-run build/execution recipe was not committed.

The repository does contain deterministic B1.11 reconstruction tooling and identity records, but `tools/vq/b1_11_reconstruct.py` still requires the exact B0 archive as an input. It cannot reconstruct B1.11 from repository contents alone.

The public pinned `SWAP-model/swap-testcases` Hupsel legacy directory does expose the meteorology, crop, drainage and SWP-template assets used in the Hupsel lineage, so the application input side is largely recoverable. That does not by itself recreate the missing exact source archive/build environment needed to repeat the historical whole-run qualification.

Classification:

```text
E2 H03 SOURCE BINDING        = PASS
E2 HISTORICAL WHOLE HUPSEL   = QUALIFIED
E2 CURRENT REPLAY RECIPE     = NOT_REPOSITORY_COMPLETE
E2 BLOCKER CLASS             = REPRODUCIBILITY / BUILD-ASSET
E2 SCIENTIFIC BLOCKER        = NO
E2 RUNTIME RESULT            = NOT YET MEASURED
```

No whole-SWAP speedup is inferred from the historical run or from E1.

## E2 route binding and executable reproducibility result

Current-source route binding is now explicitly gated by workflow `F-PE-PROFILE03 H03 E2 route binding`.

Successful run `36067148732` proves the following current source chain:

```text
legacy SoilWater task-2
  -> run_b110_production_soil_water_task2
  -> admitted Hupsel/B1.11 explicit production profile
  -> reference_richards_legacy_solver_t
  -> reference_richards_legacy_solve
  -> current src/legacy/b1_10_port/headcalc.f90
  -> H03 provider_tuple_valid reuse logic
```

This closes the semantic question whether H03 is on the previously qualified whole-Hupsel typed-adapter route: it is.

However, E2 timing cannot yet be executed reproducibly from the current repository alone. The prior M1-C3 whole-Hupsel qualification record shows that its complete executable was built by combining the exact external SWAP 4.3.1/B1.11 source authority with the current typed-adapter production delta. The current repository persists identities, reconstruction tooling and patches, but not the complete 63-member source tree or the original exact outer archive required by that reconstruction.

Additional recovery checks performed for PROFILE03:

- historical SWAP5 branches contain B0 identity manifests and ordered B1 patches, not the complete exact source archive;
- public `SWAP-model/SWAP` is explicitly a legacy 4.2.0 line and is not authority-equivalent to the 4.3.1/B1.11 source used by M1-C3;
- the user Library contains historical SWAP audit ZIP packages, but the exact 4.3.1 outer source archive is not exposed as a directly materializable file in this Project context.

Therefore the state is:

```text
E2 HUPSEL -> H03 ROUTE BINDING = PASS
E2 COMPLETE EXECUTABLE SOURCE   = BLOCKED_EXTERNAL_EXACT_ARCHIVE
E2 TIMING                        = NOT_EXECUTED
WHOLE-SWAP SPEEDUP CLAIM         = NOT PERMITTED
```

This is an infrastructure/provenance blocker, not a physics or H03 qualification failure. E1 remains valid and closed at 12.262324% mean application-host interval speedup.

## E2 blocker refinement — exact archive exists but is not executable from current automation surface

Further recovery established that the exact SWAP 4.3.1 distribution is still available in the user Library in multiple copies, including:

- `SWAP_4.3.1(2).zip`, size 8,959,314 bytes;
- `SWAP_4.3.1.zip` under the historical `M1C3_work` path, size 8,959,314 bytes;
- additional numbered copies with the same recorded size.

This materially narrows the blocker. The archive is not lost.

However, the current execution surface cannot materialize the raw bytes of those Library ZIP records into the working container: the Files layer returns `This Project file does not have an authorized raw-byte materialization path.` The ZIP contents are also not text-indexed for member-level reconstruction. The local container has no outbound network access, while GitHub Actions cannot access the private ChatGPT Library.

The current repository itself is insufficient for a standalone full SWAP build: the migrated legacy source directories contain only a bounded subset of the complete 63-member B1.11 source tree.

Therefore:

```text
EXACT B0 ARCHIVE EXISTENCE       = CONFIRMED_IN_LIBRARY
EXACT B0 ARCHIVE LOST            = NO
RAW BYTES AVAILABLE TO E2 CI     = NO
CURRENT REPO FULL BUILD SOURCE    = INCOMPLETE
E2 ROUTE BINDING                 = PASS
E2 PREFLIGHT                     = PASS
E2 WHOLE-HUPSEL TIMING           = BLOCKED_BY_ARTIFACT_HANDOFF
BLOCKER TYPE                      = EXECUTION/ARTIFACT ACCESS ONLY
```

The next technically valid action is to make the already-known exact archive available to the execution environment or repository-side CI as a raw artifact. No new scientific design or solver work is required before E2 timing.
