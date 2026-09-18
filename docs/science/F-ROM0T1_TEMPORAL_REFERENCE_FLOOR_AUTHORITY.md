# ROM-0T1 exact temporal Reference-floor authority

ROM-0T1 closes the exact observation-interval row that was preregistered in the original ROM-0 matrix.

TA1 and TA3 remain valid diagnostics, but they do not substitute for this row: those workunits use the later R1 gravity-consistent seed and TOP_PLUS/TOP_MINUS perturbations. The original ROM-0 floor explicitly requires B01/B14 under E1_NOMINAL_FLUX and E2_DRYING_FLUX from the original uniform Se=0.85 initial state.

T1 therefore runs the four exact original fixed-flux cases on the 16x10 cm grid at:
- 32 steps of 0.0016 day;
- 64 steps of 0.0008 day;
- common horizon 0.0512 day.

Both levels use the governed F-KT Reference-floor sample/candidate/commit path and the original strict fixed-flux Reference controls. No R1 seed, prescribed-head representation policy, automatic temporal subdivision or post-result retuning is allowed.

At every common time, base step j is compared with refined step 2*j for pressure head, water content, total and fixed-band storage, cumulative top/bottom exchange and terminal bottom flux. The result is measure-only; no acceptance threshold is inferred from the observed differences.

A positive result, together with ROM-0V1, completes the exact numerical Reference-floor matrix required for final ROM-0 gate reconciliation.
