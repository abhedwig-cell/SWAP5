# PERF01 coupled historical-weather accuracy/cost curve

Research complete,21 October2026. The previous application-composition blocker is resolved for an explicit bounded97-day live weather/crop/soil-temperature/free-drainage driver. The general historical SWP regional application remains outside this claim. No production source, default, mass threshold, physical formula or restart format changes.

## Executed application and numerical meaning

The driver composes existing production bootstrap and WOFOST/Feddes/thermal providers with the admitted original Andelst weather bytes,20January through26April1999. There are97days,64 weather/root coupling intervals per day,227mm gross rain and a21.9mm peak daily rain. The soil is the existing explicit30cm homogeneous four-cell qualification geometry, initial head-75cm. Crop parameter tables are the existing illustrative qualification parameters; they are not calibrated Andelst field crop data, and high late LAI must not be interpreted as a field prediction. Meteorological rain is uniform within each day; storm duration is not reconstructed.

The existing rooted application uses `TX_TEMPORAL_MODEL_CERTIFICATE`. Its setting is `model_temporal_indicator_budget`, in centimetres of estimated local pressure-head error. For mode7 free drainage, the existing calibrated coefficient0.17320259355765216 multiplies the history-based head bound before comparison with this budget. It is not the full-step/two-half-step comparator of the earlier synthetic pond study. This is a separate measured accuracy/cost curve using the existing production numerical route, not equivalence between estimators. Merely changing `transaction%temporal_tolerance` would not test this route.

A fresh256-provider GNU13.3 O2 closure links the existing real HeadCalc and production providers. Only two generated diagnostic overlays print the accepted bottom and surface fluxes after successful commits. They do not change layouts, equations, branches, guards or state. Seven-day states and deterministic work match the unobserved executable exactly, excluding clocks and newly reported fields. Timing excludes compilation; process CPU includes weather reads, crop/heat, snapshots and diagnostic output. Core timing surrounds daily crop advancement and hydrology and excludes the extra daily snapshot/readout.

## Complete97-day curve

Each principal setting has three serial native observations on CPU0, with reversed order in repetition2. All repeat physical states, fluxes and work exactly. Table CPU is the median; sub-second differences on the plateau are not portable speed rankings. All differences below are against the finite2.5e-7cm run, not independent physical truth.

| Head budget (cm) | Median process CPU (s) | HeadCalc calls | Maximum daily storage difference (mm) | Maximum head difference (cm) | Total lower-boundary outflow difference (mm) |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1e-06 | 12.217939 | 1,411,228 | 0.00027624 | 0.003246 | -0.00027215 |
| 0.001 | 1.066378 | 56,502 | 0.00598758 | 0.180701 | -0.00598758 |
| 0.01 | 0.909877 | 49,007 | 0.00635726 | 0.207150 | -0.00635726 |
| 0.1 | 0.948075 | 48,602 | 0.00641262 | 0.205094 | -0.00641262 |
| 1 | 0.951929 | 48,515 | 0.00642523 | 0.204769 | -0.00642523 |

The1e-6 to1e-3 process-CPU ratio is11.46; core-CPU ratio15.88. HeadCalc calls fall24.98-fold. From1e-3 to1e-2 process CPU improves another1.17-fold, while beyond1e-2 work is nearly flat:49,007 to48,515 HeadCalc calls, only1.0% fewer. At1cm there are zero temporal rejections, but20,032 accepted internal steps remain. Other work and the fixed64-per-day coupling already limit further gain. These observations do not establish the earlier synthetic55-fold factor for a practical run.

The normal case has no drought-limited transpiration: cumulative actual and potential transpiration both84.9554mm, and soil evaporation12.9721mm. At1e-3, lower-boundary outflow is146.6949mm. Total runoff and pond evaporation are zero. The existing flux-only weather receiver explicitly rejects any ponding or runoff regime; every actual interval stays inside its accepted zero-pond/zero-runoff domain. Therefore these completed runs provide no validation of overflow/rain-intensity events. Net prescribed drain/source terms cancel; the active lower-boundary outflow is the real head-dependent SWBOTB7 free-drainage solution, not the initialized nominal forcing flux.

## Active stress discriminator, refinement and reconstruction

A separate sensitivity arm changes only the explicit Feddes thresholds to hlim3l=-100cm,hlim3h=-150cm,hlim4=-500cm. This is an artificial stress-sensitive parameter case, not a second calibrated site. All5budgets complete97days. The1e-5cm reference has38days with uptake deficit above0.0001mm/day,82.1278mm actual transpiration and2.8162mm total deficit. At1e-3/1e-2/1e-1/1cm, the stress-day count remains38. Cumulative transpiration differences from that finite finer run are0.001016/0.001005/0.001013/0.001001mm; maximum daily transpiration differences stay below0.000188mm. This genuinely activates head-dependent uptake feedback; the neutral arm alone could not assess it. Stress-arm differences are finer-run spread without independent convergence proof.

Normal-arm1e-4,1e-5,2.5e-6,1e-6 and2.5e-7refinement gives decreasing maximum storage differences against the finest run:0.0045994,0.0023101,0.0006543,0.0002762 and0mm. Corresponding maximum head differences decrease as well. The finest run is a finite comparison reference, not an exact solution or an independently proved global error bound. Spatial discretization and weather/root coupling remain fixed; no time-grid or mesh convergence claim is inferred from tolerance refinement.

At1e-3 and1cm, closing the application at day48 and reconstructing the full accepted soil/crop/weather/history continuation in the same native process reproduces every daily physical value and deterministic work count exactly. This tests application reconstruction, not an independent-process disk restart or portable restart admission.

All26final runs complete their full97-day horizons:15timed principal observations,4normal references,2midpoint reconstructions and5stress observations. Their combined native user CPU is97.32s. Independently summed gross daily rain, both evaporations, actual uptake, lower outflow and storage reproduce closure below2.2e-10mm/day; maximum97-day closure is1.46e-9mm. These are roundoff-scale bookkeeping residuals, distinct from the approximately0.006mm discretization spread in storage and outflow. Failed early diagnostic driver attempts remain archived as failures; a rejected launch during a rebuild is not a native result. No owning guard was relaxed.

## Reproduction and scope

`build_perf01_weather.py` plus `perf01_weather_main.inc` generates the executable and exact30cm legacy grid context; `--observe` selects the two read-only overlays. `run_perf01_weather.py` applies a per-process180s/512MiB native cap and saves raw success/failure streams, resource measurements and hashes. `assess_perf01_weather.py` recomputes actual fluxes, independent gross balance, reference differences, repeat identity and midpoint reconstruction. A build in progress is rejected rather than reusing a stale executable.

```bash
python benchmarks/performance/build_perf01_weather.py /tmp/weather-build --observe
python benchmarks/performance/run_perf01_weather.py --build /tmp/weather-build --output /tmp/weather-1e-3 --budget .001 --days 97
```

Use `--days 97` (separate argument), `--windows 64`, `--restart` for midpoint reconstruction and `--profile sensitive` for the explicitly altered stress thresholds. The compiler recipe reuses the retained PERF01 compiler identity; provider objects are freshly built against the correct grid. The evidence archive stores all raw final native observations and prior attempts/build streams, not compiler objects or executables. General SWP intake, annual/HRU orchestration, field crop/soil calibration, heavy clay/overflow cases and a global default change are not established by this bounded research.

Checked O0 follow-through: fresh 256-provider build completes in 35.79s. The complete 97-day 1e-3 and 1cm runs reproduce O2 physical outputs, accepted fluxes and deterministic work exactly. The O0 1e-3 midpoint reconstruction also matches. The incumbent pond-policy production owner remains qualified; production src/app/tests are unchanged. Evidence is bound by `PERF01_WEATHER_CURVE_STATUS.json` and its archive SHA256/member inventory.
