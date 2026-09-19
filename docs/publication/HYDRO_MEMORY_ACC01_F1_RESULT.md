# HYDRO-MEMORY ACC01-F1 result

**Decision:** `ACC01_F1_PASS_GOVERNED_TEMPORAL_ROUTE`

The governed HYDRO-MEMORY temporal-accuracy route is feasible for a genuinely state-changing prescribed root sink.

The qualification used the preregistered Stage 0 numerical policy:

- application head-error requirement: (H_{app}=0.4\) cm;
- temporal allocation: (A_{temporal}=0.25);
- model temporal budget: (H_{temporal}=0.1\) cm.

No value was changed after seeing the model response.

## Executable result

GitHub Actions run **35430447651** passed on head `7ea9e8f202af0d9f19c973239a4eddb8a3e15d66`.

For the frozen 0.1-day, 0.02 cm d-1 unbalanced root-extraction case:

- the complete requested interval was accepted;
- 2 substeps were accepted;
- 4 trial retries occurred, all due to temporal rejection;
- solver rejections: 0;
- maximum accepted normalized temporal indicator: **0.5388703918**, below the governed limit 1;
- accepted substep durations ranged from **0.00625 d** to **0.09375 d**;
- final indicator: `reference-richards-defect-bound`;
- final head-error bound: **0.01760835 cm**;
- final normalized indicator: **0.17608352**;
- maximum pressure-head change from the equilibrium origin: **0.71809187 cm**;
- ROOT versus equivalent GENERIC final head difference: **0**;
- ROOT versus equivalent GENERIC final water-content difference: **0**;
- the hard (10^{-12}) cm mass gate passed;
- O0/O2 output identity passed.

## Preregistration correction

The original F1 text expected the internal route name `reference-richards-raw-bound`. The first content-complete run showed that the already qualified indicator selected `reference-richards-defect-bound`.

Source inspection established that these are not alternative accuracy policies. The indicator always computes

[
B_infty = rac{min(|e_{raw}|_M,,2|delta|_M)}
{sqrt{min_i M_i}},
]

and labels the result `raw-bound` or `defect-bound` according to which existing bound is active.

ACC01-F1-A1 therefore corrected only the data-dependent route-name expectation. The 0.4 cm application requirement, 25% temporal allocation, 0.1 cm budget, root sink, interval, mass gate, solver settings and retry budget were unchanged.

## Consequence

The earlier CAP01 blocker is now resolved at the temporal-accuracy level. A nonzero net root sink can change the hydraulic state while satisfying a prospectively governed temporal head-error budget.

This still does **not** authorize the 90-day HYDRO-MEMORY experiment. The next independent requirement is the groundwater-interface/coupling error allocation and its executable qualification. Temporal error has received 25% of the application allowance; the remaining numerical-error budget has deliberately not yet been assigned.
