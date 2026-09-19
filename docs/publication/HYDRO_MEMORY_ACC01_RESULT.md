# HYDRO-MEMORY ACC01 result

**Decision:** `ACC01_GOVERNANCE_QUALIFIED`

The Stage 0 numerical groundwater-head accuracy policy is now frozen and executable through the canonical application-accuracy contract.

Governed values:

- (H_{app}=0.4\,\mathrm{cm});
- (A_{temporal}=0.25);
- (H_{temporal}=0.1\,\mathrm{cm}).

The application requirement is 1% of the smallest preregistered groundwater-depth treatment spacing, 40 cm. The temporal share was fixed at 25% before feasibility execution. Neither value is inferred from SWAP timestep behaviour, solver tolerances, temporal-indicator magnitude, calibration error or a physical-impact threshold.

GitHub Actions run **35430102367** passed on head `5cbadaba8f03f1d5de872d03c5a2dfe8912cd0a3`.

Evidence:

- governance-source SHA-256 verified;
- pinned F-GC13 validator: `ACCEPT`;
- F-GC13 mapping to (0.4,0.25,0.1): PASS;
- canonical F-GC14 typed adapter binding: PASS;
- O0/O2 output identity: PASS;
- no production or reference source mutation.

This closes governance only. Stage 0 is not yet authorized. The next gate is an executable state-changing root-active temporal-feasibility trial under the governed 0.1 cm budget.
