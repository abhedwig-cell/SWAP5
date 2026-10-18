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
