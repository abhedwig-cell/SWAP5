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

This does not support production admission. A follow-up tolerance sensitivity test set only the direct probe's absolute and relative head tolerances to `1e-9` (mass gates remain `1e-10 cm`) and extended pulse refinements to 16 and 32. The joint candidate completed at 1, 2, 4, and 8, but failed on recession at 16 and 32. Instrumentation immediately before HeadCalc rollback recorded residual maxima `1.2704e-4` and `1.7699e-5`, respectively, with head corrections `1.0969e-4` and `1.1554e-5 cm`; these exceed the configured `1e-9 cm` head tolerance by several orders of magnitude. This is a genuine nonlinear solve failure, not the strict `1e-12` convergence-gate artifact seen in the earlier failing runs. The direction is also concerning: making the forcing steps finer does not give a monotone path to acceptance.

On the completed 1/2/4/8 paths, consecutive refinement changes in maximum pressure head were `1.503`, `0.877`, and `0.513 cm`; top-transfer changes were `0.0983`, `0.0507`, and `0.0248 cm`. These decrease with refinement but remain large relative to the applied stage range. An extended `1e-9`-tolerance factorial run further separated the candidate components. Completion across refinements 1/2/4/8/16/32 was: near-legacy soil + smooth surface `T/T/T/F/F/F`; broad 2 cm soil + legacy surface `T/T/F/T/T/F`; broad 2 cm soil + smooth surface `T/T/T/T/F/F`. Their failure windows differ: the near-legacy control fails during rising inundation from refinement 8, while the joint candidate fails during recession at 16/32; broad soil + legacy surface passes 8/16 but fails at 4/32. The factorial result confirms interaction and non-monotonicity but does not uniquely localize the remaining blocker to soil or surface alone.

The follow-up also tested transition widths 0.02 and 0.2 cm at the same `1e-9` head tolerance. At 0.02 cm, the joint candidate passes refinements 1/2/4/16 and fails 8/32 during the third rising stage. At 0.2 cm, it passes 1/2/8/16/32 and fails 4 at the same rise stage. The 0.2 cm soil law with the legacy surface provider passes only 32 and fails 1/2/4/8/16, so the smooth surface law clearly changes the solve path; however, no tested width passes all six refinements. The combination has a real mechanism signal but a strong width-by-timestep interaction, without a robust candidate.

These transition widths are research settings, not calibrated soil parameters. The trial harness uses a direct Richards solve with a synthetic external-stage provider; it does not exercise the production transaction lifecycle, Ribasim publication, external storage ownership, runoff, rainfall, evaporation, or restart/rollback semantics.

No production source file was changed. Generated provider copies were compiled from scratch for the experiment, at both O0 and O2 with identical numeric records. The evidence therefore neither admits a new surface formulation nor changes the status of the paused TOP03 route. It shows a joint mechanism signal, while falsifying this tested parameterization as a timestep-robust remedy. It does not falsify every physically calibrated co-regularization law.

## Next direct question

Localize the non-monotone branch behavior across the two rising and recession failures with the already instrumented residual traces, then inspect the relevant Jacobian and constitutive derivatives to distinguish the soil K law from the surface exchange law and their composition. The refinement-16/32 recession failures show that simply increasing the temporal resolution is not a remedy. Before adding more transition widths, compare the residual/Jacobian state against the current constitutive-cut evidence and establish whether the regularized law creates a new branch-local residual gap. Any next candidate must use calibrated hydraulic/terrain support and ultimately exercise the accepted transaction path.

Machine-readable records and exact run scope are in `TOP03_JOINT_NEARSATURATION_SURFACE_RESULT.json`. The test-only runner is `tests/fapp/run_sw_rib_top03_joint_microrelief_probe.sh`.
