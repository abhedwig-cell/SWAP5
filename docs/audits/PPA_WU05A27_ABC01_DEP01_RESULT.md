# PPA-WU05-A27-ABC01-DEP01 result — RFM live state-layout admission and preservation repair

Date: 2026-10-02  
Status: QUALIFIED_SHARED_BACKEND_REPAIR_CANDIDATE  
Canonical admission: NO

## Trigger

The first executable ABC01 production screen exposed that comparator C was rejected with `KERNEL_STATUS_NOT_ADMITTED` before any transaction attempt. The dedicated `fmr_b110_rfm_state_t` extends `fmr_b110_physical_state_t`, but `state_matches_numerical_continuation_layout()` had no exact RFM type branch. Because the base branch is `type is`, not `class is`, the RFM carrier fell into `class default`.

The repair adds one explicit RFM carrier case with the same no-continuation/no-fixed-weir/no-evaporation predicate as the ordinary base carrier. It does not widen RFM physics, storage, surface forcing or numerical-continuation scope.

## Behavioral evidence

Run `36991919530` on postimage `41daf2c62f9c74a0310a1443f1cf92000c7565d3` demonstrates that after the repair:

- C reaches production execution rather than admission rejection;
- all 32 C records have zero admission rejections;
- 8 C cases complete;
- the remaining 24 fail later with solver rejections, which is a separate runtime-stability result.

The same run produced the ABC01 evidence artifact `11220260500`, digest `sha256:4d48cce68c030c09658dc5465cc9ba13ab0f7de521601d63ea6236cfb986ab2e`.

## Current-canonical reconciliation

Canonical subsequently advanced through LOW03 work. Reconciliation onto `0c18a9fffa14bce9e25a4cf773420c5824c0c819` exposed a second preservation regression: current canonical had reverted the previously qualified quantitative RFM full/half temporal metric to exact state identity, while the current A26 preservation gate still requires pressure, layer-storage, MB-storage and endpoint-storage differences.

A27 restored that previously qualified RFM temporal block unchanged while retaining all newer LOW03 and Reference temporal-indicator code. Current canonical later advanced to `f7c261a7f059c91d4a0aac16e378351f293aa080` by documentation only, so the relevant code baseline remains unchanged.

Final preservation run `36993219391` on postimage `a806d3f0d1cc9d3ff65a1c3f437c1ea005309b18` passed:

- A26 live trial preparer;
- current serialized backend compile/static A26 preservation gate;
- A8 real-Richards standard macropore production preservation.

## Decision

DEP01 is qualified as a shared backend repair candidate on the A27 branch.

It is **not** canonically admitted by this record. Central SWAP5 integration must decide whether to admit the explicit RFM carrier case and restoration of the already-qualified quantitative RFM temporal metric to canonical.

No ABC01 parameter, RFM physics parameter or hydrologic threshold was changed to obtain these passes.
