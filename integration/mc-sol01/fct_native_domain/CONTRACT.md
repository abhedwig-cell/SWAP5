# Unequal cells and production-owned surface exchange

MC-SOL01 successor to the PR1419 demonstrated domain gaps. Production dispatch
remains pending. Numerical reconstruction uses centre distances and each donor
cell's half width. Every paired interior transfer is applied once with opposite
signs. Each cell's own thickness controls storage, positivity and Courant checks.

The physical baseline determines pond-to-soil mass using the existing production
surface routine. Only a private numerical predictor replaces this transfer by
an equivalent inlet concentration and removes surface mass from predictor
scratch. The final corrected implicit solve retains the original physical pond,
rain/irrigation/runon/runoff forcing and receipts. Surface mass is never published
from the predictor. Uniform/no-surface cases delegate the admitted sink route.
Reject upward flow, negative drainage, macropore/age/aquifer domains. No guard
removal is treated as qualification. Invariants3,5,7,13,21,23 apply.

Select checked O0/O2 real eleven-to-thirteen-provider process cases first:
unequal geometry, Freundlich0.5/1/2, extracting sinks, dispersion/decay, pond
storage and surface inputs/runoff, exact OFF, unchanged surface exports,
independent cell equations and whole balance. Expected<15s. Real native
trajectory/restart and current owner qualification precede production activation.
No native year, RossFast, highest low-air or full F-CI selected at this phase.
