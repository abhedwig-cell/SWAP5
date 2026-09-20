# SWAP5-MODFLOW6 coupling semantics authority audit

## Status

**SEMANTIC_RECONCILIATION_CLOSED — REPAIR_REQUIRED**

Date: 2026-09-20  
Reconciled canonical: `integration/f-ci-canonical@919bbf76370c2136932daa04ad88135e7d1615a8`

This audit is authority/evidence only. It does not change production physics or coupling implementation. Existing PUB-GC E7 evidence is preserved, but its former interpretation as a closed realistic component-domain limit is superseded by this audit.

## Decision

The current coupling contains a **sound core interface contract plus an incorrect application-authority binding**.

Classification:

- interpretation defect: **YES**;
- authority-binding defect: **YES, primary defect**;
- implementation defect: **YES, at the production application/profile gate**;
- fundamental coupling-design defect: **NO for the typed head/flux, transaction and MODFLOW ownership design; YES only if `bottom_mode=5` is treated as the coupled application's groundwater authority rather than an internal trial-boundary realization**.

A MODFLOW trial hydraulic head can correctly define the hydraulic Dirichlet value at a direct hydraulic interface during a SWAP trial. The defect is promoting the concrete legacy realization used to impose that trial value, `bottom_mode=5`, into the application-level definition and admission envelope of coupled groundwater operation.

## Theory and ownership authority

For a direct hydraulic SWAP-MODFLOW interface the coupled conditions are:

```text
H_SWAP(interface) = H_MF(interface)
q_SWAP(interface) = -q_MF(interface)
```

The groundwater component owns groundwater state and groundwater storage. SWAP owns the soil-column state and all SWAP process state. The coupler owns iteration, residual evaluation, acceptance and ordered publication.

A MODFLOW trial head is a coupling iterate, not accepted groundwater state. It becomes accepted groundwater state only when the coupled candidate is accepted and published. A SWAP trial evaluated at that head likewise remains disposable until publication.

The current F-GC17 contract already contains the correct datum transformation `psi_bottom = H_interface - z_bottom`, with unit conversion. This is a mapping from hydraulic head on the coupling plane to pressure head on the same plane. It is not a mapping from groundwater-table elevation to a legacy application option.

## Where the interface is

The interface is a **fixed lower coupling plane / lower face of the SWAP column** for the current direct-coupling contract. It is not, in general, the centre of the lowest SWAP node, the freatic surface, a MODFLOW cell centre, or groundwater storage.

The MODFLOW cell head is used as the groundwater-side hydraulic-head representation supplied to the coupling interface. That identification is a modelling/discretization contract and requires a common datum. The SWAP lower-face pressure head follows from `H=z+psi`.

If a deep vadose transfer component is active, the SWAP bottom plane and the groundwater exchange plane are not the same interface. Existing architecture invariant 18 already keeps that transfer zone outside SWAP.

## Legacy SWAP boundary reconciliation

The frozen SWAP4.3.1 source authority, as captured by PPA-WU02, classifies:

```text
SWBOTB=5 -> prescribed pressure head at the bottom boundary
SWBOTB=6 -> prescribed groundwater level
```

Therefore `SWBOTB=5` is **not prescribed groundwater level**.

Mode 5 can be a legitimate numerical mechanism for imposing a trial hydraulic head at the fixed lower coupling face after datum conversion. It does not make a coupled application semantically a standalone mode-5 groundwater application.

## Current implementation trace

```text
MODFLOW accepted state
  -> one prepared MODFLOW solve
  -> MODFLOW nonlinear trial cell heads
  -> F-GC49C generic service
  -> F-GC49D FMR application context
  -> participant trial_from_origin(cell_head)
  -> FMR groundwater head forcing materializer
  -> H_interface -> psi_bottom
  -> typed forcing.bottom_head
  -> Reference SWAP trial
  -> accepted whole-window bottom exchange
  -> area aggregation / response reanchoring
  -> MODFLOW boundary update
  -> conjunctive convergence
  -> MODFLOW publication
  -> SWAP publication
  -> interface-ledger publication
```

The live MODFLOW service does not give SWAP ownership of groundwater state. MODFLOW remains the groundwater-state owner. F-GC49D keeps SWAP state in Fortran and the coupling service owns iteration/publication.

The problematic binding occurs lower in the stack:

1. `mod_fmr_groundwater_head_forcing_adapter` declares the profile admitted only when `bottom_mode == 5`;
2. `mod_fmr_production_application_bootstrap` defines `groundwater_profile` as all tiles having `bottom_mode == 5`;
3. `production_application_groundwater_ready` repeats the same condition;
4. process-composition guards in `tile_config_valid` are consequently interpreted as restrictions of the groundwater coupling application;
5. E6/E7 then treated failure to compose drainage/root uptake with this mode-5 profile as a groundwater-coupling application-domain result.

This is the point where an implementation mechanism became application authority.

## Correct exchange contract

MODFLOW supplies per groundwater cell and trial iterate a hydraulic head on the common vertical datum plus lineage/revision/window provenance. The coupling adapter maps that trial head to the hydraulic state required at the SWAP lower coupling plane. In the current Reference backend this may be realized as a temporary prescribed lower-face pressure head. That realization is solver/runtime internal.

SWAP returns the accepted-sign whole-window exchange through the coupling plane, or an exactly equivalent mean interface rate, plus any qualified local response information used for iteration. MODFLOW recharge/exchange must be derived from this interface transfer and not from a terminal `qbot` sample.

Drainage remains a SWAP process when the drainage system is represented by SWAP. It is an external sink from the SWAP column to the drainage network. It is not automatically MODFLOW recharge and must not also be booked as groundwater-interface transfer. A drainage formulation intended to exchange directly with MODFLOW requires a separate explicit component/topology contract.

Root uptake, evaporation, precipitation, irrigation and other surface/process fluxes remain SWAP-owned balance terms. They affect bottom exchange through SWAP state and balance, but are not separate MODFLOW exchange terms.

SWAP storage change belongs to the SWAP column. MODFLOW storage change belongs to MODFLOW. Neither storage term is an interface flux. Conservation books the common interface transfer once with equal and opposite signs while each component closes its own balance.

## Mass-conservation invariant

For one accepted coupling window:

```text
SWAP:
Delta S_swap = surface/process inflows - surface/process outflows
               - drainage - root uptake - q_interface_out + other admitted terms

MODFLOW:
Delta S_gw = groundwater external inflows - groundwater external outflows
             + q_interface_out + other MODFLOW terms
```

Rejected SWAP or MODFLOW candidates contribute zero authoritative interface mass. The existing F-GC19/F-GC41/F-GC49 publication and ledger architecture remains valid under this interpretation.

## Defect classification and E7

E7 observed a real stop: authentic Hupsel requires drainage/root processes, while the production owner rejected those processes before a mode-5 participant could be allocated. That observation remains valid.

The former inference does not. The stop does not establish that authentic Hupsel lies outside the physically admissible SWAP-MODFLOW coupling domain. It establishes that Hupsel lies outside the current **mode-5-bound production participant implementation profile**.

E7 is therefore reclassified as:

```text
COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED
```

Do not rerun E7 until the corrected application/coupling authority is implemented and independently qualified.

## PUB-GC experiment impact

| Evidence | Disposition | Reason |
| --- | --- | --- |
| E1/E2 | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | sign/unit, rollback and exactly-once transfer evidence remains useful; prescribed-head application wording must be recast as a trial-boundary realization |
| E3/E3-R/E3-D | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | outer iteration evidence remains numerical evidence for the restricted realization; no application-level mode-5 authority may be inferred |
| E4 | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | response identities remain bounded numerical identities; prescribed-head derivatives describe a trial realization |
| E5 | NUMERICALLY_VALID_SEMANTIC_REINTERPRETATION_REQUIRED | algorithm/information-value comparison remains bounded to the same response realization |
| E6 | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | its drainage incompatibility is caused by the mode-5-bound corrector/profile intersection |
| E7 | COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED | the pre-owner stop is an implementation-profile boundary, not established physical coupling-domain evidence |

No experiment is globally invalidated by this audit. Claims depending on “groundwater coupling equals standalone mode 5” are superseded.

## F-GC authority impact

- F-GC17 head datum/sign/unit contract: **retain**, but reinterpret mode 5 as one Reference-backend realization.
- F-GC18/F-GC19 transaction and ledger contracts: **retain**.
- F-GC21 predictor/corrector ownership and publication contract: **retain**, but remove application-level dependence on a mode-5 profile.
- F-GC30/F-GC33 response contracts: **retain within their qualified numerical envelope**.
- F-GC39/F-GC41/F-GC49C/F-GC49D MODFLOW ownership, iteration and publication architecture: **retain**.
- FMR head forcing materializer and production bootstrap profile authority: **repair required**.
- Tests asserting `bottom_mode==5` as a coupling prerequisite: **supersede as application-authority tests**. Retain only tests proving the Reference backend's internal trial-head realization.

## Corrected design contract

```text
application physics configuration
  + accepted MODFLOW groundwater state
        |
        v
explicit coupled-groundwater interface
        |
        +-- coupling trial hydraulic head / provenance
        v
SWAP coupled-interface trial
        |
        +-- Reference implementation may internally impose psi_bottom
        |   using the legacy mode-5 numerical route
        |
        +-- SWAP processes remain configured independently
        v
whole-window SWAP interface transfer + optional response
        |
        v
MODFLOW boundary / nonlinear iterate
        |
        v
joint acceptance and ordered publication
```

Application configuration must state that the lower boundary is externally owned by the groundwater coupler, not that the application itself is `SWBOTB=5`.

## Required repair slices

**CSR-01, explicit coupled-boundary authority type.** Introduce an application/runtime distinction between standalone lower-boundary selection and externally coupled groundwater ownership. No new physics.

**CSR-02, Reference backend trial realization.** Move `H_interface -> psi_bottom -> bottom_head` behind the coupled-interface adapter. Permit the Reference backend to use the legacy mode-5 computational branch internally, but remove `bottom_mode==5` from the public/application coupling admission test. Prove numerical identity with the old restricted route where other physics are identical.

**CSR-03, process-composition separation.** Rework the production bootstrap so root uptake, drainage and other admitted processes are governed by their own composition authorities, not rejected merely because coupled groundwater is active. Do not silently admit unqualified combinations.

**CSR-04, drainage/recharge accounting qualification.** Add executable active-drainage balances proving drainage is booked once as a SWAP external sink, bottom interface transfer once in the groundwater ledger, MODFLOW receives only intended interface exchange, no double counting occurs, and rejected trials publish neither history nor interface mass.

**CSR-05, root-active coupled qualification.** Qualify root extraction under corrected coupled-boundary authority, including accepted-state dependence and rollback. Research-only root-active live-MODFLOW fixtures may inform this but are not production authority.

**CSR-06, PUB-GC requalification.** After required repair slices are admitted, rerun the minimal E1-E5 identity set, reconsider E6 under the corrected contract, and execute E7 prospectively with the frozen Hupsel dates and unchanged hydrological configuration.

## Governance disposition

PUB-GC submission authority is **HELD** pending corrected coupling-authority implementation and requalification. Historical E6/E7 files must not be deleted or rewritten.

Superseded current interpretations include:

- groundwater coupling requires the application to be `bottom_mode=5`;
- failure to compose authentic Hupsel with mode 5 demonstrates a realistic groundwater-coupling component-domain limit;
- a future process-complete prescribed-head owner is necessarily a new physical groundwater-coupling capability.

Replacement authority:

> The current Reference implementation uses a prescribed lower-face pressure-head realization for coupled trial heads. Coupled groundwater authority itself is defined by hydraulic-head continuity, interface-flux conservation, component state ownership and transactional publication, independently of legacy standalone SWAP lower-boundary option semantics.

## Closure

The semantic reconstruction is sufficiently determined by existing repository authority to close this audit without a new physics decision. Next action is implementation repair, starting with CSR-01/CSR-02. No Hupsel tuning, solver change or E7 rerun is authorized before that repair is qualified.
