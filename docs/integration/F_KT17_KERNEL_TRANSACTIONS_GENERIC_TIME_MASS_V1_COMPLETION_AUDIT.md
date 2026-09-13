# F-KT17 — Kernel, Transactions, Generic Time & Mass v1 Completion Audit

## Decision

`KERNEL_TRANSACTIONS_GENERIC_TIME_MASS_V1_FINAL_CLOSURE_GAPS_IDENTIFIED`

100% completion is **not** currently defensible on the frozen SWAP5-v1 denominator.

This audit does not change the denominator and does not invent a replacement 99.x percentage. F-RG01C previously records D01 as 8/8 and 100.0%. F-KT17 finds one hard qualification blocker that prevents that raw denominator score from being carried forward as a qualified 100% claim.

Baseline audited:

- `integration/f-ci-canonical@c19a04721a05c6a00ba264e7477969807dcb258f`
- tree `5342833575484452b34606f8854ff3f5a542e452`
- `F-CI56: finalize predictor-corrector canonical admission closeout`

## Frozen scope

The audited kernel contract is conceptually:

`advance_interval(parameters, committed_state, forcing, numerical_config, t0, t1) -> result + candidate_state + diagnostics`

The kernel remains file-free, path-free, parser-free, topology-free and scheduler-free. Parameters, committed state, forcing, numerical configuration, candidate state, result, diagnostics and solver workspace/scratch are separately represented. Generic time is expressed through numerical `[t0,t1]` intervals rather than a day/month/year execution unit.

RossFast, energy balance, deep-vadose, future physics, future solver productionization, 100k-column throughput proof, Status AA and arbitrary MODFLOW application classes remain outside this frozen closure.

## What passed

Criteria 1–7 and 9–17 pass on the audited current canonical source and authority chain. In particular:

- standalone, Serialized MultiSWAP, current restricted parallel composition and coupling use the same canonical kernel semantics;
- rejected trials do not mutate committed state and retries originate from checkpoint/committed physical state;
- candidate state becomes committed only through explicit commit;
- rollback discards trial/candidate state and requires no reverse physics;
- generic time and variable coupling windows are preserved;
- F-KT15/F-KT15R solver-service composition remains preserved on the exact current canonical dependency surface;
- F-KT16 remains the authority for state/persistence/restart and is compatible with kernel transaction ownership;
- F-VQ64 independently verifies current predictor/corrector rollback, retry-from-origin, non-calendar windows, exact accepted exchange ledger and `q_groundwater = -q_swap`;
- result transport exposes mass completeness, missing-contribution mask, storage terms, flux totals and residual. The mass defect found here is therefore an enforcement defect, not hidden accounting information.

The exact-head current-canonical preservation run `34745966892`, job `103694059000`, is green and includes the F-KT15 solver-service, typed groundwater interface and restricted-parallel dependency preservation gates.

## Blocking finding F-KT17-G01

Classification: `MASS_GAP`, secondary `IMPLEMENTATION_GAP`.

The generic transaction path is fail-open for explicitly incomplete mass accounting.

On `c19a04721a05c6a00ba264e7477969807dcb258f`:

1. `src/transaction/mod_transaction_reference.f90` computes the trial mass acceptance from the residual tolerance. `mass_accounting_complete` and the missing-contribution mask are retained in the result but are not required for `TX_STATUS_ACCEPTED`.
2. `src/runtime/mod_canonical_interval_runtime.f90` moves an accepted trial state into the private working state. If accounting is incomplete it sets aggregate `mass.complete=.false.` and carries the missing mask, but this does not prevent the requested interval from becoming `completed=.true.`.
3. `src/kernel/mod_kernel_transactions.f90` materializes a candidate for every completed runtime result. `kernel_commit_candidate` validates candidate validity, revision/provenance and time consistency, but it does not require complete mass accounting before committing the candidate.

Therefore a physically accepted and explicitly committed interval can exist with `result.mass.complete=false` if the residual of the known subset lies within tolerance. That violates the frozen hard rule that every accepted interval must have complete auditable mass accounting and violates architecture invariant 13. Residual closure of a known subset is not proof of total water conservation when contributions are explicitly marked missing.

This is enough to forbid 100% completion. It does not require evidence that a current production physics model routinely emits incomplete accounting. The generic production transaction contract itself permits the forbidden accepted state.

## Current-canonical preservation classification

The F-CI56 predictor/corrector addition is `PRESERVATION_PROVEN`: its transaction and interface-mass semantics have independent F-VQ64 evidence and current canonical admission evidence. The final F-CI56 closeout from the already admitted source is `IRRELEVANT_TO_KERNEL_SCOPE` as a material kernel change and is covered by the exact-head preservation gate.

The mass gap is not a predictor/corrector double-counting defect. Current predictor/corrector exchange conservation is qualified. The blocker is the more general transaction admission rule that can accept an incomplete ledger.

## Minimal closure

Only one bounded remediation is required before re-running final completion qualification:

- in the existing transaction acceptance gate, require `mass_accounting_complete=true`;
- require a zero missing-contribution mask;
- retain the existing residual-tolerance test as an additional condition;
- classify incomplete/missing accounting as a mass rejection so the existing retry/rollback path is used;
- add regression coverage for zero-residual-but-incomplete accounting, repeated retry immutability, normal complete-ledger acceptance, fallback behavior and preservation of restart/MultiSWAP/coupling transaction semantics.

A kernel API redesign is not justified by the evidence and is outside the minimal closure principle unless the remediation itself proves one unavoidable.

## Invariant audit

PASS: 1, 2, 3, 5, 7, 8, 9, 10, 11, 15, 16, 23, 24, 25, 26, 28, 29, 30.

FAIL: 13, because incomplete mass accounting can currently pass the generic acceptance/commit path.

Invariant 30 passes as a process requirement because current-canonical changes and preservation were explicitly audited; the architecture as a whole is nevertheless not fully conformant while invariant 13 remains open.

## Authority notes

Key current authorities include:

- F-RG01 `09ef05c60c5e45af218980001c8ad8ec30da2e9e`
- F-RG01A `4553204468695553cf69a48d1c97598c471156d6`
- F-RG01C fixed-denominator authority `971e732551abad86acccfd5f01811d855e51e939`
- F-MQ12/F-KT01 admission `e7248ef1813acf942fcae0f8d66c1b4409af4914`
- F-MQ20/F-KT05 admission `06b45a139f649dbd92437d922fadfea9a00d660a`
- F-MQ22/F-KT06 admission `893c24732acabe4de4d1a0cd2835ab77cd3c253e`
- F-KT09 `0ffd4e304ac5cf66fe7738cac3a1c07308d6c687`
- F-KT10 `d8e2ac874fc395d8831e995714af553cee47b08b`
- F-KT11 `00a9924890d407758404413f99c982bb591b5367`
- F-KT12 `a7fad31e392ab5b43d4db3eea5e18687e8d36bc6`
- F-KT13 `66c2d682330c9637c6f0cbfbaca2a3ef755346ba`
- F-KT14 owner history `2f7995df362c65916671278a5552ed9976ed39b3`; current authority comes from later exact-head admission/preservation rather than that owner's pending-CI status
- F-KT15 `48336cb7f14e9246b03c23e549fe7354a93f9e6b`
- F-KT15R authority `1b3d8ba6cc70d74a124f20f01f0c47a102763ae0`, canonical merge `9465be74c01fe6455466e5ba7f62a761986ad450`
- F-KT16 `37a91f16078badaa675235f1230d225a21c9e010`, tree `3ddacee88898872ec4541b721b74cce63117bbed`
- F-MR42-R1 `c70b3c7ad8267e7eb77b98cf142fa66e7e506cee`; its red exact-R1 workflow is a moving-canonical fail-closed event, not a capability failure
- F-VQ64 `466119889a3f09b33ede638322e897bded2472a3`
- F-CI56/current canonical `c19a04721a05c6a00ba264e7477969807dcb258f`

For superseded early F-KT steps without a live standalone branch, this audit deliberately does not invent identities. Their provenance is carried by F-RG01C and downstream source-bound qualification/admission evidence.

## Exit state

Production source changed by F-KT17: **NO**.

Frozen denominator changed: **NO**.

100% qualified: **NO**.

Persisted decision: `KERNEL_TRANSACTIONS_GENERIC_TIME_MASS_V1_FINAL_CLOSURE_GAPS_IDENTIFIED`.

Recommended next workunit, live namespace checked free on 2026-09-13: **F-KT18**, restricted to fail-closed mass-completeness admission and its qualification/preservation chain.
