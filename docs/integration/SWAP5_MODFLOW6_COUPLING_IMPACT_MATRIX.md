# Coupling-semantics impact matrix

Date: 2026-09-20

Canonical audit preimage: `integration/f-ci-canonical@919bbf76370c2136932daa04ad88135e7d1615a8`.

Classification vocabulary:

- `UNAFFECTED`: evidence remains valid for the claim it actually tested.
- `NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED`: calculations/evidence remain useful, but one or more scientific labels/claims must be narrowed or renamed.
- `COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED`: the evidence depends on the application-level coupling assumptions now under correction and must not be used as final production/scientific authority without requalification.
- `INVALIDATED`: the demonstrated calculation/result itself is unusable.

No evidence block is classified `INVALIDATED` by this audit. Historical evidence is preserved.

## F-GC authority and evidence

| Authority/evidence | Impact | Reason |
| --- | --- | --- |
| F-GC17 head/datum interface authority | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | The pressure-head to hydraulic-head conversion is sound. `H_SWAP` must be read as lower-face trial hydraulic head, not SWAP diagnostic groundwater level or application groundwater ownership. |
| Early Groundwater Coupling v1 transaction, ledger, rollback and accepted-state work through F-GC28 | UNAFFECTED for transaction semantics; semantic wording review required where direct head/flux language is broader | Rejected-state isolation, same-origin replay and accepted publication do not depend on a legacy SWBOTB identity. |
| F-GC21 concrete FMR groundwater-head forcing adapter | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | It introduced `bottom_mode==5` as profile admission. Mode 5 is a valid internal corrector representation but not coupled-application authority. |
| F-GC23/F-GC29 response/sensitivity services | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | Response mathematics remains useful, but state/control coordinates must be named as lower-face/coupling quantities rather than generic groundwater-level authority. |
| F-GC25 MultiSWAP direct-groundwater composition | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | Mapping/transaction composition remains useful; physical transferability and vertical head-transfer assumptions are not established by composition. |
| F-GC30 prescribed-qbot predictor, `u/q_u` response | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | The algebra is admitted and matches the 2024 coupling concept. `u` is coupling/storage response and `q_u` is predictor/groundwater-response information, not automatically accepted interface mass. |
| F-GC31 active-drainage predictor/tangent | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | The predictor is mass-complete. Its mode-2-only admission cannot be used to infer that drainage is incompatible with head-driven coupled correctors. Drainage ownership still needs an explicit coupled contract. |
| F-GC33 linear response backend | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | HCOF/RHS transform is algebraically valid. Physical use requires explicit storage-partition authority for the `u/DeltaT` slope relative to MODFLOW STO. |
| F-GC34 typed API publication | UNAFFECTED | Publishes already constructed terms; does not determine their hydrological meaning. |
| F-GC35 XMI package adapter | UNAFFECTED | Pointer/package access is implementation plumbing. |
| F-GC36 live MODFLOW bridge | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | Demonstrates real kernel consumption of affine terms, not physical validity of a realistic storage/head partition. |
| F-GC38 prepared-solve backend | UNAFFECTED | Fixed `XOLD`, evolving `X`, repeated external terms and one finalize solve remain the correct state distinction. |
| F-GC39 prepared-solve coupling-service contract | UNAFFECTED for state/iteration mechanics | The mechanics remain valid. Documentation about exact layer placement relative to iMOD Coupler should be reconciled with F-GC49/F-GC50 wording. |
| F-GC40 N:1 affine cell aggregation | UNAFFECTED mathematically | Conservative aggregation remains valid as software algebra; heterogeneous hydrological transferability remains a separate SCALE question. |
| F-GC41 whole-window acceptance/publication | UNAFFECTED | Publication and failure semantics do not require mode 5 as application authority. |
| F-GC42 service composition | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | Composition is usable, but the scientific names of head/exchange quantities must follow the corrected contract. |
| F-GC43 real FMR/SWAP participant | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | Participant correctors are concretely bound to the mode-5 materializer/profile admission. |
| F-GC44 real SWAP + live MODFLOW E2E | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | Strong numerical/transaction evidence remains, but the synthetic case does not establish production vertical head transfer or non-overlapping storage. |
| F-GC45 | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | Inherits the same participant/head-response application assumptions as F-GC44. |
| F-GC46 multi-cell live MODFLOW | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | Multi-cell execution remains evidence, but every cell inherits the same head/storage coupling assumptions. |
| F-GC47 mixed topology live MODFLOW | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | Topology execution remains evidence, but topology lacks explicit vertical head transfer, drainage owner and storage partition. |
| F-GC48 generic groundwater topology | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | Tile-to-cell mapping is useful but semantically incomplete for realistic production because vertical transfer/storage/drainage ownership are absent. |
| F-GC49A application plan | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | Materializes terms and bindings from the incomplete topology/response authority. |
| F-GC49B participant registry | UNAFFECTED as registry mechanics | Opaque handle/state ownership does not itself decide coupling physics. |
| F-GC49C generic service | UNAFFECTED for iteration/publication mechanics; semantic input contract must be updated | Flux iteration and publication ordering remain useful. |
| F-GC49D production FMR application context | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | Routes MODFLOW cell heads to real participants and therefore consumes the current application-level binding. |
| F-GC50 product-integration state | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED before future implementation | Its internal-ready statement explicitly depends on the restricted PPA-WU01 `bottom_mode=5` profile. Product integration must not freeze that profile as final groundwater semantics. |

## PUB-GC E1-E7

| Experiment | Classification | Disposition |
| --- | --- | --- |
| E1 interface identity/conservation | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | The arithmetic identities, SWAP balance and accepted-ledger equality remain useful. Rephrase `q_u` as predictor response, not accepted recharge. The zero-storage-change case does not resolve storage partition. |
| E2 rejected-trial/accepted publication authority | UNAFFECTED | Trial isolation and exactly-once publication do not depend on mode-5 application semantics. |
| E3 coupling-window/feedback characterization | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | Numerical residual/head results remain valid for the synthetic identity-head-transfer fixture. Do not generalize them as a validated realistic SWAP-MODFLOW storage conceptualization. |
| E4 response identity | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | The finite-window map comparison remains informative and already shows `u_A` is not a universal head-to-exchange Jacobian. Tie terminology to predictor/corrector coordinates. |
| E5 response-assisted iteration | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | Algorithmic comparison remains valid on its constructed response problem, but it cannot supply missing physical storage/head-transfer authority. |
| E6 active-drainage and stress extension | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | The current stop remains valid evidence of the old implementation envelope. It no longer supports a physical incompatibility between drainage and coupled head-driven trials. |
| E7 Hupsel realistic application | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | Preserve the frozen dates and stop evidence, but classify the outcome as `DIAGNOSTIC_EVIDENCE_UNDER_SEMANTIC_REVIEW`. The stop is largely an artifact of the current profile binding. Do not rerun until corrected coupling authority and storage/drainage ownership are established. |

## PUB-GC claim consequences

The following claim classes can remain with corrected wording:

- transactional same-origin replay;
- rejected-trial zero authority;
- prepared-solve MODFLOW state distinction;
- exactly-once accepted publication;
- algebraic `u/q_u` predictor response;
- numerical convergence behaviour of the tested synthetic fixtures.

The following claims are held:

- realistic-production validity of the current head-transfer identity without application-specific authority;
- interpretation of `u` plus MODFLOW STO as a proven non-overlapping physical storage model;
- E6/E7 as evidence of a physical mode-5 plus drainage/root limitation;
- Hupsel realistic-transferability conclusion;
- final manuscript submission authority.

## Supersession rule

Historical reports remain in the repository. New reconciliation notes supersede their current interpretation but do not rewrite their recorded observations, run IDs or numerical outputs.
