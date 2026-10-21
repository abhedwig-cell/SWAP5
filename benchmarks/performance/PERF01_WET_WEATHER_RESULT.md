# PERF01 wetter live-weather tolerance comparison

Completed research, 21 October 2026. Measurement baseline is `a737c60596f7d77cf2415cb09c4181d35a8a25b5`. Production sources, equations, acceptance guards and defaults are unchanged. The existing exact O2/O0 executables from PR1359 are reused. Only daily rainfall is multiplied; all other source-record tokens, soil, crop, temperature, geometry, free-drainage mode and 64-per-day coupling remain identical. This is modified meteorology for a sensitivity scenario, not observed wet weather or an Andelst site calibration.

## Double-rain case: 97 days complete

Rain increases from 227 to 454 mm for 20 January through 26 April 1999. The maximum daily rain rises from 21.9 to 43.8 mm. Rain remains uniformly distributed within each day. The largest reported daily pressure head rises from -12.67 cm in the original case to -0.06276 cm; maximum water content reaches 0.422996 compared with theta-saturated 0.423. The case is therefore meaningfully wetter and almost saturated, rather than merely relabelled.

Each principal budget has three serial O2 native observations on CPU0, reversing order in repetition2. The executable hash is `c66c46dfd280f8961bdffe7daa5ec35eb395aa4dde5f849b6f5e7681fa35bd19`. The applicable tolerance is the existing calibrated mode7 model-certificate local head budget in cm, not the earlier pond full-step/two-half-step comparator. CPU below is median process user time, including normal application/diagnostic overhead and excluding input preparation or compilation. Differences are against a finite 2.5e-7 cm trajectory, not independent physical truth.

| Head budget (cm) | Median CPU (s) | HeadCalc calls | Maximum storage difference (mm) | Maximum head difference (cm) | Total bottom-outflow difference (mm) |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1e-06 | 17.668605 | 2,164,709 | 0.00021770 | 0.002270 | -0.00015732 |
| 0.001 | 1.419184 | 113,330 | 0.00685706 | 0.110929 | -0.00685706 |
| 0.01 | 1.378571 | 101,472 | 0.00746402 | 0.205336 | -0.00746402 |
| 0.1 | 1.403882 | 100,566 | 0.00767067 | 0.208943 | -0.00767067 |
| 1 | 1.377062 | 100,113 | 0.00772870 | 0.208947 | -0.00772870 |

Moving from 1e-6 to 1e-3 cm gives a measured 12.45-fold process-CPU reduction and 19.10-fold fewer HeadCalc calls. Beyond 1e-3 cm there is little further timing gain; 1e-2 through 1cm differ mainly within timing variation. The loose end still requires roughly 100,000 HeadCalc calls and 31,000 accepted internal steps. Refinement at 1e-5, 2.5e-6 and 1e-6 cm gives decreasing maximum storage differences versus the finest trajectory: 0.002800, 0.000815 and 0.000218 mm. No universal error bound or coupled time-grid/spatial convergence is inferred.

At 1e-3 cm, actual free-drainage outflow totals 364.1267 mm, soil evaporation 12.9721 mm and transpiration 84.9554 mm. All reported runoff and pond evaporation are zero. The completed scenario remains inside the existing flux-only weather receiver's zero-pond/zero-runoff admitted domain. It does not qualify a transition to overflow or an active wet-stress response. Actual and potential transpiration are equal with the unchanged crop thresholds.

All 20 selected O2 double-rain runs finish 97 days: 15 repeated principal points, three refinement runs and two midpoint reconstructions. Gross water balances are independently reconstructed from actual accepted rain, evaporation, uptake, bottom exchange and storage: maximum daily closure residual 2.65e-10 mm; maximum 97-day residual 2.74e-9 mm. These bookkeeping residuals are separate from the up-to-0.00773 mm time-discretization spread. Physical values, accepted fluxes and work repeat exactly. Same-process application close/reconstruction at day48 reproduces the full sequence at 1e-3 and 1cm. Three reused checked O0 runs (1e-3, 1cm and midpoint reconstruction) also reproduce O2 physical values/work exactly; no new provider build is required for valid rain-input values.

## Four-rain failure is retained

The extra 4x-rain probe is an explicit failed stress test, not a completed curve point. At 1e-6, 1e-3 and 1cm the computation finishes 34 whole days, then rejects the first requested interval of day35, 23 February 1999. Scenario rain that day is 48.4 mm/day, while the material Ksat is 47.5 mm/day. This numerical coincidence does not on its own establish the causal mechanism.

A private failure-print main, excluded from all timing comparisons, reproduces the 1e-3 accepted physical/work prefix and all accepted fluxes exactly. It exposes runtime status10 / kernel status2 after 22 accepted internal steps, with 81 solver, 195 temporal and 62 mass rejections. These counters do not establish whether the ultimate limiting issue is pond/flux composition, nonlinear solving, or roundoff at the hard mass guard. The existing flux-only atmospheric receiver cannot publish ponding/runoff. No guard or retry threshold is weakened, no runoff is invented, and no day35 generation is reported as complete. This retained failure limits extrapolation to more extreme wet forcing and deserves a separate causal diagnosis.

## Reproduction and preservation

`study_perf01_wet_weather.py` constructs a new input-only build view pointing at the existing exact executable. It verifies all 256 provider inputs, both print-only overlays, the original compressed meteorology authority and that every non-rain record token is identical. Both 2x and 4x original/scenario weather bytes and hashes are retained. Existing `run_perf01_weather.py` and `assess_perf01_weather.py` remain unchanged; `assess_perf01_wet_weather.py` reuses their actual-flux/closure checks and checks complete horizons, exact repeats, refinement spread, reconstruction and explicit failure labels.

```bash
python benchmarks/performance/study_perf01_wet_weather.py --build /tmp/weather-build --output /tmp/wet2-build --rain-multiplier 2
python benchmarks/performance/run_perf01_weather.py --build /tmp/wet2-build --output /tmp/wet2-run --budget .001 --days 97
```

The case remains the prior explicit 30cm, four-cell soil with illustrative crop tables, daily-uniform rain and fixed external coupling intervals. Soil/crop calibration, more resolved geometry, rain duration, general SWP/annual/HRU application and overflow physics are outside this comparison. Full FCI, low-air and RossFast are not selected for an input-only experiment with no production changes. All native failures and successful observations are retained in the SHA-bound evidence archive described in the work-unit status.
