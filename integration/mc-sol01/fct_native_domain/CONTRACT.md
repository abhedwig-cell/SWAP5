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
Interior and lower-boundary signed flow use the actual donor cell. Reject
upward top flow (soil-to-pond return), negative drainage and macropore/age/aquifer domains. No guard
removal is treated as qualification. Invariants3,5,7,13,21,23 apply.

Select checked O0/O2 real eleven-to-thirteen-provider process cases first:
unequal geometry, Freundlich0.5/1/2, extracting sinks, dispersion/decay, pond
storage and surface inputs/runoff, exact OFF, unchanged surface exports,
independent cell equations and whole balance. Expected<15s. Real native
trajectory/restart and current owner qualification precede production activation.
No native year, RossFast, highest low-air or full F-CI selected at this phase.

Native composition phase: explicit generated native crop/pond caller, original
SWP hydraulic/chemical import, modified FREXP/TSCF and a constructed four-window
0.4day active-crop forcing.41/60node unequal/uniform grids, Freundlich0.5/1/2,
TSCF0/1 at O0/O2; full/split/fresh native process, exact binary endpoints and
continued budgets. Both owners select the already implemented analytical
empty-pool limit. Numerical policy has a distinct water parameter identity.
Select144 signed/interior-flow material/pond process oracles before the native
matrix. Measured first native case8.62s O0 and4.91s O2 including restart;
expected complete24case matrix<200s. Per-invocation ceiling180s. Original
153 reader providers may be reused only with matched compiler route, flags and
all materialized source bytes. All201 scientific/application providers compile
fresh. Current composed owner/source controls selected after canonical source
reconciliation, expected<180s from prior measured validation; no full F-CI.
Retain all failed/incomplete rounds; short positive-pond prefixes qualify only
their actual4e-6day span, not the complete0.4day transition.
