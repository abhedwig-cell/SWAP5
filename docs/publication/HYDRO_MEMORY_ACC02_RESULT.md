# HYDRO-MEMORY ACC02 result

**Decision:** `ACC02_GOVERNANCE_QUALIFIED`

The HYDRO-MEMORY Stage 0 groundwater-interface accuracy allocation is now frozen and executable.

The parent application requirement remains (H_{app}=0.4) cm. Temporal and coupling-interface convergence each receive 25%:

- temporal budget: **0.1 cm = 0.001 m**;
- interface head-residual tolerance: **0.1 cm = 0.001 m**;
- total allocated fraction: **0.50**;
- deliberately unallocated numerical reserve: **0.50**.

GitHub Actions run **35430654294** passed with O0/O2 identity. The canonical groundwater accuracy binding produced the 0.001 m policy with separate application, temporal and interface provenance identities. A residual of magnitude 0.001 m is accepted; a residual above that bound is rejected.

No production or reference source changed.

This closes only the governance/binding layer. Stage 0 remains blocked until a root-active coupled predictor/corrector trajectory demonstrates that the governed interface tolerance can be met without relaxing the already qualified 0.1 cm temporal budget or hard mass gate.
