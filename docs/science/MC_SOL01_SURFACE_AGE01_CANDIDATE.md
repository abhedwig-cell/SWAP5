# MC-SOL01-SURFACE-AGE01 | isolated candidate (2026-10-18)

Baseline: canonical `fa09e2982cc73a43d1e81bfcd192c5bf5639dd23`.
The admitted Reference pond water and solute model is untouched. RossFast remains frozen/optional. Aquifer excluded.

**Finding:** admitted `mod_fmr_b111_age_route` rejects nonzero top flux and the admitted `mod_b111_age_tracer_substep` excludes pond/rain/irrigation physics. Its `age_pond_previous_concentration` is not a separately persisted pond age *amount*. It is **not** safe to enable its legacy surface branch by deleting the guard: surface age production, runoff export, dry-to-wet transition, and restart ownership would be inconsistent.

**Candidate:** `mod_b111_surface_age_budget` is deliberately isolated and has no entry into current production. It owns no committed state and changes no accepted water/solute source. Given an accepted substep with explicit gross rain, irrigation and runon, beginning/end pond water, infiltration, runoff and evaporation depths, it checks the water balance, adds externally specified age loads, ages water with a documented midpoint-in-time approximation and partitions pond-age amount across retained water, infiltration and runoff. Evaporation exports no age amount. Output age amounts use cm day and mean ages use day.

**Qualification boundary:** a deterministic native O0/O2 process runner exists in `tests/nut-sol/run_surface_age_budget.sh`, covering mixing, external ages, water and age closure, evaporation, invalid rates and dry cases. **Not executed yet** and no real hydraulic production qualification claimed.

**Required before admission:** a separately persistent pond age amount and revised joint restart schema; actual Reference accepted-substep provenance bound atomically to the water trial; top age injection into matrix age process; handling of dry-down and total pond evaporation; independent fresh-process restart; O0/O2 real physical joint, negative rollback and preservation of admitted age, pond chemistry, NUT and canonical. Do not confuse an isolated process PASS with scientific admission. No mastercoverage promotion.

The current isolated operator is a **research candidate**, not a production API nor a complete MC-SOL01-SURFACE-AGE01 outcome.

## Additional execution record (2026-10-18)

Native gfortran is available in the local environment, but this chat container cannot resolve github.com for a repository checkout. The PR includes a narrowly scoped O0/O2 Actions workflow (`.github/workflows/mc-sol01-surface-age01.yml`) to execute the actual source exact script if triggered. As of the check on head `f4acd6f509704f104468f34e4afa14f71d0fb9f4`, no workflow run carrying its name was listed. Therefore compiled qualification is **NOT YET ESTABLISHED**. The updated negative oracle refuses the complete-evaporation age-stock singularity. No code from this candidate is called by the admitted runtime.

## 2026-10-18 execution continuation

The source-exact isolated budget was compiled and executed **locally under GNU Fortran O0/O2 with -Wall -Wextra -Werror -fcheck=all and floating-point traps**. Initial real equality warnings were corrected; the native candidate test passed at both optimization levels. A later 200-case positive gross-input and closure sweep also passed locally O0/O2, and GitHub Actions run 39125154821 (prior to persistent-owner addition) concluded SUCCESS on the expanded budget source and test.

A separate *still isolated* persistent age owner, `mod_b111_surface_age_owner`, now supports explicit initialization, typed snapshots, candidate-only substeps, revision, identity-checked restart and rejection without mutation. The owner supplies stored age stock itself instead of trusting caller-supplied values. This is not yet integrated into the admitted Richards joint water/age restart and does not claim any production physical qualification. The combined native O0/O2 owner+budget script is being assessed by GitHub Actions run 39125283736; record its actual terminal result before promoting this phase.

The age production approximation presently uses midpoint pond depth times dt and excludes complete evaporative emptying with retained age stock. An independently justified dry residual-age sink or restartable residual pool is required before that case can be admitted. No solver, RossFast or canonical production source changed.

## Native combined owner qualification result

GitHub Actions run `39125283736`, job `117669000591`, completed **SUCCESS** for isolated O0/O2 owner plus age-budget tests. The upstream branch does not lag canonical at the time of this check. This is process/owner qualification only, **not** physical joint hydraulic, accepted infiltration transfer or V2 fresh-process restart qualification. The existing `mod_b111_age_tracer_substep` explicitly rejects nonzero top flux and the existing age joint application requires zero ponding. Removing those gates without a new jointly owned source/restart contract would be unsafe. No default activation or RossFast scope extension is authorized.

## Accepted Reference trace bridge candidate (2026-10-18)

New private module `src/runtime/mod_b111_surface_age_trace_bridge.f90` constructs a trial surface-age budget from the actual `fmr_water_flux_substep_trace_t` accepted hydraulic fields. It requires available final-converged gross source provenance and explicit pond begin/end. It verifies owner time, forbids unsupported positive qtop exfiltration and snowmelt, computes rain/irrigation/runon source depth, infiltration, runoff, and evaporation from those accepted typed fields, then creates a candidate owner without committing anything. Soil-age injection and acceptance remain unimplemented; never advance the surface-age owner independently of the water-and-soil-age transaction.

The bridge is **not yet compiled or physically qualified**, and no production runtime invokes it. There is intentionally no mastercoverage promotion or merge authorization for this new source. The preexisting isolated owner O0/O2 qualification PASS (run 39125283736) is not evidence for the bridge.

## Candidate topsoil age transfer (2026-10-18)

The new isolated `mod_b111_surface_age_soil_handoff` applies the already derived infiltration age amount to a candidate first-soil-compartment age stock, without modifying the previously admitted B1.11 age process or hydraulic state. It validates nonnegative/finite stock, rejects overdraw/overflow and tests whole pond + soil age closure. Native O0/O2 oracle: `tests/nut-sol/test_surface_age_soil_handoff.f90`, run by the existing bounded surface-age workflow. **This is not yet an accepted coupled soil transport scheme.** A subsequent implementation must replace the legacy zero-top guard with a source-owned flux on the actual accepted soil-age substep, rather than applying this additive transfer twice, and must jointly commit the pond, soil-age and water candidate with a single restart.

## Opt-in B1.11 age top boundary candidate

The existing B1.11 age substep now accepts an **explicit opt-in**, `accepted_surface_age_available` plus `accepted_surface_age_input_cm_day`, in the native age forcing. Default remains false and retains the historical zero-surface age exclusion. For an opted-in finite nonnegative input, the process receives the surface-age flux at the first soil face and continues its existing production/transport and compartment balance. This does **not** grant any arbitrary caller authority: a future joint transaction must bind the flux to the exact accepted Reference surface-age receipt and require identical infiltration water/time provenance. The provisional standalone topsoil handoff and this integrated process branch are alternatives, and must never both apply the same infiltration age amount.

**Not admitted:** this new process source has not yet passed its O0/O2 tests, historical 150-step age and actual Richards/age incumbent preservation, or physical joint rollback/restart. No canonical merge or default activation is permitted on current evidence.

## Integrated age-route opt-in continuation (2026-10-18)

The candidate `mod_fmr_b111_age_route` now accepts paired optional surface owner and source ages. On each accepted hydraulic substep, it generates a private candidate surface-age receipt, passes its infiltration amount into the opt-in B1.11 age top face, independently enforces equal pond-to-soil transfers and includes that flux as an inward boundary in the **soil-only** budget. It advances the trial pond and soil age together, retaining both committed age states on any rejected substep. The caller must not additionally call the standalone topsoil handoff. Default age route without a surface owner preserves the zero-top guard.

This is not yet an accepted hydraulic/age triple transaction: neither the water commit application nor the native joint disk restart was changed. A new full-module O0/O2 compilation qualification is queued in Actions run `39128401198`; no PASS claim is made before it finishes. The numerical O0/O2 process and bridge gates `39127411912` and `39127210034` passed before this new integration source change. No RossFast change, no mastercoverage promotion.

## Joint hydraulic and age transaction candidate

An optional Reference surface-age owner can now be passed to `run_age_joint_interval`. The active opt-in verifies its pond stock time and depth against the committed hydraulic state, stages surface age and soil age together from the accepted trial substeps, and publishes both age owners only **after** a successful hydraulic candidate commit. Old no-surface callers preserve the original zero-pond route. Optional restart schema 2 carries a separately validated surface-age restart payload alongside water and soil age, with atomic restore to all three owners only after matching water, soil, pond depth, clock and identity. Schema 1 remains the default for legacy callers. No new physical solver or RossFast implementation is touched.

This final source has **not yet been compiled or qualified**. A source-exact O0/O2 physical native triplet, rejection/retry replay and independent-process restart are required before admission. The focused Actions qualification of the preceding compilation composition (`39129180281`) was still queued at last read, so no PASS is attributed to the integrated joint application or optional restart. No mastercoverage promotion or canonical merge is permitted on the evidence here.

## Remaining persistent disk restart limitation

The optional schema 2 in `mod_fmr_b111_age_joint_application` is currently **an in-memory typed restart bundle only**. Existing production disk adapter `mod_age_joint_restart_file` has the unchanged magic `S5AJ0001` and serializes just hydraulic state and soil age, not the new surface-age stock. It must not be described as a completed persistent V2 disk restart. A separate bounded disk writer/reader revision with CRC, identity/size guards, negative forgeries, and independent process continuation is required. The production call site also requires native joint state/pond evidence before scientific qualification; the current module-compilation CI alone is not sufficient.

## 2026-10-18 qualification and restore-target guard

The exact previous joint-source qualification `39129526846` has both `isolated-o0-o2` and `reference-bridge-o0-o2` SUCCESS. This is native source compilation and bounded numerical tests, not a full positive-pond triplet physical replay or independent disk restart. The subsequent change `5bd4b0f0205df580b6ae075d9ee5bf5c2d61e729` prohibits restoring schema-2 triplet state into a previously initialized surface-age target, matching the water and soil-age no-overwrite rule. The fresh postimage Actions run is `39130356375`; final verdict must be checked explicitly. S5AJ0001 disk layout remains unchanged and has no serialized surface-age mass.

## Persistent surface-age sidecar research candidate

A separate fixed-length `S5PA0001` surface-age sidecar now records identity, revision, clock, pond depth and the **amount** of surface age (cm day) with an integrity checksum; it does not modify or extend the incumbent `S5AJ0001` water+soil-age disk schema. The restore code verifies exact file length, magic, checksum, expected identity and state bounds, then reconstructs a private candidate and rejects overwriting an initialized owner. O0/O2 native tests cover write, wrong identity, read, age advancement, no-overwrite and single-byte corruption. **No executed PASS yet for this source**. The checksum is an accidental-corruption detector, not an adversarial cryptographic signature.

The sidecar is not itself a safe atomic three-owner restart: a future composite load must restore the existing water+soil-age payload and the new sidecar into separate temporary owners, verify matching physical pond level/time/identities and publish all three only after all files pass. Failures may not modify existing targets. Fresh-process paired continuation of the real Richards triplet remains unqualified. Do not merge PR #1309 on process/sidecar tests alone.

## S5PA0001 fresh-process test extension

The sidecar now also has an independent-process `write` / `read` and age-continuation oracle (`test_surface_age_disk_process.f90`). It validates exact retained cm day age stock and the next accepted ageing increment after fresh loading under O0 and O2, in addition to corruption, identity and overwrite negatives. Latest focused Actions run `39130721448` was queued at the point of this documentation update. No passing qualification is claimed until its actual terminal result is observed. This is **surface-age-only** fresh-process persistence, not the still-absent atomic water+soil+surface triplet disk snapshot.

## Composite disk restoration candidate

`src/adapter/mod_b111_age_triplet_disk.f90` now stages the existing `S5AJ0001` water-and-soil-age payload and the new `S5PA0001` surface-age sidecar into **temporary owners**. Only after `age_joint_states_match` verifies clock, soil moisture and pond depth does it assign all three reconstructed owners. If either disk input is corrupt, missing, mismatched or otherwise rejected, the caller's owners remain unchanged. Overwriting any initialized target is also rejected. The source was added to the full Reference module-closure compile root; final O0/O2 status of run `39130906284` still needs verification.

This is a **reader candidate**, not an atomic paired disk writer. A crash between two independently written files can leave a mixed generation; the reader must reject such a pair if clocks/physical state differ, but equal-time accidental pairing still needs stronger shared generation binding. There is no qualified fresh-process real Richards three-owner continuation test yet. Therefore `MC-SOL01-SURFACE-AGE01` remains unadmitted and draft.

## Bounded actual Richards triplet disk regression

The existing physical `test_age_joint.f90` on this research branch now also exercises `restore_age_triplet_disk` using an actually accepted Reference Richards and B1.11 age interval. It writes the admitted S5AJ0001 hydraulic+soil-age restart and a separately initialized **dry-pond, zero-stock** S5PA0001 surface-age sidecar, then checks that a missing sidecar and a wrong surface identity fail with no hydraulic or soil-age state restored; a matching pair must restore the same accepted water and soil age. This is deliberately a **dry-pond** regression and is not evidence for positive pond or runon age physics. The new physical job in the focused workflow uses the existing real `run_age.py` O0/O2 suite and its independent-process continuation checks. Await actual GitHub completion; do not claim a numerical PASS for this change before it is reported.

## Disk corruption oracle correction

The previous byte-corruption test attempted to restore into an already-initialized surface owner. That erroneously tested the no-overwrite guard instead of the checksum. Commit `cb3c1ebd459ec70d332b84ab5aae77a9129d42fd` changes the target to a fresh uninitialized owner and asserts that it remains uninitialized on corrupted input. This correction is required for trustworthy corruption evidence. Hosted test run `39131990244` was still queued at the time of this check; it is not yet qualified.

## Late validation update: bounds checks and current CI

GitHub Actions run `39130906284` completed with SUCCESS for both Reference full-closure O0/O2 and isolated O0/O2 jobs, establishing source-scoped compilation of the composite disk reader on that earlier commit. Later run `39131159907` includes an actual dry-pond physical Richards/soil-age triplet test but was still queued at the last check. Run `39131990244` tests the corrected real checksum oracle, also still queued. The latest sidecar tests now additionally verify that an eight-byte truncated sidecar and a 57-byte overlong sidecar are rejected without initializing a destination owner (commit `134ba8ae6f10e1502f48061c7f55430e1c951116`); run `39132251040` was still queued. These are isolated hardening tests, not authorization for positive-pond physical or crash-consistent snapshot admission.

## Actual native triplet regression qualification (18 October 2026)

Both full hosted runs `39131159907` and `39131990244` completed SUCCESS across the isolated O0/O2, full Reference closure O0/O2, and `physical-dry-pond-triplet` native jobs. These runs establish the bounded real Richards + soil age dry-pond composite-restoration preservation and both invalid-path rejection checks, not the still-unrun positive-pond physical triplet. The newest exact-source file-length hardening run `39132251040` was still queued at verification. Canonical is presently 26 commits beyond the research branch; rebase/admission pending. RossFast untouched.
