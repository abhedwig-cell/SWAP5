# MC-SOL01-SURFACE-AGE01 | isolated candidate (2026-10-18)

Baseline: canonical `fa09e2982cc73a43d1e81bfcd192c5bf5639dd23`.
The admitted Reference pond water and solute model is untouched. RossFast remains frozen/optional. Aquifer excluded.

**Finding:** admitted `mod_fmr_b111_age_route` rejects nonzero top flux and the admitted `mod_b111_age_tracer_substep` excludes pond/rain/irrigation physics. Its `age_pond_previous_concentration` is not a separately persisted pond age *amount*. It is **not** safe to enable its legacy surface branch by deleting the guard: surface age production, runoff export, dry-to-wet transition, and restart ownership would be inconsistent.

**Candidate:** `mod_b111_surface_age_budget` is deliberately isolated and has no entry into current production. It owns no committed state and changes no accepted water/solute source. Given an accepted substep with explicit gross rain, irrigation and runon, beginning/end pond water, infiltration, runoff and evaporation depths, it checks the water balance, adds externally specified age loads, ages water with a documented midpoint-in-time approximation and partitions pond-age amount across retained water, infiltration and runoff. Evaporation exports no age amount. Output age amounts use cm day and mean ages use day.

**Qualification boundary:** a deterministic native O0/O2 process runner exists in `tests/nut-sol/run_surface_age_budget.sh`, covering mixing, external ages, water and age closure, evaporation, invalid rates and dry cases. **Not executed yet** and no real hydraulic production qualification claimed.

**Required before admission:** a separately persistent pond age amount and revised joint restart schema; actual Reference accepted-substep provenance bound atomically to the water trial; top age injection into matrix age process; handling of dry-down and total pond evaporation; independent fresh-process restart; O0/O2 real physical joint, negative rollback and preservation of admitted age, pond chemistry, NUT and canonical. Do not confuse an isolated process PASS with scientific admission. No mastercoverage promotion.

The current isolated operator is a **research candidate**, not a production API nor a complete MC-SOL01-SURFACE-AGE01 outcome.
