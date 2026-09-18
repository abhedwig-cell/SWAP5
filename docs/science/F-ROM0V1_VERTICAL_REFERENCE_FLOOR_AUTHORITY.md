# ROM-0V1 vertical-resolution Reference-floor authority

ROM-0V1 executes the last required numerical-floor comparison already fixed in the original ROM-0 preregistration.

The physical cases are not selected from later results:

- B01 / E1_NOMINAL_FLUX: q_top = 0.01 K0, q_bottom = -0.004 K0;
- B14 / E2_DRYING_FLUX: q_top = -0.005 K0, q_bottom = -0.019 K0.

Both use the original uniform Se=0.85 initial state, zero sources/sinks, the same 160 cm profile and the retained refined temporal resolution of 0.0008 day. The original E1/E2 horizon is preserved at 0.0512 day, giving 64 common endpoints.

The numerical policy is prospectively fixed before each sample from the accepted base state using the already qualified representation-bounded total criterion. The local balance, head, ponding, nonlinear-iteration, backtracking and hard transaction mass controls remain fixed.

The vertical comparison itself is measure-only. No observed 16-vs-32 difference is converted into an admission threshold in this workunit.

For state-profile comparison, two 5-cm fine cells are mapped to each 10-cm coarse cell:
- theta is averaged, which is exactly storage-conservative because the fine cells have equal thickness;
- pressure head is averaged, equivalent to linear interpolation to the coarse cell centre on the nested uniform grids.

Differences are measured at every common committed endpoint and summarized by maxima over the trajectory plus final-time values. Total, 0-40 cm and 40-160 cm storage are compared directly in physical units. Bottom exchange is compared cumulatively from the qualified F-KT sample result. Top exchange is prescribed by the identical fixed-flux input and is therefore recorded as an input identity, not used as a solver-derived discrepancy.

A positive result means the required vertical Reference floor is measured. ROM-1A still requires a separate final Q0 close-gate reconciliation.
