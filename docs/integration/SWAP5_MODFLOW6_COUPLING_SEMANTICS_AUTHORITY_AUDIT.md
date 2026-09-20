# SWAP5-MODFLOW6 Coupling Semantics Authority Audit

Date: 2026-09-20

Audit authority preimage: `integration/f-ci-canonical@919bbf76370c2136932daa04ad88135e7d1615a8`.

Status: **AUDIT CLOSED, REPAIR REQUIRED, STORAGE-PARTITION AUTHORITY BLOCKER OPEN**

## 1. Question

This audit re-examines the ownership and exchange contract between SWAP5 and MODFLOW6 independently of legacy SWAP lower-boundary option semantics.

The triggering observation was that the production route accepts MODFLOW cell heads, materializes them through the SWAP mode-5 prescribed-pressure-head adapter, and defines the production groundwater profile by `bottom_mode==5`. Authentic Hupsel drainage/root processes were then rejected by that profile.

The audit asks whether that is correct coupling semantics, an interpretation error, an authority-binding error, an implementation defect, or a deeper coupling-design defect.

## 2. Sources and precedence

The audit used, in descending relevance:

1. current SWAP5 canonical code, tests, qualification and governance;
2. frozen SWAP4.3.1 B1.11 source-bound lower-boundary audit;
3. official public SWAP 4.3.030 theory/manual;
4. the 2024 technical SWAP-MODFLOW coupling design;
5. official/current MODFLOW6 prepared-solve and storage semantics already pinned by the F-GC38 chain.

External sources checked on 2026-09-20:

- SWAP soil-water-flow manual:
  https://www.swap.alterra.nl/manual/02_soil_water_flow.html
- SWAP drainage manual:
  https://www.swap.alterra.nl/manual/04_surface_runoff_interflow_and_drainage.html
- SWAP-MODFLOW technical presentation:
  https://www.stowa.nl/sites/default/files/2024-01/3.%20Ab%20Veldhuizen.pdf

Earlier SWAP5 documentation was treated as evidence, not as controlling authority where its interpretation was under review.

## 3. Live canonical reconciliation

The requested starting SHA `e6c28770786a4cc7cb2ab6cf4b8e3f936c44b3f1` was no longer canonical.

At audit start:

`integration/f-ci-canonical = 919bbf76370c2136932daa04ad88135e7d1615a8`.

The existing work branch `work/f-gc-coupling-semantics-reconciliation` was found to be based exactly on that head with no canonical lag. Its prior audit text was treated as a checkpoint, not as authority. One factual error in that checkpoint, SWBOTB=6 labelled as prescribed groundwater level, is corrected by this audit.

## 4. Legacy boundary semantics

The frozen source-bound PPA-WU02 audit and the public SWAP manual agree:

- SWBOTB=1: prescribed groundwater level;
- SWBOTB=2: prescribed lower-boundary flux;
- SWBOTB=5: prescribed pressure head at the lower boundary/bottom compartment;
- SWBOTB=6: zero lower-boundary flux.

Mode 5 is therefore a lower-face Dirichlet pressure-head condition. It is not the legacy prescribed-groundwater-level option.

The manual also states that drainage can coexist with options 1, 2, 3, 5 and 6. The production rejection of mode 5 plus active drainage is therefore not an intrinsic legacy SWAP physics rule.

See `SWAP5_MODFLOW6_LEGACY_BOUNDARY_RECONCILIATION.md`.

## 5. Original coupling concept

The 2024 SWAP-MODFLOW design does not define two-way coupling as a persistent standalone mode-5 SWAP application.

It distinguishes:

- SWAP as an unsaturated plus saturated column model;
- MODFLOW6 as the regional saturated-flow model;
- SWAP diagnostic groundwater level from MODFLOW hydraulic head;
- a predictor bottom flux from the regional groundwater balance;
- a SWAP-derived exchange/recharge quantity `q_u`;
- a response/storage coefficient `u`;
- a finalization step in which the MODFLOW head is imposed at the SWAP bottom.

The same source explicitly notes that the groundwater level calculated by SWAP need not equal the MODFLOW head because resistance in the phreatic layer can produce a difference.

The F-GC30/F-GC33 production algebra is recognizably derived from this predictor/response formulation.

## 6. Current implementation trace

The present production implementation does the following.

### Predictor

A same-origin SWAP trial with prescribed `qbot` produces lower-face head response and the F-GC30 `u/q_u` predictor relation.

### Groundwater solve

F-GC40 aggregates tile responses and F-GC33 creates an affine MODFLOW API-package term. MODFLOW runs one prepared solve with fixed accepted `XOLD` and evolving `X`.

### Corrector

The current MODFLOW cell head `X` is routed to each SWAP participant. The concrete FMR forcing adapter converts it through the datum to lower-face pressure head and executes a mode-5 same-origin corrector trial.

### Residual

The service compares the realized SWAP whole-window bottom rate against the current MODFLOW API-package rate. When not converged, the SWAP candidate is discarded and the affine term is re-anchored at the current head and realized SWAP rate while retaining the slope.

### Acceptance

On coupled convergence, MODFLOW solve and timestep, SWAP candidate and interface ledger are published under the admitted ordered transaction contract.

The exact trace is persisted in `SWAP5_MODFLOW6_CURRENT_IMPLEMENTATION_SEMANTIC_TRACE.md`.

## 7. Answers to the requested semantic questions

### 7.1 Who owns groundwater head?

MODFLOW6 owns the accepted regional groundwater state/head and the current nonlinear groundwater iterate.

SWAP may calculate a diagnostic phreatic level internally. That diagnostic is not the coupled groundwater authority and need not equal the MODFLOW head.

### 7.2 What should MODFLOW deliver to SWAP?

For the currently intended finalization/corrector method, MODFLOW supplies a hydraulic head iterate associated with the mapped groundwater cell/node.

The coupling layer must then apply an explicit head-transfer/datum contract to obtain the SWAP lower-face trial hydraulic head.

The current implementation uses the identity transfer `H_bottom=H_MF,node`. This is an application coupling assumption and must be made explicit. It is not a statement that the MODFLOW head equals SWAP groundwater level.

### 7.3 What should SWAP deliver to MODFLOW?

Not one undifferentiated “recharge” scalar in all stages.

The predictor supplies response information:

- `q_u`;
- `u`;
- reference lower-face head and derivative provenance.

The head-driven corrector supplies the realized whole-window SWAP bottom transfer at the current groundwater iterate.

The accepted transfer is the converged MODFLOW-package/SWAP-corrector exchange, published once. Predictor `q_u` is not authoritative accepted mass merely because it was used in the groundwater solve.

### 7.4 Where is the interface?

The computational SWAP condition is the fixed lower face of the SWAP column.

That is distinct from:

- the lowest SWAP node;
- the diagnostic phreatic surface inside SWAP;
- the MODFLOW cell centre/node;
- groundwater storage.

The current topology maps tiles to MODFLOW cells but does not encode a vertical transfer geometry or resistance. Thus an identity mapping between MODFLOW node head and SWAP bottom head is currently implicit.

### 7.5 May a coupled SWAP application possess a legacy bottom_mode as groundwater authority?

Not as the application-level groundwater authority.

A concrete participant may internally use mode 5 to realize a temporary lower-face Dirichlet trial. The coupled application should instead be admitted under an explicit groundwater-coupling profile/contract.

Standalone SWBOTB selection and external groundwater ownership are different layers.

### 7.6 Is mode 5 internally usable?

Yes.

The existing datum conversion and mode-5 materialization are suitable as an internal corrector/finalization realization, subject to application-specific head-transfer authority and process-envelope qualification.

The implementation defect is that `bottom_mode==5` is also used as the gateway for the production groundwater profile.

### 7.7 Drainage and root uptake

Root uptake remains a SWAP process. It affects column storage and the coupled response but is not a separate MODFLOW exchange.

Drainage must have one explicit owner per physical drainage path.

SWAP can physically combine mode 5 with drainage. But the 2024 coupling concept also allows regional/local groundwater drainage to influence the groundwater-to-SWAP predictor flux. A coupled application must therefore declare whether a drainage path is SWAP-owned, MODFLOW/surface-water-owned, or explicitly partitioned.

The same drainage discharge must never be represented on both sides.

### 7.8 Mass conservation

Mass conservation requires separate component balances and one accepted interface transfer.

SWAP balance includes:

- atmospheric/surface fluxes;
- root uptake;
- SWAP-owned drainage;
- SWAP storage change;
- lower-face transfer.

MODFLOW balance includes:

- regional groundwater flows;
- MODFLOW-owned sinks/sources;
- MODFLOW storage;
- the coupling-package transfer.

At accepted convergence the coupling-package transfer and realized SWAP lower-face transfer must agree under one sign convention. In the combined-system balance the pair is internal and cancels.

Rejected predictor/corrector work must contribute zero accepted interface history.

## 8. Storage ownership finding

This is the one material semantic issue that cannot be closed from current authority.

The SWAP-derived coefficient `u` is a finite-window lower-face head response. F-GC33 injects `u/DeltaT` into the MODFLOW API-package slope. The 2024 design calls `u` an exchange/storage coefficient controlling how quickly MODFLOW head responds.

MODFLOW STO independently owns cell storage through specific storage/specific yield.

The current production topology and application configuration do not state which physical storage volume represented by `u` lies outside, supplements, or overlaps the MODFLOW STO volume.

The live F-GC44/F-GC46/F-GC47 qualification fixtures use nonzero STO together with the SWAP-derived affine response. Those tests prove numerical composition, not absence of realistic hydrogeological storage overlap.

Therefore:

**STORAGE_PARTITION_AUTHORITY_REQUIRED**

Before broad realistic production admission, the coupled application must define a non-overlapping storage partition or a justified overlap correction.

This audit does not assert that present tests double-count storage. It finds that the repository does not yet contain enough scientific authority to prove that a realistic configuration does not.

## 9. Defect classification

### Interpretation defect: YES

Examples:

- treating mode 5 as prescribed groundwater level;
- treating a MODFLOW trial head as application-level SWAP groundwater authority;
- treating the E7 mode-5 process guard as a physical SWAP drainage limitation;
- treating predictor `q_u` as if it were automatically accepted interface mass.

### Authority-binding defect: YES, PRIMARY

F-GC17 introduced a lower-face hydraulic-head conversion. F-GC21 then admitted one concrete FMR materializer restricted to `bottom_mode==5`. Later bootstrap/application authority elevated that implementation restriction into the production groundwater profile.

This is the main provenance error.

### Implementation defect: YES

`mod_fmr_groundwater_head_forcing_adapter` and `mod_fmr_production_application_bootstrap` use the legacy mode selector as a production coupling-admission key.

The bootstrap additionally couples process admission, including drainage/root rejection, to that profile.

### Architecture/design defect: YES AT CONTRACT LAYER, NOT A DEMONSTRATED FAILURE OF THE NUMERICAL ITERATION

The current production coupling contract lacks:

- an application-level coupled-groundwater profile independent of legacy SWBOTB;
- explicit head-transfer geometry/operator authority;
- explicit drainage ownership;
- explicit storage partition between SWAP-derived `u` and MODFLOW STO.

No evidence from this audit shows that the prepared-solve iterative algorithm itself is fundamentally numerically wrong.

Therefore the overall answer is a **combination of interpretation, authority-binding and implementation defects plus an incomplete coupling-contract architecture**. It is not evidence that the complete partitioned coupling method must be discarded.

## 10. E7 disposition

The historical E7 evidence is preserved.

Current authority is changed from:

`CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT`

to:

`DIAGNOSTIC_EVIDENCE_UNDER_SEMANTIC_REVIEW`.

The observed stop remains real: the current production bootstrap cannot instantiate authentic Hupsel drainage/root composition through its restricted groundwater profile.

What is superseded is the scientific interpretation that this stop establishes a realistic physical/component-domain limit of SWAP-MODFLOW coupling.

E7 must not be rerun merely by deleting guards. First establish corrected coupled-groundwater, storage and drainage authority.

## 11. PUB-GC hold

PUB-GC must not move to final submission authority while this semantic repair is open.

The audit does not invalidate the full paper. Transaction, replay, response-algebra and controlled numerical evidence remain useful subject to the impact matrix.

See `SWAP5_MODFLOW6_COUPLING_IMPACT_MATRIX.md`.

## 12. Corrected contract

The proposed corrected contract is persisted in:

`SWAP5_MODFLOW6_CORRECTED_COUPLING_CONTRACT.md`.

Core form:

`MODFLOW accepted/trial groundwater state`
→ explicit head-transfer/coupling interface
→ same-origin SWAP coupled trial
→ realized SWAP exchange/response
→ MODFLOW groundwater equation
→ coupled convergence
→ accepted joint publication.

Legacy mode 5 may occur inside the SWAP trial adapter, never as the external application authority.

## 13. Repair slices

### CSR-01: semantic application profile

Introduce an explicit coupled-groundwater application/profile authority independent of `bottom_mode`.

No physics change.

### CSR-02: hide legacy lower-boundary realization

Retain the current head-to-pressure-head conversion behind a coupled-interface adapter. Remove `bottom_mode==5` as the public groundwater identity.

### CSR-03: head-transfer topology

Add explicit authority for the MODFLOW-node to SWAP-lower-face head transfer. Identity may be one admitted option.

### CSR-04: storage partition

Before realistic application admission, define and qualify the physical partition between SWAP-derived `u` and MODFLOW STO. This is a scientific/architectural prerequisite, not a code-cleanup task.

### CSR-05: drainage ownership

Add one-owner drainage topology and no-double-booking invariant. Then qualify the chosen authentic Hupsel drainage representation without changing physics solely to rescue E7.

### CSR-06: process capability

Admit root uptake and other state-dependent SWAP processes according to their real coupled response requirements. Keep derivative coverage separate from semantic application identity.

### CSR-07: requalification

Requalify the affected F-GC43/F-GC44-F-GC49 application chain under the corrected contract. Reuse unaffected transaction/backend evidence by dependency analysis.

### CSR-08: PUB-GC supersession

Update manuscript/claim authority only after CSR-04/05 and relevant requalification. E7 remains frozen until then.

## 14. Governance inconsistency found

Current documents disagree about whether predictor/corrector iteration is “below iMOD Coupler” or “product-level orchestration”.

F-GC39/F-GC44 place the internal coupling service below iMOD Coupler. F-GC49/F-GC50 also say the product driver coordinates the lifecycle and calls the admitted service, while some status wording says predictor/corrector ownership remains “under/in the iMOD Coupler layer”.

This is not the physical defect that triggered the audit, but the wording is ambiguous. Future documentation should distinguish:

- iMOD Coupler owning the outer product timestep/driver lifecycle;
- the admitted SWAP5 coupling service owning the bounded per-window iteration semantics and calling both participants.

## 15. Closeout

Audit closure means the semantic reconstruction and defect classification are complete.

It does **not** mean the production coupling is ready for broad realistic application.

Current disposition:

`AUDIT_CLOSED_REPAIR_REQUIRED_STORAGE_AUTHORITY_BLOCKED`.

No production physics, solver, tolerance, Hupsel configuration or coupling implementation was changed by this audit.
