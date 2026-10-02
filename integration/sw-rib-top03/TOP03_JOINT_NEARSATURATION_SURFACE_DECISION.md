# Joint near-saturation and surface-storage probe

Date: 2026-10-02
Decision: **partial numerical improvement; not qualified for production**

## Finding

The user's co-regularization hypothesis has a positive mechanism signal. A test-only combination of (1) a shared smooth transition in soil water content, its analytic storage derivative, and hydraulic conductivity across a 2 cm pressure-head band below saturation, and (2) a smooth microrelief wet-fraction curve with surface storage defined as its integral, completed selected inundation paths that the inherited piecewise/legacy combination could not complete.

At microrelief amplitude 0.05 cm, the inherited rising-stage trajectory failed at every tested refinement (1, 2, 4, and 8 substeps per forcing window). The tested 2 cm joint candidate completed the rise with 1 and 8 substeps and failed at 2 and 4. In the rise-and-recession extension, it completed only the 1-substep path; the 8-substep path failed at stage event 10 on recession, while 2 and 4 failed at event 3 during rising inundation. The outcome remains non-monotonic in timestep size.

The fully completed rise-and-recession path had 187 Newton iterations, combined soil-plus-surface ledger residual `9.73e-14 cm`, and maximum per-step soil residual `4.57e-14 cm`. O0 and O2 records were identical. This is direct conservation evidence for the test-only accepted path; it does not qualify rejection/replay, restart, or an external Ribasim transaction.

## Factorial controls

The tested 0.02 cm soil transition with either the inherited or smooth surface law completed none of the four rising paths. Smoothing the surface law alone while making the soil transition effectively zero also completed none. A 2 cm soil transition with the inherited surface provider completed none. Only the combination of the broad soil transition and smooth surface hypsometry completed some paths. Thus the observed improvement is joint and parameter-dependent; neither isolated change explains it.

The shared soil law removed the measured K jump at the inherited near-saturation cutoff and its capacity matched a finite-difference derivative oracle. The surface law defines wet fraction `f(H)` as a quintic smoothstep CDF, storage as `S(H)=integral f(H)dH`, and mean wet head as `S/f`. This makes `dS/dH=f(H)` and avoids the piecewise-linear kink at full wetting. Its width and physical calibration have not been validated against measured terrain or a field-scale model.

## Interpretation

This does not support production admission. The failed 2/4-step paths and recession failure at 8 steps show that the candidate is still timestep-sensitive. The 2 cm constitutive transition is a research width, not a recommended soil parameter. The trial harness uses a direct Richards solve with a synthetic external-stage provider; it does not exercise the production transaction lifecycle, Ribasim publication, external storage ownership, runoff, rainfall, evaporation, or restart/rollback semantics.

No production source file was changed. Generated provider copies were compiled from scratch for the experiment. The evidence therefore neither admits a new surface formulation nor changes the status of the paused TOP03 route. It shows that smoothing both the near-saturation soil law and the surface hypsometry is more promising than smoothing either side alone, while also showing that this specific law is not yet robust enough.

## Next direct question

Determine why 2 and 4 substeps fail at the third rising stage while 8 substeps can pass it, and why 8 substeps fail on recession. Record the failed residual/Jacobian states and check whether the exact failure follows the soil K law, the surface exchange law, or their composition. Then compare a calibrated transition width and a smooth K-contact relation in a dry-to-wet-to-dry test that exercises the accepted transaction path. Do not expand to broad parameter sweeps before this residual localization.

Machine-readable records and exact run scope are in `TOP03_JOINT_NEARSATURATION_SURFACE_RESULT.json`. The test-only runner is `tests/fapp/run_sw_rib_top03_joint_microrelief_probe.sh`.

