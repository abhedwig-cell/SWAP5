# PPA-WU05-A27-ABC01-DEP01 current-canonical reconciliation addendum

Date: 2026-10-02  
Status: PREREGISTERED_PRESERVATION_REPAIR

After DEP01 qualification work started, canonical advanced from `800f6a9b429ed2a392e4c3778951bb92eca042aa` to `0c18a9fffa14bce9e25a4cf773420c5824c0c819`.

The canonical delta modifies the shared serialized Reference backend and Reference temporal-indicator code for LOW03. A27 therefore reconciled onto the new canonical backend rather than retaining the older complete file.

The current canonical backend contains a preservation regression in the RFM temporal branch: the previously qualified quantitative RFM full/half metric

- maximum pressure-head difference;
- ponding and groundwater-level difference;
- layer water-storage difference;
- MB-storage difference;
- endpoint-storage difference

has been replaced by exact `base_physical_states_identical(...)` plus `rfm%same_values(...)`.

The still-current A26 backend preservation gate explicitly requires the quantitative MB and endpoint metrics and rejects the exact-identity form. The gate therefore fails on current canonical before compilation with `RFM temporal MB metric missing`.

## Authorized reconciliation repair

Restore the previously qualified quantitative RFM temporal block byte-for-semantics from the pre-`0c18` A27 postimage. Do not alter:
- current canonical LOW03 bottom-boundary code;
- the new Reference temporal-indicator implementation;
- standard macropore temporal metrics;
- transaction tolerances;
- RFM physics or structural parameters.

Keep the separately preregistered DEP01 explicit `fmr_b110_rfm_state_t` layout-admission case.

## Gates

The reconciled postimage must pass:
1. A26 live trial preparer;
2. A26 current serialized backend compile/static preservation assertions;
3. A8 real-Richards standard-macropore preservation.

ABC01 need not be repeated merely to establish this current-canonical preservation repair. Its earlier run `36991919530` remains behavioral evidence for the DEP01 live-layout repair because the later reconciliation repair restores the prior RFM temporal metric rather than changing RFM physical composition.
