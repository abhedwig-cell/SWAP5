# MC-NUT01 reactive daily production contract

Proposed on canonical eb03024d99ef9256335eb6e2f3f74bccce8145f0; selective donor
PR #1117 at b6b894513fcdcf66e94824742c129616ddd7aed1. Preserve all accepted
water, crop, matrix and mineral profiles. One coherent work unit and one PR.

One private reactive configuration wraps the existing mineral owner; it never
holds a second OM or mineral inventory, clock or revision. The old four-provider
mineral process feedback closure remains available. A new budget-checked transfer
seam in that owner commits organic and mineral changes atomically. The existing
runtime daily carrier is factored into a read-only validated aggregation interface;
its original consume entry point retains its exact off-profile results.

Daily source order: reference organic rates times literal temperature/moisture
factors; FOM/Bio/Hum turnover; carbon dissimilation; respiration reduction of
denitrification; simultaneous analytical NH4 transport/production/nitrification;
NO3 transport/nitrification input/denitrification; one whole-N owner commit. The
explicit corrected-reference decision is MC-NUT01-R1: fix the duplicated Bio term
in the historical Nminer FOM coefficient before qualifying production. Preserve
both original defect witness and exact one-line B1 transform. The archive/global
B1 manifest is immutable. Organic N is always derived from stores and immutable
fractions. Denitrification is the external gaseous-N loss; nitrification is an
internal transfer, never an external sink. Carbon dissimilation drives the stated
source denitrification factor; this does not admit a general soil-carbon balance.

Explicit disabled mode delegates the admitted mineral operation exactly. Enabled
profile has prescribed bounded temperature, organic reference rates, carbon/N
fractions and WFPS response parameters. No heat-state/default-bootstrap coupling,
humus exponential-calendar option, crop N demand or uptake, fixation change,
amendments or residue events. Existing full-column, one-day, top-zero and no
opposing-boundary-flow restrictions remain. New configuration is included in
opaque and CRC disk restart; wrong identity/configuration or invalid payload
publishes neither water nor N. Actual Richards temporal history is retained.

Finite domains: temperature/reference -20..60 C; reference rates0..1/day;
WFPScrit0.05..0.95, WFPScrit2 0..0.95, water saturation0.01..1; carbon fractions
0..1, half-respiration0..1000 kgC/m2. Enabled organic turnover excludes singular
eigenvalue/resonance and zero determinant profiles using the source fail-closed
checks. Invalid/insufficient-N candidates reject atomically, never clip away an
unbooked organic or mineral transfer. Water hard closure1e-10cm and whole-N
1e-12 relative accounting remain unchanged. Ordinary accepted states must retain
bit-identical disabled-mode behavior and restart continuation.

Qualification starts with the real small process closure and full literal source
oracles (orgmatn, rateconstants, watern). Then actual two-day water/reaction
composition, off-mode equivalence, mineralisation and immobilisation, gaseous
loss, rollback/retry, malformed carriers, opaque and fresh-process disk restart
and corrupted payloads. Expected process build below5s, physical build around
120s with the established235-provider closure plus new pure modules; native cost
UNKNOWN initially. Stable admission selects one complete local moving gate,
expected1400..1900s, because the shared mineral owner/carrier and admission guards
change. Owning clause: execution-protocol local contract feedback and four-level
stable admission boundary. No expensive test during routine feedback; no long
highest-low-air stress (NOT_SELECTED_POLICY). Retain failed/censored results.
