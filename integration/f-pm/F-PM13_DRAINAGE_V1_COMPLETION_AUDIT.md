# F-PM13 — Drainage-v1 100% Completion & Current-Canonical Preservation Audit

Status: `DRAINAGE_V1_FINAL_CLOSURE_GAPS_IDENTIFIED`

This is a frozen-scope completion audit. It changes no production physics, no reference source, no drainage denominator and no existing canonical authority.

## Exact audit base

- Repository: `abhedwig-cell/SWAP5`
- Audit branch: `work/f-pm13-drainage-v1-completion-audit`
- Current canonical: `integration/f-ci-canonical@379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`
- Current canonical tree: `556221f62b4fde616981499eba68ef5460f5d83c`
- F-RG01 post-RB1 governance authority: `regie/f-rg01-post-rb1-program-rebaseline@09ef05c60c5e45af218980001c8ad8ec30da2e9e`
- F-PM08 readiness closeout: `3ce245e3cac068268bdff2f0af0fdcdf022c82aa`

F-RG01 requires the production authority chain `source owner -> independent qualification -> F-CI admission -> postimage preservation`. File presence or a qualified scientific child branch is not enough for production-completion credit.

## Frozen drainage-v1 denominator

F-PM13 retains the complete requested denominator:

1. restricted single-level linear-resistance drainage;
2. restricted spatial distribution / positive single-level DIVDRA;
3. DRAMET=1 tabulated drainage response;
4. DRAMET=2 Hooghoudt response;
5. DRAMET=2 Ernst response;
6. empirical interflow drainage-side response;
7. multi-level drainage aggregation;
8. restricted fixed-weir transactional surface-water runtime.

No item is removed or reclassified as future scope merely to obtain 100%.

The historical F-PM08 contract is also binding: legacy drainage is not one migration object, exchange-law physics, spatial distribution and surface-water storage/control are separate responsibilities, process code may not access HeadCalc internals or mutate the solver Jacobian, and hard mass conservation has no configurable tolerance.

## Variant disposition

| Frozen variant | Scientific / structural authority | Runtime + canonical evidence | F-PM13 disposition |
| --- | --- | --- | --- |
| Linear | F-VQ44: 1200 exact equivalence cases, exact analytic derivative agreement, O0/O2 identity | F-VQ44 explicitly records `runtime_qualified=false` and `canonical_admission_qualified=false` | `FAIL` |
| Spatial / DIVDRA | F-CI32 source admission; F-CI33 binding; F-CI36 active runtime | current canonical process blob `1f538174...`; runtime blob `9a384658...` | `PASS_CURRENT_CANONICAL` for the restricted single-level positive scope |
| Tabulated DRAMET=1 | F-VQ40 qualified remediated response and explicit fail-closed degenerate route | F-VQ40 explicitly excludes runtime composition and canonical admission | `FAIL` |
| Hooghoudt DRAMET=2 | F-VQ38 qualified response family | F-VQ38 explicitly excludes runtime/source-sink binding, fully implicit Jacobian chain and canonical admission | `FAIL` |
| Ernst DRAMET=2 | F-VQ38 qualified response family | same explicit holds as Hooghoudt | `FAIL` |
| Empirical interflow | F-VQ42 qualified drainage-side response, sensitivity and singularity semantics | `runtime_qualified=false`, `canonical_admission_qualified=false` | `FAIL` |
| Multi-level aggregation | F-VQ43 exact legacy-order aggregation and conservative sensitivity composition | phase explicitly says `NOT_RUNTIME_OR_CANONICAL_ADMISSION` | `FAIL` |
| Restricted fixed weir | F-VQ59 independent transaction/mass/restart/MultiSWAP qualification; F-CI52/F-CI52P admission/preservation | current canonical process blob `16da4f6e...`; runtime blob `f81229c2...` | `PASS_CURRENT_CANONICAL` |

The scientific work is therefore substantially further than the production-completion state. That distinction is decisive here.

## Why 100% is not admissible

Six frozen response variants have independent scientific qualification but lack the production execution and authority layers that this audit explicitly requires. Their current authorities do not permit inference from scientific equivalence to runtime correctness or canonical admission.

The missing proof is not merely documentation. For those variants there is no admitted current-canonical path proving, end to end:

- trial-local computation and no committed mutation on reject;
- exactly-once drainage mass booking on accept;
- rollback/retry behavior and hard water-balance closure;
- restart semantics, including an explicit no-additional-state declaration where the response is stateless;
- MultiSWAP column isolation and order independence;
- per-route diagnostics and fail-closed unsupported combinations;
- production isolation from HeadCalc internals;
- current-canonical source/runtime admission and postimage preservation.

F-PM13 therefore cannot emit `QUALIFIED_DRAINAGE_V1_100_PERCENT_COMPLETE`.

## Hard blockers

### G1 — production runtime composition

Affected: linear, tabulated, Hooghoudt, Ernst, empirical interflow and multi-level aggregation.

The already qualified response candidates have not been recomposed behind one current-canonical production drainage execution seam. This is real software closure work, not a status-file correction.

### G2 — transaction, mass, restart, MultiSWAP and diagnostics qualification

The absent runtime composition means the required end-to-end execution properties have not been independently qualified for those six variants. Existing scientific response tests remain valid but do not close this gap.

### G3 — canonical admission and preservation

The relevant F-VQ authorities explicitly withhold canonical admission. F-CI admission and postimage preservation are therefore still required after runtime qualification.

## Architecture invariant disposition

The current admitted spatial/DIVDRA and fixed-weir scopes preserve the SWAP architecture contracts. The completion failure is concentrated in missing evidence/execution for the unadmitted variants, not in a newly detected violation of the already admitted paths.

For the full frozen denominator, invariants 7, 8, 13, 16, 22, 26 and 29 remain `FAIL` at completion level because runtime transactionality, hard mass accounting, rerun/restart behavior, MultiSWAP execution, production HeadCalc isolation, diagnostics and absence of silent runtime dependencies cannot yet be demonstrated for every frozen variant. Invariants 14 and 25 have strong `PASS_BY_INDEPENDENT_QUALIFICATION` evidence at the response-science/reference level. All untouched composition/coupling/system-boundary invariants remain `PASS_PRESERVED`. The machine-readable artifact contains the complete 1–30 mapping.

## Source mutation and denominator statement

- Production source changed by F-PM13: `false`
- Reference source changed by F-PM13: `false`
- Frozen denominator changed: `false`
- Scope reduced: `false`
- New drainage physics introduced: `false`
- 100% completion: `false`

## Minimal dependency-ordered closure route

1. Establish exactly one production owner for the missing response-family runtime composition. Recompose only the already independently qualified frozen response candidates onto the live canonical contracts. Add no new drainage physics and do not reopen spatial/DIVDRA or fixed-weir authorities.
2. Route all six response variants through the canonical transaction and transfer/ledger semantics. Rejected trials may not book committed drainage. Accepted transfers are booked exactly once. Mass conservation remains hard, without a configurable relaxation.
3. Independently qualify the recomposed runtime against the immutable F-VQ44, F-VQ40, F-VQ38, F-VQ42 and F-VQ43 scientific authorities. Qualification must cover mass, accept/reject rollback, retry, restart/no-state semantics, MultiSWAP isolation/order independence, diagnostics, generic `[t0,t1]`, O0/O2, HeadCalc isolation and fail-closed unsupported combinations.
4. Admit only that independently qualified postimage through a separate serial F-CI workunit, followed by current-canonical postimage preservation.
5. Re-run the frozen-scope completion audit from that exact canonical head. Only a full PASS may emit `QUALIFIED_DRAINAGE_V1_100_PERCENT_COMPLETE`.

## Full follow-up prompt

The F-PM namespace was live-rechecked while closing this audit and `F-PM14` was free. The next execution must recheck it again and use the first actually free F-PM number if that changed.

```text
Start and complete a separate drainage production-closure workunit:

F-PM14 — SWAP5 Frozen Drainage Response-Family Runtime Composition & Final Production Closure

Ordinary ChatGPT chat, not Work mode.
Use the GitHub connector directly.
Repository: abhedwig-cell/SWAP5

Numbering
Recheck the complete live F-PM namespace before branch creation.
At F-PM13 close, F-PM14 was free. If it is no longer free, use the first actually free F-PM number. Never overwrite or reuse an existing workunit.

Proposed branch
work/f-pm14-drainage-response-runtime-closure

Authority and start point
Recheck integration/f-ci-canonical live immediately before branch creation.
Read and preserve:
- F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json
- F-PM13_DRAINAGE_V1_COMPLETION_AUDIT.md
- F-RG01 post-RB1 governance authority
- F-PM08 readiness contract
- F-VQ44 linear authority
- F-VQ40 tabulated authority
- F-VQ38 Hooghoudt/Ernst authority
- F-VQ42 empirical-interflow authority
- F-VQ43 multi-level authority
- current admitted spatial/DIVDRA F-CI32/F-CI33/F-CI36 authorities
- current admitted restricted fixed-weir F-VQ59/F-CI52/F-CI52P authorities
- current solver-service, process-hydraulic-view, source/sink, transaction, restart, MultiSWAP and diagnostic contracts.

Goal
Close only the three F-PM13 blockers G1–G3 for the frozen drainage-v1 denominator.
Do not develop new drainage physics.
Do not reduce or redefine the denominator.
Do not reopen the already admitted spatial/DIVDRA or restricted fixed-weir physics.
Do not change Full Richards physics.
Do not change mass-conservation policy.

Frozen missing response variants
1. restricted single-level linear-resistance drainage, exactly within the F-VQ44/F-PM08A qualified scope;
2. DRAMET=1 tabulated response, exactly within the remediated F-VQ40 scope;
3. DRAMET=2 Hooghoudt response, exactly within F-VQ38;
4. DRAMET=2 Ernst response, exactly within F-VQ38;
5. empirical interflow drainage-side response, exactly within F-VQ42;
6. multi-level aggregation, exactly within F-VQ43.

Hard scope guards
- no reverse/infiltration drainage claim unless it is already explicitly inside the frozen authority for that variant;
- no new response equation or parameter semantics;
- no process access to HeadCalc internals;
- no process mutation of solver Jacobian internals;
- solver owns Jacobian assembly and chain rule;
- no file I/O, parser, path, file-unit, daily or midnight assumption in kernel/process code;
- no configurable drainage mass-balance tolerance;
- no duplicate production owner;
- no weakening of reference mode;
- no hidden per-column solver scratch or unnecessary persistent state;
- no silent unsupported-combination fallback.

Required production architecture
Create the smallest common current-canonical drainage response runtime seam that can execute the already qualified response variants without duplicating their science.
Keep parameters, forcing, committed state, numerical policy, transfer/result and diagnostics explicit.
Stateless response variants must not acquire persistent state merely for uniformity.
All temporary solver data remains worker-owned.
Use explicit hydraulic process views, not HeadCalc arrays.
Use generic [t0,t1].

Transaction and mass contract
For every frozen variant prove:
checkpoint -> trial/retry -> accept+commit or rollback.
A rejected or failed trial leaves no committed drainage transfer or diagnostic masquerading as accepted output.
An accepted transfer is booked exactly once.
State update and water ledger must derive from the same accepted candidate lineage.
No stale/cross-candidate response may be published.
Mass conservation is exact within existing qualified numerical accounting, with no configurable concession.

Restart and MultiSWAP
For stateless variants, persist and test an explicit no-additional-process-state contract.
For any required state, use typed optional per-column state only when active.
Prove restart roundtrip or no-state equivalence as applicable.
Prove MultiSWAP column isolation, order independence and no cross-column scratch/state contamination.
Do not create one heavy solver instance per logical column.

Diagnostics
Expose at least variant identity, accepted/rejected status, failure/unsupported reason, retries where applicable, transfer booked, and water-balance diagnostic through current runtime result/diagnostic contracts.
Non-smooth/singular response conditions must remain explicit and fail closed according to their qualified scientific authority.

Qualification
Owner-side tests are not independent qualification.
After owner closeout, create a separate F-VQ workunit from the exact current prerequisite head.
The independent verifier must consume the immutable scientific authorities as oracles, not owner-generated expected values.
Minimum evidence:
- all six frozen response variants;
- response flux and defined sensitivities against existing F-VQ authorities;
- accept/reject/rollback and retry cases;
- exactly-once mass booking and no booking on reject;
- restart or explicit stateless restart equivalence;
- MultiSWAP isolation/order independence;
- HeadCalc-internal dependency check;
- generic non-day/non-midnight intervals;
- unsupported combinations fail closed;
- O0/O2 identity where the existing qualification policy requires it;
- reference source unchanged;
- all 30 SWAP architecture invariants explicitly audited.

Canonical admission
Only after independent F-VQ PASS:
- open a separate serial F-CI admission workunit from live integration/f-ci-canonical;
- admit only the qualified source/runtime postimage and required test/governance support;
- run the dedicated admission gate and broad canonical gate;
- perform current-canonical postimage preservation;
- do not combine unrelated production work.

Exit
Persist exact source blobs, qualification heads/runs, admitted canonical SHA/tree, mass/transaction/restart/MultiSWAP/diagnostic evidence, and a 30-invariant audit.
Then run a new frozen drainage-v1 completion audit using the same denominator as F-PM13.

Only emit:
QUALIFIED_DRAINAGE_V1_100_PERCENT_COMPLETE
if every F-PM13 frozen variant is scientific-qualified, runtime-qualified, current-canonical admitted/preserved, transaction-safe, mass-safe, restart-safe, MultiSWAP-safe, HeadCalc-isolated and diagnostically explicit.

Otherwise fail closed with:
DRAINAGE_V1_FINAL_CLOSURE_GAPS_IDENTIFIED
and list the exact remaining minimal gaps.

Never round 99.x to 100%.
Never shrink scope to obtain closure.
Never modify integration/f-ci-canonical directly from the owner workunit.
```

## Final decision

`DRAINAGE_V1_FINAL_CLOSURE_GAPS_IDENTIFIED`

This is the authoritative F-PM13 result on its audited canonical base. The scientific response family is well qualified, and the admitted spatial/DIVDRA plus restricted fixed-weir paths are strong. The remaining work is bounded but real: production runtime composition, end-to-end execution qualification and canonical admission/preservation for the six already qualified response variants.
