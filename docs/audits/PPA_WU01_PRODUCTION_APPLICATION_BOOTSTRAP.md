# PPA-WU01 Production Application Bootstrap

## Status

**CANONICAL_ADMITTED_RESTRICTED_PRODUCTION_CLOSED**

Workunit: PPA-WU01  
Branch: `work/ppa-wu01-production-application-bootstrap`  
Qualified source head: `92181c96486c7d49ac1d6cd19a7236f1dcf204b7`  
Canonical admission: PR #306, merge `a95a14d3544ae6f7dc86d04694c9d466518f65b7`

## Purpose

PPA-WU01 closes the narrow ownership gap identified by the Production Physics & Application Envelope Gap Audit. Before this workunit, SWAP5 could execute admitted typed soil-water and groundwater capabilities, but a caller had to arrive with already-owned FMR state or a pre-existing F-GC49D application context.

The production bootstrap now creates and owns the persistent FMR-side runtime objects from an explicit typed application configuration. It does not introduce a legacy parser, meteorological ingestion, new physics, or Python-owned SWAP state.

## Production authority

Production implementation:

`src/runtime/mod_fmr_production_application_bootstrap.f90`

The bootstrap owns:

- logical FMR columns and templates;
- typed physical parameters and already-resolved effective forcing;
- committed physical state;
- Reference Richards backend and top-boundary provider;
- for the groundwater profile only: head-forcing materializers, participant registry, participant handles and interface mass ledgers;
- the lifecycle of a per-window F-GC49D application plan/context and its opaque C-API handle.

The application owner is Fortran/FMR-owned. The Python groundwater runtime remains an orchestration client of an opaque handle and does not own SWAP committed state, candidate state, ledgers or participant lifecycle.

## Restricted admitted profiles

PPA-WU01 deliberately admits two separate profiles.

### Standalone Reference profile

- serialized Reference Richards runtime;
- `bottom_mode=7`;
- explicit already-resolved typed effective forcing;
- base optional-state topology;
- no new process family introduced by WU01.

The bootstrap drives the existing `fmr_run_serialized_physical_multiswap` transaction path. Accepted state therefore remains owned by the canonical committed-state lifecycle.

### Groundwater application-owner profile

- Reference Richards groundwater participant;
- `bottom_mode=5`;
- valid typed groundwater datum;
- production head-forcing materializer;
- F-GC49B participant registry;
- separate interface mass ledger per tile;
- F-GC49D application context materialized from an already-admitted topology, predictor response and cell-area input.

The context is window-scoped. Persistent committed SWAP/FMR state remains owned by the bootstrap across context creation and retirement.

### Explicit fail-closed boundary

A mixed `bottom_mode=5` / `bottom_mode=7` bootstrap is not admitted by WU01. Other lower-boundary profiles are not inferred. New physics is not enabled by this bootstrap.

## Qualification

Workflow:

`PPA-WU01 production application bootstrap`

Successful run:

`35365440351`

Successful job:

`105666642389`

Qualified head:

`92181c96486c7d49ac1d6cd19a7236f1dcf204b7`

The same production implementation was compiled and executed at O0 and O2. The stable qualification output was identical.

Decisive markers:

- `PPA_WU01_TYPED_CONFIG_TO_FMR_OWNER=PASS`
- `PPA_WU01_STANDALONE_REFERENCE_RICHARDS_RUNTIME=PASS`
- `PPA_WU01_STANDALONE_HARD_MASS=PASS`
- `PPA_WU01_COMMITTED_STATE_FORTRAN_OWNED=PASS`
- `PPA_WU01_FGC49B_REGISTRY_FORTRAN_OWNED=PASS`
- `PPA_WU01_MASS_LEDGERS_FORTRAN_OWNED=PASS`
- `PPA_WU01_FGC49D_CONTEXT_FROM_PRODUCTION_OWNER=PASS`
- `PPA_WU01_NO_QUALIFICATION_FIXTURE_BOOTSTRAP=PASS`
- `PPA_WU01_UNADMITTED_PROFILE_FAILS_CLOSED=PASS`
- `PPA_WU01_O0_O2_OUTPUT_IDENTITY=PASS`
- `PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS`

## Qualification-driven repairs

The first qualification attempt used a mode-5 standalone trajectory. The backend admitted the physical profile, but the transaction did not complete. WU01 did not change solver, retry or physics semantics to force that trajectory through. Instead, standalone qualification was rebound to the pre-existing admitted serialized Reference profile with `bottom_mode=7`, while mode 5 remained the groundwater participant route.

The second qualification attempt revealed an ownership error in the first bootstrap implementation: it created the groundwater participant registry for every application profile. The registry correctly rejected the standalone mode-7 materializer. The repair made groundwater ownership optional and profile-bound. The generic FMR owner is therefore independent of coupling infrastructure.

These are WU01-local composition repairs. They do not change Richards physics, transaction semantics, F-GC49D convergence logic or lower-boundary science.

## Non-claims

PPA-WU01 does not establish:

- complete SWAP 4.3.1 input-file compatibility;
- weather-file, calendar or cursor ownership;
- complete atmospheric preprocessing;
- full legacy output composition;
- a broad lower-boundary selector map;
- migration of macropore, frost, hysteresis, advanced stress, tillage or other missing process families;
- a general mixed-profile application bootstrap;
- actual registration of a SWAP5 driver in upstream iMOD Coupler;
- heterogeneous N:1 hydrological transferability;
- ROM functionality.

## Consequence for the application-envelope audit

The former statement that SWAP5 has no production config-to-owned-FMR bootstrap is no longer correct after canonical admission of PPA-WU01.

The remaining application gap is broader composition around this restricted typed owner, especially normal atmospheric/input ingestion and broader application configuration. PPA-WU03 remains the planned workunit for that boundary.

For F-GC50, the internal SWAP5 bootstrap prerequisite is satisfied only for the restricted WU01 production profiles. Actual iMOD Coupler product integration still requires an authorized upstream product-driver extension and an explicit mapping from product configuration into an admitted SWAP5 bootstrap profile.


## Canonical closeout

PPA-WU01 was canonically admitted through PR #306 at `a95a14d3544ae6f7dc86d04694c9d466518f65b7`.

Final admission-head checks:

- owner qualification run `35368123088`: PASS;
- documentation run `35368123177`: PASS;
- F-CI canonical qualification run `35368122940`: PASS.

The pre-merge canonical advanced only through PUB-GC manuscript/submission-readiness documentation. That live delta had no overlap with WU01 source, tests, workflow, audit register or F-CI preservation authority.

The moving-preservation prerequisite discovered during admission was closed separately by PR #308. Its canonical qualification run `35367229074` passed with no production mutation.

PPA-WU01 is therefore **CLOSED**. Any broader atmospheric/input composition belongs to PPA-WU03; lower-boundary authority recovery belongs to PPA-WU02.
