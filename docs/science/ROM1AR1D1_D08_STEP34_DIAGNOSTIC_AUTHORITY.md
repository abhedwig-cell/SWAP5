# ROM-1A-R1-D1 D08 step34 failure diagnostic authority

The ROM-1A-R1 successor library progressed through the discovery set to D08. D08
step 33, the first BOTTOM_HEAD_RISE interval after 16 FALL and 16 TOP_PLUS steps,
was accepted normally. The next identical mode-5 interval failed the original strict
Reference attempt. The existing strict-first fallback guard then rejected the failure
because it was not classified as RETRY_TOTAL_ONLY.

D1 is classification only.

The exact D08 predecessor is rebuilt through the already qualified research Reference
authorities: ROM1AD2 for mode-2 intervals and ROM-0R-R3D4 for mode-5 intervals. Those
authorities may be used only for predecessor steps 1-33. Step 34 is then attempted
under the original strict controls with **no fallback**.

The failed interval must not mutate committed state. A direct same-state Reference
solve is used only to inspect the final convergence workspace and classify the retry
using the existing PUB-P2E11D criterion split. The prospective representation bound
is computed from the accepted predecessor before the failed solve, but is not applied
as a solver tolerance.

D1 may identify the blocker. It cannot choose a remedy.
