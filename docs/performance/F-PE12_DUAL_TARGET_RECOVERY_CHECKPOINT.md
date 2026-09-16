# F-PE12 — Dual-target performance recovery checkpoint

## Scope

Bounded recovery and qualification campaign for late-August / early-September 2026 SWAP performance work.

Targets:

- A: SWAP 4.3.1 stable legacy maintenance/performance line.
- B: SWAP5 current post-Status-A development line.

Protocol: `RECONCILE -> CLASSIFY -> IMPLEMENT -> QUALIFY -> CLOSE`.

Explicit exclusions: Energy Balance; RossFast modification; new physics; transaction-policy changes; mass-policy changes; hidden solver fallback; tolerance widening; production changes solely to obtain benchmark PASS.

## Authority pins

### SWAP 4.3.1 B0

The authoritative legacy baseline is the immutable byte-defined B0 recorded under `reference/swap-4.3.1/b0/`.

Controlling identities from `SOURCE_IDENTITY.md`:

- supplied `SWAP_4.3.1.zip`: SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- nested `tools/SWAP/source/SWAP.ZIP`: SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`
- 63 Fortran source members, each pinned by `file-manifest.sha256`

B0 is never reconstructed from prose or memory. Changes must be represented outside B0 as independently reviewable patches.

### SWAP5

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- live canonical commit rechecked during CLASSIFY: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- live canonical tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`

The commit/tree distinction is explicit because the tree SHA must not be mistaken for a successor canonical commit.

The previously checked `50346642... -> 992a5c...` delta is governance-only: one release-readiness document, no production-source change.

The live canonical head is an F-CI91 RossFast governance-preservation merge whose commit message explicitly states no scientific replay, production readmission or Status-A denominator change. RossFast remains out of scope here.

## Classification semantics used by this workunit

The letters below are workunit-local recovery classes, not release grades:

- **A — CORRECTNESS_FIX**: evidence establishes a defect/correction. Performance is not the admission basis.
- **B — EXACT_SEMANTICS_PERFORMANCE_CANDIDATE**: a defensible optimization route exists whose intended contract is preservation of scientific/numerical semantics. B does not imply implementation or qualification.
- **C — NON_EXACT_OR_NON_ADMISSIBLE_PERFORMANCE_EXPERIMENT**: the candidate intentionally changes numerical method or recovered evidence already shows route/output divergence. It cannot enter the exact-semantics performance path in that form.
- **D — INSUFFICIENT_RECOVERED_EVIDENCE**: provenance, exact patch bytes, semantic mapping or qualification evidence is insufficient for implementation/admission.
- **E — OBSOLETE_OR_SUPERSEDED_FOR_TARGET**: current architecture conclusively removes the old hotspot or already incorporates equivalent semantics. E requires positive mapping evidence, not merely absence of an old symbol.

## Recovered formal legacy evidence

### SWAP-011 dK/dh

Status: formally recovered.

Classification: **A — CORRECTNESS_FIX**.

The canonical legacy dossier under `reference/swap-4.3.1/patches/SWAP-011/` records a confirmed/qualified derivative defect and correction. It must not be described as a performance optimization.

GitHub issue #12 additionally preserves exact historical artifact provenance clues:

- `SWAP_4.3.1_E7_SW011_upstream_package.zip`
- `SWAP_4.3.1_SW011_overdracht_Marius.docx`
- `SWAP_4.3.1_SW011_overdracht_Marius_bundle.zip`
- `patch/SWAP-011_fix.patch`

Expected final changed source set recorded there:

- `SWAP/MOD_MvG_functions.f90`
- `SWAP/WC_K_models_04_11.f90`
- `SWAP/MOD_RIA.f90`

with `SWAP/headcalc.f90` byte-identical.

Hard provenance rule from issue #12: do not reconstruct the qualified patch from prose or memory. Exact patch/package bytes remain the required artifact for legacy admission.

The recovered D2 qualification matrix further shows why correctness and performance must remain separate: the numerical derivative correctness oracle improves the affected Newton workload overall but has a material wall-time penalty. It is a correctness reference, not a preferred performance implementation.

### SWAP-012 hydraulic inverse / hconduc-dhconduc

Status: formally recovered.

Classification: **A — CORRECTNESS_FIX**.

The legacy dossier records that the old inverse is incorrect for most hydraulic models and that the qualified correction restores the intended round-trip. The correction is not itself a speed optimization and has prior per-call cost evidence indicating it is slower. It may serve as the correctness oracle for a future faster inverse implementation.

## Recovered OxygenStress performance context

Historical WFT300 regression material establishes that its Romberg baseline already contained two earlier OxygenStress optimizations:

1. duplicate-QROMBD removal;
2. a fast no-stress exit.

This proves historical existence of both changes, but does not recover the isolated patch bytes, exact call-count evidence, or an independent exact-equivalence qualification for either change. Repeated recovery searches on `OxygenStress`, `QROMBD`, `waterfilmthickness`, `no-stress`, and related aliases did not locate an admission-grade isolated package.

Therefore:

- duplicate-QROMBD removal: **D — INSUFFICIENT_RECOVERED_EVIDENCE**;
- fast no-stress OxygenStress exit: **D — INSUFFICIENT_RECOVERED_EVIDENCE**.

These D classifications are not statements that the optimizations were wrong. They mean this campaign cannot safely reconstruct or admit them from the evidence currently recovered.

The separate SWAP-007 OxygenStress strict-FPE/Newton-overflow work remains a correctness fix and must not be merged conceptually with these performance experiments.

## WFT300 lookup

Classification: **C — NON_EXACT_OR_NON_ADMISSIBLE_PERFORMANCE_EXPERIMENT** for the exact-semantics path.

Recovered broad-regression evidence is decisive enough to close this classification:

- WFT300 replaces Romberg integration with a 300-point log-space cubic-Hermite lookup. It is therefore not bit-transparent by construction.
- Several well-conditioned cases show substantial runtime reductions while retaining the aggregate Newton histogram and only small printed-output differences.
- The B05/O05 coarse-sand case changes the Newton histogram and has many numerical differences versus Romberg.
- O05 and O13 homogeneous cases also show changed iteration histograms; O05 contains materially larger WDM differences than the stable cases.
- Increasing the O05 table from 300 to 600 or 1000 points does not remove the difference versus Romberg, which indicates a method-route difference rather than merely inadequate lookup resolution.

Consequently WFT300 must not be used as the implementation candidate for an exact-semantics performance claim. Its historical timing evidence may remain useful as research context only.

## Hydraulic K / dKdh reuse

Recovered E2/E3 material is sufficient to distinguish an admissible design direction from an unsafe cache shortcut.

### Rejected form

A hidden module-level "last K call" mutable cache is **C / not admissible for the exact path** because exact cache identity spans more than head alone and hidden cache state creates call-order, invalidation and thread-safety risks.

### Retained form

An explicit per-node combined K/dKdh evaluation or explicitly owned derivative reuse is classified:

**B — EXACT_SEMANTICS_PERFORMANCE_CANDIDATE, design-level only.**

Recovered E2 static analysis documents the duplicated hydraulic work and identifies required identity/invalidation dimensions. E3 demonstrates a source-level semantic prototype that stores per-node derivative information at conductivity update points and reuses it in the subsequent Jacobian path while preserving macropore scaling.

However E3 was not compiled or executed in the recovered workspace. It deliberately used the separate E1 K and dKdh evaluators to test state/lifetime structure rather than prove a final speedup. Therefore this B classification is not a qualification verdict and is not admission authority.

Required implementation gate before any performance claim:

- pin the exact legacy source postimage to which the prototype applies;
- preserve backtracking, frost, macropore and active-node invalidation semantics;
- strict build;
- representative hydraulic-model matrix including models 3, 7, 10 and RIA 12;
- solver-route and final-profile equivalence against the applicable correctness baseline;
- A/B/A determinism;
- only after equivalence, reproducible timing and call-count measurement.

## Remaining recovered candidates

| Candidate | Closed class in this pass | Basis |
| --- | --- | --- |
| SWAP-011 dK/dh | A | qualified correctness defect/correction |
| SWAP-012 inverse | A | qualified correctness defect/correction |
| OxygenStress duplicate QROMBD work | D | historical existence confirmed, isolated exact patch/qualification not recovered |
| OxygenStress fast no-stress exit | D | historical existence confirmed, isolated exact patch/qualification not recovered |
| WFT300 lookup | C | numerical method changes; recovered regression contains route/output divergence |
| explicit per-node K/dKdh reuse | B, design-level only | static semantic feasibility exists; runnable qualification missing |
| hidden last-call K cache | C / rejected exact-path form | incomplete cache identity and unsafe hidden lifetime/order dependence |
| clay-start optimization | D | no exact patch or isolated scientific/performance evidence recovered |
| O5 coarse-sand runtime work beyond WFT300 | D | WFT300 behavior is known, but no separate exact candidate is recovered |
| Marius handoff beyond SWAP-011 | D | exact artifact bytes/provenance remain unrecovered |

The O5 dry-end Jacobian regularisation mentioned in the WFT300 baseline is treated as correctness/robustness-adjacent context. It is not relabelled as a performance optimization without separate evidence.

## SWAP5 applicability observations

The current scientific production tree materially differs architecturally from SWAP 4.3.1:

- root uptake is owned by `src/process/mod_root_water_uptake_process.f90` and bound through explicit runtime/solver contracts;
- hydraulics are exposed through explicit solver providers/views rather than a mechanically shared legacy global path;
- the current root-water-uptake process has explicit early exits for no roots and negligible potential transpiration and allocates owned result/diagnostic arrays per call;
- no direct current production symbol named `OxygenStress`, `QROMBD` or `WFT300` has been recovered in the current source searches.

These facts block mechanical porting but do not by themselves justify class E. Equivalent work can exist under different ownership or naming. The old OxygenStress and hydraulic candidates therefore retain target-B mapping work before they can be called superseded or applicable.

WFT300 does not need that mapping to be excluded from the exact-semantics path: its recovered numerical-method change is already sufficient for class C.

## Baseline measurement contract

No new speedup is claimed at this checkpoint.

Before implementation qualification, both targets require reproducible baseline records including, where practical:

- wall time and repetition variability;
- CPU time;
- solver calls/iterations;
- relevant expensive-routine call counts;
- allocations/materializations where measurable;
- output checksum and selected scientific observables;
- mass/water balance;
- compiler, flags, runner/hardware and case identity.

Exact-semantics qualification precedes performance measurement. Required qualification evidence includes applicable O0/O2 consistency, solver-route equivalence, representative regression matrix and A/B/A determinism.

Historical MP-7/MP-8 evidence already established that the shared host was unsuitable for a 1% CPU baseline. Historical timing values without compiler/hardware/repetition metadata remain contextual rather than admission-grade speed evidence.

## Mutations in this workunit

- branch `work/f-pe12-dual-target-performance-recovery` was created from canonical `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`;
- first RECONCILE checkpoint commit: `a0446996a33710fa79d40068921947ea0d34740c`;
- this file was then advanced with recovered WFT300 and E2/E3 classification evidence;
- no production source modified;
- no legacy source modified;
- no EB or RossFast source modified.

## Current verdict

Phase state: **RECONCILE complete for the named recovery set; first CLASSIFY pass closed. IMPLEMENT not yet started.**

Closed disposition of the recovered set:

- correctness only: SWAP-011, SWAP-012;
- exact-semantics implementation candidate: explicit K/dKdh reuse, B at design level only;
- excluded from exact-semantics implementation: WFT300 and hidden mutable cache forms;
- insufficient recovered evidence for reconstruction: the two earlier OxygenStress optimizations, clay-start, separate O5 runtime work, and non-SWAP-011 Marius handoff material.

No D candidate may be re-created from narrative descriptions merely to keep the campaign moving.

## Next permitted action

1. Reconcile the B candidate to the exact available SWAP 4.3.1 source/postimage and identify its minimal owned files and invariant/lifetime contract.
2. Reconcile the same optimization concept to the current SWAP5 hydraulic owner to decide whether target B is applicable, already structurally superseded, or requires a separate later implementation surface.
3. Persist that target mapping before changing production source.
4. If and only if the mapping is clean, implement the smallest explicit-state K/dKdh reuse candidate and qualify semantics before timing it.
5. Keep WFT300, hidden mutable caches, EB and RossFast out of the implementation path.
