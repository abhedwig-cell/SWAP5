# Experimental dry-pressure temporal assessment

Canonical baseline3170aa1 retains the checked original-input run. At original
day927 its time controller repeatedly rejects full/half trials because the
unscaled unsaturated pressure defect dominates: at node2, h is about-7789cm,
dt2.18e-6day, pressure difference7.85e-5cm and total equivalent water-storage
difference4.86e-10cm. Larger trials reject pressure differences of0.001–0.005cm
despite storage differences below4e-8cm. Actual solver retries remain enforced.
This is a measured numerical cost barrier, not missing groundwater physics.

The isolated candidate uses abs(h_full-h_half)/max(1cm,abs(h_full),abs(h_half))
as its unsaturated pressure defect, only for the existing experimental
time-varying groundwater plus Boesten route. Saturated algebraic heads remain
excluded as before. The absolute water-storage, every Darcy face exchange,
ponding, groundwater/drainage and Boesten SPEV/SAEV budgets are unchanged.
Temporal budget1e-4, nonlinear tolerances, original MAXIT/MAXBACKTR/DTMIN/DTMAX,
water-mass1e-10 and rollback controls are unchanged. Other routes retain their
old head defect. This is an explicit numerical-policy correction, not identical
source4.3.1 adaptive stepping and not a production promotion.

Qualification must include actual gfortran O0/O2, original day1 execution,
same-build disk restart, the distinct actual/potential management window,
existing groundwater/default/oxygen preservation, comparison with4.3.1 and a
targeted tighter-budget numerical refinement at the measured dry event. An
old-state diagnostic rebinding can diagnose cost/accuracy but cannot qualify
restart or substitute for the new source's complete day1 history.
