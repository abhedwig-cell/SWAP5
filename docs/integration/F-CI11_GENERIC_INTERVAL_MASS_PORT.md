# F-CI11 generic physical interval and mass port

F-CI11 separates physical execution boundaries from calendar boundaries in the controlled B1.10 source port. `b1_10_interval_seam_t` supplies `[t0,t1]`; `TimeControl` clips numerical `dt` to that boundary but leaves day-start/day-end processing on the real calendar boundary. The canonical caller prepares an interval with SWAP task 22 and then executes task 2.

Unrounded trial fluxes are accumulated through the explicit worker/job-local `b1_10_trial_mass_t` passed into `MOD_integral`. Legacy standalone calls omit both optional objects and retain their existing behavior.

Qualification covers day-start, non-midnight and cross-day intervals for the Hupsel profile, with hard mass conservation and O0/O2 identity. Full-versus-two-half state differences are intentionally retained as future temporal-error information; they are not judged as an error in this work unit.
