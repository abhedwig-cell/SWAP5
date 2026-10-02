# PPA-WU05-A27-ABC01-DEP01 preregistration — RFM live state-layout admission

Date: 2026-10-02  
Status: PREREGISTERED_SHARED_BACKEND_DEPENDENCY  
Observed A27 head: `980e1279407b0caedfc4a4dd6ce0a00a9daa6229`  
Canonical dependency baseline: `800f6a9b429ed2a392e4c3778951bb92eca042aa`

## Trigger

ABC01 production run 36990063203 successfully executed the harness, but comparator C was rejected in all 32 cases before any transaction attempt:

- status `KERNEL_STATUS_NOT_ADMITTED = 101`;
- fail step 1;
- transaction calls 0;
- attempts 0;
- nonlinear iterations 0.

The RFM configuration itself passed `rfm_runtime_configuration_t%valid()` and `configure_rfm_runtime()` in the prospective harness.

Source reconciliation identifies a shared live-execution admission defect.

`fmr_b110_rfm_state_t` is declared as an extension of `fmr_b110_physical_state_t`.  
`prepare_snow_outer_event()` calls `state_matches_numerical_continuation_layout()` before kernel execution admission. That function has exact guards for several specialized carriers and then an exact

`type is (fmr_b110_physical_state_t)`

base guard. It has no `fmr_b110_rfm_state_t` guard. An RFM carrier therefore falls into `class default`, leaves `state_profile_admitted=.false.`, and is subsequently rejected by `fmr_serialized_execution_admitted()`.

This is inconsistent with the later A26 live production closeout, which admits the accepted-state-frozen RFM/Reference split. The older source comment that A20 carrier/checkpoint semantics were admitted separately does not establish later A26 live reachability.

## Authorized repair

Add one explicit `type is (fmr_b110_rfm_state_t)` branch to `state_matches_numerical_continuation_layout()`, immediately before the base physical-state branch.

Its predicate must be exactly the same no-continuation/no-fixed-weir/no-evaporation predicate as the base physical carrier. Do **not**:
- change RFM state contents;
- widen numerical continuation compatibility;
- change storage accounting;
- change surface forcing, preferential routing or matrix source semantics;
- replace the exact guards with a broad parent `class is` guard;
- modify any A27 benchmark parameter or E0/E1 threshold.

## Prospective gates

1. Current backend compile gate passes O0/O2.
2. A26 live trial preparer and actual Richards binding preservation pass.
3. Existing standard macropore A8 production trial remains admitted.
4. ABC01 C no longer fails with admission rejection before the first transaction.
5. If C then fails later in transaction/solver/physics, retain that as a separate result. Do not extend this repair to make the benchmark pass.
6. A/B behavior must remain unchanged modulo timing noise.

This branch-local repair is not canonical admission. If qualified, record it as a shared production-backend repair candidate for central SWAP5 regie.
