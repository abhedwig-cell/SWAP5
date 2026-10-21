# PERF01 fast-side tolerance curve, 21 October 2026

Completed research, not a production default change. Baseline48a59396d7e7745cf99ad4b1003cd84c946e3e3f, production source tree d33b91286c478708e2a7db41bee4c3c0eb141c19 unchanged.

The existing file application rejects temporal tolerances above1e-3 before model execution. Those15 rejected observations are retained, not reported as numerical failures. A private observing main changes only its explicit upper input ceiling from1e-3 to1. All189 original model providers, linked object hashes, numerical algorithms and hard mass/state guards remain unchanged. Build commands, source and hashes are retained. The existing1e-3 case reproduces all five physical artifacts exactly after this change.

Eighteen complete64-window,32-cell, one-day native runs, three per tolerance, execute serially on CPU8. Reverse order in repetition2 reduces order bias. Timings exclude compile and analysis; table uses median process user CPU. Timings fluctuate, especially at very short durations. Work and physical results repeat exactly at each tolerance. Strict1e-6 and1e-4 observations from the previous study are not freshly repeated or used to claim a matched new speed ratio.

All errors are maxima at64 reporting times against the same independently converged continuous finite-volume/BDF water reference. Head includes32 nodes per time. Storage includes soil and pond. Infiltration is independently recovered from supply minus reference pond change, evaporation and runoff. These are cumulative flux errors, not instantaneous flux-rate error bounds.

| Tolerance | Median user CPU (s) | HeadCalc calls | Max head error (cm) | Max storage error (mm) | Max runoff error (mm) | Max infiltration error (mm) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.001 | 2.172044 | 52275 | 0.408943 | 0.00069765 | 0.00068448 | 0.00050851 |
| 0.003 | 0.944192 | 24513 | 0.718629 | 0.00123686 | 0.00121010 | 0.00089771 |
| 0.01 | 0.452785 | 10190 | 1.332911 | 0.00232692 | 0.00227023 | 0.00167733 |
| 0.03 | 0.189255 | 4144 | 2.392903 | 0.00425838 | 0.00413867 | 0.00300536 |
| 0.1 | 0.078440 | 1641 | 4.548125 | 0.00681304 | 0.00659201 | 0.00544201 |
| 1 | 0.029244 | 357 | 10.648193 | 0.01616028 | 0.01529959 | 0.01266916 |

From1e-3 to1e-2, median CPU falls4.80-fold and HeadCalc work5.13-fold. From1e-3 to1, median CPU falls74.27-fold and HeadCalc work146.43-fold. This is changed numerical accuracy, not an equivalent-accuracy implementation speedup. At the shortest runtimes fixed overhead becomes significant.

There is no observed hydrological error cliff through1 in this particular case. Runoff first appears in reporting window51 at every setting; this does not bound timing shifts within a window (22.5min). At1, maximum runoff error is0.01530mm with10mm gross supply; maximum head error reaches10.65cm. The numerical tolerance is not a global error percentage. There is no claim that1 is safe for dynamic roots, groundwater boundaries or regional applications.

Maximum per-window water closure residual is2.53e-13mm; solute closure3.68e-14mg/cm2. Checks recompute errors from raw CSVs, verify all raw digests, all18 completed horizons, deterministic repetitions, and exact1e-3 physical preservation. No mass criterion is relaxed. Solute trajectory accuracy is not independently established by these water-reference comparisons.

The next discriminating research should change forcing around runoff onset and drying/rewetting, and activate a head-dependent flux. Repeating stricter points in this same smooth prescribed-sink day would add little information about those risks. This result supports investigating loose tolerances; it does not select a universal default.

Evidence: `PERF01_FAST_CURVE_EVIDENCE.tar.gz`, including both initially rejected input observations and actual expanded-input native runs; `study_perf01_fast_curve.py` retains the executable build and observation recipe. The recipe requires the retained prior native provider build; no compiler binaries or objects are archived. Compiler/provider identities are inherited from the existing pond-policy evidence.
