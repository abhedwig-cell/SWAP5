# Andelst: 130 days and precise temporal stiffness diagnosis

The experimental corrected-wall, 0.0001 cm entry-ramp route on source `0a61d40` completes 130 full original-input days and accepts source time 130.89000000000425. Its native process was explicitly interrupted by SIGINT after at least 1228 seconds; controller exit 130 is an interruption, not a natural model/solver failure. The last complete daily restart is day 130, with valid CRC; raw progress also preserves the accepted 130.888→130.890 interval. No native process remains active.

Maximum accumulated daily water residual is 3.31e-12 cm. Thermal output records the last substep accounting residual, not an independent whole-project energy qualification. The long run was stopped after diagnosing its increasing cost so it would not block canonical admission of the two complete original projects in the main campaign. No numerical tolerance was increased, no new source repair was applied after0a61d40, and no full 481-day or literal original Andelst closure is claimed.

The last accepted 0.002-day source interval takes 5346 attempts, 2677 temporal rejections, zero solver/mass rejections and 2669 accepted internal substeps. Its cost is 48012 Newton/linear solves and 16038 HeadCalc calls. This is temporal stiffness; it is not demonstrated Newton or linear stagnation.

Actual full/half comparisons, replayed from authentic day 129 and 130 scientific payloads, isolate the controlling constituent:

| Trial start | Critical node | Whole trial dt,day | Full/half head,cm | Head defect,cm | Theta defect | Matrix-water defect,cm | Macro-water defect,cm |
|---|---:|---:|---|---:|---:|---:|---:|
|129.27500000000131|68|9.7656248954e-7|-1.36201613 / -1.37548085|0.0134647164|8.90e-9|2.67e-8|2.62e-8|
|130.32200000000154|70|9.7656248954e-7|-1.39064919 / -1.40718783|0.0165386376|1.10e-8|3.30e-8|3.24e-8|

The absolute negative-pressure defect alone exceeds the existing 0.01 temporal criterion. These nodes are nearly saturated (theta≈0.4419992); the theta/head secant is about 6.6e-7. The driest nodes at -318/-420 cm contribute negligible head differences. Actual drainage exchange defect is zero, macro topology matches and volume defects are around 1e-14 cm. Thus this is near-saturated pressure conditioning rather than the dry-tail case or an observed missing process.

For each actual full/half sibling, Richards converges in 3 Newton iterations, 1 HeadCalc and 3 linear solves, with 3 backtracking attempts and zero alternative-solver calls. Native balance-rate residuals are at most 4.45e-11 cm/day in these samples (integrated defects below 3e-17 cm); macro balance residuals are below 2e-16 cm. The observation-only executable exits intentionally 87 after the genuine rejected temporal comparison. It neither qualifies an interrupted trial rollback nor proves global root nonexistence. It identifies the actual costly criterion; changing that criterion requires a justified temporal formulation, not a scalar tolerance relaxation.

The first 100 days were also compared with full original B0/B1 donor outputs. Against B1, maximum daily differences are EACT 0.00207 cm, TACT 4.92e-6 cm and total drainage 0.02624 cm; cumulative drainage difference is +0.07665 cm and maximum GWL difference 7.12 cm. The native entry ramp differs from the donor's sharp entry, so this is descriptive evidence, not scientific equivalence. The original zero-width entry law remains independently unresolved, as documented in the sealed sharp-entry evidence.

ANDELST130_RESULT.json and ANDELST130_EVIDENCE.tar.xz contain the complete 130-day raw execution/censor record, source-bound executable/build, actual day 129/130 restart states, both observation replays, source patch, original B0/B1 comparison data and the observation-only source. The existing tests/dataqual15/verify_andelst_diagnostics.py validates the manifests, executable hashes, checkpoint CRCs/clocks, identical scientific replay payloads, explicit interruption and actual solve/temporal records. No production or canonical Andelst admission is asserted.
