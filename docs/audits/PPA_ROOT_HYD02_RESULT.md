# PPA-ROOT-HYD02 result

**Decision:** `QUALIFIED_RESTRICTED_PRESCRIBED_ROOT_TANGENT_COVERAGE`

The accepted-trajectory tangent can now cover the already admitted prescribed B1.10 root-sink carrier without claiming support for arbitrary or state-dependent root uptake.

The physical root-extraction sink remains fully present in the Richards solve. The new directional statement is narrower: for the concrete `b110_root_sink_provider_t`, the prescribed vector does not change with the groundwater coupling control during a trial, so its direct derivative is exactly zero.

Qualification run **35438255509**, job **105884524353**, passed at source head `55451eec38a877412e3eef59c3c103a33156ceee`.

Observed for the frozen root-active equivalence fixture:

- equilibrium reference flux: `-0.1626392064213146 cm d-1`;
- accepted substeps: 2;
- retries: 4;
- ROOT versus GENERIC physical head difference: 0;
- ROOT versus GENERIC final pressure-head direction difference: 0;
- ROOT versus GENERIC integrated bottom-exchange derivative difference: 0;
- ROOT versus GENERIC MODFLOW bottom-face tangent difference: 0.

The active-root MODFLOW tangent endpoint is authoritative only because explicit prescribed-root coverage is carried through each accepted step, the trajectory composer and publication result. All other root-sink provider types remain fail-closed.

Preservation also passed for F-KT21 accepted-trajectory composition, F-GC31 active-drainage tangent behavior and PPA-ROOT-HYD01 temporal-certificate behavior. O0 and O2 outputs were identical.

No finite-difference runtime fallback, extra nonlinear solve, root physics, temporal budget, mass tolerance, solver tolerance or retry policy was introduced.

This workunit does not yet qualify a live root-active SWAP-MODFLOW application. The next gate is ACC02-F1: reuse the canonical F-GC44 real-SWAP + live-MODFLOW6 end-to-end fixture, activate only the prescribed root sink, and enforce the already governed HYDRO-MEMORY temporal and interface accuracy policies.
