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
- live canonical observed during this checkpoint: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`

The previously checked `50346642... -> 992a5c...` delta is governance-only: one release-readiness document, no production-source change.

The live canonical head is an F-CI91 RossFast governance-preservation merge whose commit message explicitly states no scientific replay, production readmission or Status-A denominator change. RossFast remains out of scope here.

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

### SWAP-012 hydraulic inverse / hconduc-dhconduc

Status: formally recovered.

Classification: **A — CORRECTNESS_FIX**.

The legacy dossier records that the old inverse is incorrect for most hydraulic models and that the qualified correction restores the intended round-trip. The correction is not itself a speed optimization and has prior per-call cost evidence indicating it is slower. It may serve as the correctness oracle for a future faster inverse implementation.

## Recovered performance-governance context

- F-PE01 is SWAP5 performance/qualification measurement infrastructure, not one of the old August performance patches.
- Its earlier reference fixture records compiler/runner/solver statistics and mass-balance evidence but did not itself establish wall-time measurements.
- Historical MP-7/MP-8 evidence explicitly determined that the shared host was unsuitable for a 1% CPU baseline and left an isolated runner `INFRASTRUCTURE_PENDING`. Therefore historical timing numbers lacking compiler/hardware/repetition metadata are not accepted as hard speedup evidence.
- The current SWAP5 F-PE branch family postdates the August legacy experiments.

## Candidates not yet recovered to admission-grade evidence

The following named candidates were searched in canonical paths, branches, commit messages and issues using their direct names and obvious aliases. No admission-grade historical artifact has yet been recovered:

| Candidate | Current recovery status | Provisional class | Reason classification is not final |
| --- | --- | --- | --- |
| OxygenStress duplicate expensive preprocessing / QROMBD | historical artifact not yet recovered | D | exact duplicate-work removal is plausible, but exact patch, call-count and output evidence are still missing |
| exact no-stress OxygenStress fast path | historical artifact not yet recovered | D | must prove route is mathematically and numerically identical and preserves diagnostic/side-effect semantics |
| WFT300 lookup | historical artifact not yet recovered | C | prior campaign context reports small differences versus the Romberg route; therefore it cannot enter exact-performance admission unless new evidence proves exact equivalence |
| hydraulic K-reuse candidate | historical artifact not yet recovered | D | requires proof of invariant inputs/lifetime and no stale reuse across trial/retry/transaction boundaries |
| clay-start optimization | historical artifact not yet recovered | D | patch and scientific/performance evidence not yet recovered |
| O5 coarse-sand runtime work | historical artifact not yet recovered | D | patch, exact case identity and reproducible timing evidence not yet recovered |
| Marius handoff packages beyond SWAP-011 names | not recovered | D | filenames/provenance need exact artifact recovery, not reconstruction |

These provisional D/C entries are deliberately conservative and are not production recommendations.

## SWAP5 applicability observations

The current scientific production tree materially differs architecturally from SWAP 4.3.1:

- root uptake is owned by `src/process/mod_root_water_uptake_process.f90` and bound through explicit runtime/solver contracts;
- hydraulics are exposed through explicit solver providers/views rather than a mechanically shared legacy global path;
- the current root-water-uptake process has explicit early exits for no roots and negligible potential transpiration and allocates owned result/diagnostic arrays per call;
- no source path or symbol named `OxygenStress`, `QROMBD` or `WFT300` was found in the current production source search/tree during this checkpoint.

Therefore old OxygenStress, WFT300 or K-cache code must not be copied mechanically. Each candidate requires a semantic mapping to current owners. If the relevant legacy hotspot no longer exists, its SWAP5 disposition may become **E — OBSOLETE_OR_SUPERSEDED** even if it remains useful for SWAP 4.3.1.

The absence of a direct current symbol does not by itself prove absence of equivalent behavior. That determination remains open until current call paths and legacy reference backends are reconciled.

## Baseline measurement contract

No new speedup is claimed at this checkpoint.

Before implementation, both targets require reproducible baseline records including, where practical:

- wall time and repetition variability;
- CPU time;
- solver calls/iterations;
- relevant expensive-routine call counts;
- allocations/materializations where measurable;
- output checksum and selected scientific observables;
- mass/water balance;
- compiler, flags, runner/hardware and case identity.

Exact-semantics qualification precedes performance measurement. Required qualification evidence includes applicable O0/O2 consistency, solver-route equivalence, representative regression matrix and A/B/A determinism.

## Mutations in this workunit

- created branch `work/f-pe12-dual-target-performance-recovery` from live canonical `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`;
- added this checkpoint only;
- no production source modified;
- no legacy source modified;
- no EB or RossFast source modified.

## Current verdict

Phase state: **RECONCILE substantially complete; CLASSIFY open**.

Hard classifications closed so far:

- SWAP-011: A — CORRECTNESS_FIX
- SWAP-012: A — CORRECTNESS_FIX
- WFT300: provisionally C, cannot enter exact-performance chain on currently recovered evidence

All other named legacy performance candidates remain D until exact artifacts/evidence or a conclusive supersession mapping is recovered.

## Next permitted action

1. Continue artifact recovery through historical issue/PR discussions, generic audit branches and tree contents, including Marius handoff provenance.
2. Reconcile each unresolved candidate to the current SWAP5 owner/call path and decide whether it is B, C, D or E per target.
3. Build measurement-only reproducible baseline harnesses for B0 and SWAP5 before any production optimization patch.
4. Only after CLASSIFY closes may an exact-semantics candidate enter IMPLEMENT.
