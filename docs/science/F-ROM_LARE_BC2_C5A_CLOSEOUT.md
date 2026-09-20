# F-ROM-LARE BC2-C5A closeout

C5A completes the matched material-by-lower-boundary interaction test by applying the exact C4Z dynamic prescribed-head workload to B14. Only the constitutive material constants changed. The Reference numerical policy, histories, head factors, switching times, LARE closure, partitions and metrics were frozen before the B14 dynamic response.

The authoritative run is 35495825564 at execution head 279ab2e34fc28a81fc3507a835a20b144049fc83. R16 and R2 both pass the Reference gates and O0/O2 identity. The exact result SHA-256 is 50ac095f50f47370c6d201a18c11522f765f608ea1970eca50df0ced65a560dc.

The formal preregistered decision is **C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED**. No reduced lower-zone member R3-R12 crosses the complete frozen R2-relative dynamic-groundwater vector, and therefore no PROFILE frontier exists either.

The failure is highly specific. Every lower-zone member fails on exactly one of the eight groundwater-vector components: pooled absolute mean signed bottom-flux error. On the other seven components, all lower-zone members are no worse than R2. R2 itself has 832 flux-sign mismatches and misses the Reference reversal sequence in three of four histories.

The pooled signed-bias component is also unusual for R2. Its pooled bias magnitude is about 2.79e-6 cm/d, but the mean absolute history-specific signed bias is about 3.79e-3 cm/d. The cancellation ratio is therefore about 7.36e-4. For R8 the pooled bias is about 4.23e-6 cm/d while the mean absolute history-specific bias is about 4.99e-6 cm/d. The formal gate remains unchanged, but the decomposition shows that R2's advantage on the blocking component is dominated by cross-history cancellation.

Increasing lower-zone state does not repair the blocker. R5, R6, R8, R12 and R16 are effectively identical on both pooled signed bottom-flux bias and interval bottom-flux RMSE. This points away from a simple state-dimension explanation and toward a closure, boundary-response or integration-floor mechanism.

Placement evidence does transfer. R4 remains componentwise no worse than U4 and R8 remains componentwise no worse than U8. The cross-axis evidence therefore supports a stronger conclusion than a universal minimum number of layers: material, lower-boundary semantics, placement and closure response interact.

C5A remains a negative preregistered result. The next step is C5B, a zero-fit mechanistic reconciliation of the sole blocker. C5B may diagnose signed error by history, boundary phase, resolution and timestep, but it may not change the C5A gate or reinterpret C5A as accepted.
