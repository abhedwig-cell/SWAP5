# PPA-WU02 — Source-bound lower-boundary application envelope

Date: 2026-09-18

Status: `SOURCE_INVENTORY_COMPLETE / PPA-WU02-A + PPA-LOW02-TIME CANONICAL_ADMITTED / WORKUNIT_CLOSED`

Initial canonical authority at source reconcile: `integration/f-ci-canonical@12beef3e91f90f88b101c13af72cd216bccc63e3`.

Post-WU03 application-surface reconcile used `0d1798aafbf43417801d75a140e4f4f3cef74bd8`. PPA-WU02-A requalified at `eff8670a2614f72d34016dbfc7eba040c940c245` and was canonically admitted by PR #324 at `013c549686a8f310834ddb3e8d1270166f8283f1`.

## Authority binding

The exact SWAP 4.3.1 authority is B1.11, member-manifest SHA-256
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.
B1.11 differs from B1.10 only through SWAP-011 in
`MOD_MvG_functions.f90`, `WC_K_models_04_11.f90`, and `MOD_RIA.f90`.
The lower-boundary implementation is therefore unchanged from B1.10 to B1.11.
In particular, exact `SWAP/headcalc.f90` remains
`db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

The B1.11 replay also pins the unchanged lower-boundary source members:
`boundbottom.f90=5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e`,
`calcgwl.f90=d7649f02bf6cd629cc7eceb1c761a6c38d6f0adf0d0c072c7aaab3af4562f5eb`,
`soilwater.f90=027cfefc3ba7a010a256db1e43bd6e9c9facc4bf6edb4984578ddf1ef48acac8`,
`fluxes.f90=b28b163520bc2ed873d98d4e0308d7b02a33577ee81b12a7f4bc1bc4cf746550`,
and `integral.f90=bd37ebe5014f14ab2ff961a336cfa284266102d510617feef1c00f6616c64174`.
B1.11 `readswap.f90` is
`e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c`;
its admitted SWAP-013 change concerns PDI hydraulic-input validation and does not
alter the lower-boundary selector block. The B1.11 lower-boundary grammar is
therefore source-identical to the B0/B1.10 lineage except for that unrelated
`readswap` mutation.

For modes 2 and 5, the repository already contains independent exact-source
oracles reconstructed from the frozen 4.3.1 archive. F-SI27 binds mode 2 to
the exact HeadCalc residual and native qbot sign; F-SI16 binds mode 5 to the
exact HeadCalc plus accepted-step `watstor()+fluxes()` qbot publication.
F-APP02 independently binds legacy input selector 6 to zero qbot.

The complete selector/input catalogue below is also cross-checked against the
legacy SWAP parser/bottom-boundary source lineage. Those descendant/source-lineage
copies are corroboration for parser field names and `BoundBottom` staging; they
are not substituted for the frozen B1.11 identity.

## Native conventions

* Length: cm; flux rate: cm d-1.
* Native `qbot > 0`: water enters the simulated soil profile through the lower
  boundary. `qbot < 0`: water leaves the profile.
* A lower pressure head `hbot` is a pressure head at the lower face, not the
  nodal equation `h(NN)=hbot`.
* Groundwater level/head and lower-face pressure head are distinct semantics.
  The F-GC datum mapping remains its own owner.
* Candidate boundary effects are transactional. Accepted publication and mass
  accounting occur only after the accepted physical trajectory. No selector
  migration is allowed to create a second commit or mass owner.

## Source-bound selector matrix

| Legacy selector | Exact application meaning and source staging | Inputs/state | Solver/Jacobian semantics | Current SWAP5 reachability | PPA-WU02 classification |
|---|---|---|---|---|---|
| 1 | Prescribed groundwater level. `BoundBottom` interpolates `gwlinp(t+dt)`. If the GWL lies in/above the profile the Richards domain is truncated/continued saturated; if it lies below the profile it is converted to a lower-face `hbot`. | DATE1/GWLEVEL table; `gwlinp`, `gwl`, `fllowgwl`, geometry. Initial `SWINCO=2` also uses the prescribed GWL. | Internal-GWL branch has a saturated lower continuation and GWL-distance Jacobian. Below-profile branch uses the Darcy lower-face head gradient and K/d Jacobian. qbot is an output, not prescribed forcing. | Groundwater/head coupling exists through admitted F-GC contracts, but this legacy selector/state-machine is not the typed application contract. | `PRESERVED_NOT_TYPED_AS_LEGACY_MODE`; migration requires its own groundwater-level boundary/state slice. |
| 2 | Prescribed regional/native bottom flux. `BoundBottom` supplies a sinusoid or time table. At extremely dry bottom pressure head (< -1e7 cm) legacy application semantics switch temporarily to `-2` free drainage. | SW2; either SINAVE/SINAMP/SINMAX or DATE2/QBOT2; qbot. | `F_N=other_terms-qbot`; no boundary-head stiffness. F-SI27 proves exact B1.10/B1.11-equivalent solver identity. | Typed physics/runtime and temporal route are canonically admitted through F-SI38/F-MR44R/F-CI62. PPA-WU02-A admits homogeneous typed `bottom_mode=2`; PPA-LOW02-TIME additionally admits the exact B1.11 SW2 sine/table law and state-derived oven-dry `2 -> -2` continuation on the Reference production route. General SWP/BBC parsing and raw DATE2 string ingestion remain outside this slice. | `RESTRICTED_PRODUCTION_TYPED_APPLICATION_CANONICAL`; B1.11 SW2/time-law/dry continuation is closed, parser migration is not claimed. |
| 3 | Cauchy exchange with deep groundwater/aquifer, optionally plus a time-dependent extra groundwater flux. `BoundBottom` computes aquifer head and saturated-profile resistance. | SWBOTB3RESVERT, SWBOTB3IMPL, SHAPE, HDRAIN, RIMLAY; SW3 with AQAVE/AQAMP/AQTMAX/AQPER or DATE3/HAQUIF; optional SW4 DATE4/QBOT4; `gwl`, `deepgw`. | Explicit form presents qbot to the generic flux row. Implicit form recomputes qbot from bottom hydraulic head and resistance inside HeadCalc; Jacobian adds reciprocal resistance. | Formula remains in legacy port, but no admitted typed boundary contract/application adapter owns the complete semantics. | `PRESERVED_NOT_TYPED`; split explicit/implicit Cauchy migration only after source-bound timing/state contract. |
| 4 | Flux as a function of profile groundwater level. `BoundBottom` evaluates either `cofqha*exp(cofqhb*abs(gwl)) [+ cofqh c]` or a q(h) table before the Richards solve. | SWQHBOT; COFQHA/COFQHB and optional COFQHC, or HTAB/QTAB; current/profile `gwl`. | HeadCalc receives the resulting qbot through the generic flux row. The application law is state-dependent/lagged and is not semantically equivalent to a user-prescribed time-only qbot. | Generic mode-2 flux row exists, but the q(gwl) law and its staging do not. | `PHYSICS_ROW_REUSABLE / APPLICATION_LAW_NOT_MIGRATED`. |
| 5 | Prescribed lower-face pressure head as a function of time. | DATE5/HBOT5; `hbot`; lower-face K and geometry. | Darcy gradient `(h(NN)-hbot)/d+1`; K/d Jacobian. Exact authoritative qbot is materialized after accepted HeadCalc through the B1.10/B1.11-equivalent `watstor()+fluxes()` arithmetic. | F-SI16/F-MR11 lineage plus current F-GC/PPA-WU01 groundwater profile: restricted production. It is not a generic legacy DATE5 normal-file adapter. | `RESTRICTED_PRODUCTION`, groundwater-owned application route. |
| 6 | Zero lower flux. No extra input. | qbot = +0.0 cm d-1. | Same generic flux row as mode 2. | F-APP02 maps exactly `SWBOTB=6 -> typed bottom_mode=2, bottom_flux=+0.0`; F-VQ102/F-CI95 admitted this bounded application mapping. | `RESTRICTED_PRODUCTION` exact legacy adapter. |
| 7 | Free drainage. | No extra input; bottom K from current hydraulic state. | `qbot=-K_bottom`; residual subtracts qbot; conductivity derivative enters Jacobian where applicable. | F-SI13 typed semantics; PPA-WU01 normal standalone production application. | `PRODUCTION_ADMITTED`. |
| 8 | Lysimeter plate boundary with a no-flow/head-boundary switch. `BoundBottom` starts qbot at zero; HeadCalc activates the plate head boundary when the bottom state crosses the plate criterion. | No selector-specific parser table; uses `hplate`, bottom state and `flboth` continuation within the nonlinear call. | In inactive branch qbot=0. In active branch `hbot=hplate` and Darcy K/d lower-head row. Active-set state is held consistently within the HeadCalc evaluation sequence. | Preserved in legacy port, not admitted as typed application semantics. | `PRESERVED_NOT_TYPED`; needs explicit active-set/continuation contract. |
| -2 | Internal emergency free-drainage continuation reached from legacy mode 2 under oven-dry bottom conditions. Not a normal SWBOTB 1..8 input option. | Derived from current trial-start bottom pressure head plus current bottom K. | Same free-drainage equation as mode 7. | F-SI13 admits -2 at solver level; PPA-LOW02-TIME now makes that continuation canonically reachable from admitted typed mode 2 while keeping -2 non-normal and non-persistent. | `INTERNAL_CONTINUATION_CANONICALLY_REACHABLE_NOT_NORMAL_SELECTOR`. |
| 9 | Internal/extended-head path present in HeadCalc: solves one fewer unknown and uses the last stored head as the lower head continuation. It is outside the normal 1..8 parser catalogue. | Extra terminal head/node state and geometry. | Darcy lower-head row; `SWKIMPL=1` explicitly not implemented in the legacy path. | Preserved code path only; no typed/app admission. | `INTERNAL_SPECIAL_PRESERVED_NOT_TYPED`; no normal application claim. |

## Capability layers

The inventory deliberately separates four layers:

1. **physics capability**: a residual/Jacobian or accepted-flux formula exists;
2. **typed boundary contract**: the control is explicit and independent of parser globals;
3. **normal application adapter**: ordinary typed application construction can reach it;
4. **groundwater coupling semantics**: head/datum/sign/transaction exchange with F-GC.

A PASS in an earlier layer does not imply the later layers.

## Migration slicing

Priority is by independent semantic ownership, not selector number.

1. **PPA-WU02-A, typed prescribed qbot normal application.** Admit homogeneous
   `bottom_mode=2` profiles in the existing production application bootstrap,
   using the already admitted `base_forcing%bottom_flux`. No legacy parser,
   sinus/table law, dry fallback, groundwater coupling, or new physics.
2. **PPA-LOW02-TIME, B1.11 SWBOTB=2 time law and dry continuation.**
   Canonically admitted by PR #360 at `6c63b8d0e340669d9722bc5e3d947d42d2b467a5`.
   This closes the typed SW2 sine/table and exact state-derived `2 -> -2` slice,
   but does not migrate the general SWP/BBC parser or raw DATE2 date-string ingestion.
3. **SWBOTB=4 q(gwl) law.** Add an explicit state/timing boundary-provider
   contract before composition. Do not alias it to prescribed qbot.
4. **SWBOTB=1 prescribed-GWL state machine.** Reconcile with F-GC ownership,
   but do not move predictor/corrector or datum semantics into the solver.
5. **SWBOTB=3 Cauchy.** Treat explicit and implicit variants as distinct
   qualification regimes sharing one source-bound physical law.
6. **SWBOTB=8 lysimeter active set.** Preserve the exact active-set continuation
   semantics transactionally before admission.
7. Internal mode 9 and -2 remain non-normal application states unless a later
   authority explicitly requires exposure.

No broad “all SWBOTB migrated” claim follows from this work unit.


## PPA-WU02-A qualification

The preregistered application-only slice was implemented with one production
mutation: `src/runtime/mod_fmr_production_application_bootstrap.f90` now admits
a homogeneous `bottom_mode=2` profile alongside the pre-existing homogeneous
mode-7 standalone and mode-5 groundwater profiles. The bootstrap copies the
already-resolved typed forcing unchanged and creates no groundwater registry or
ledger for mode 2.

Final requalification after reconciling the shared bootstrap surface with canonical PPA-WU03 used exact head `eff8670a2614f72d34016dbfc7eba040c940c245`:

- PPA-WU02 workflow run `35374976662`;
- owner job `105697423309`: PASS;
- independent job `105697676084`: PASS;
- PPA-WU01 preservation run `35374976768`: PASS;
- Documentation run `35374976742`: PASS;
- canonical admission: PR #324, merge `013c549686a8f310834ddb3e8d1270166f8283f1`.

The owner gate proves nonzero prescribed qbot reaches the production bootstrap,
executes and commits through Reference Richards, preserves hard mass closure,
advances committed revision, reaches the exact arbitrary endpoint
`4100.6875`, and is output-identical at O0/O2. The independent gate locks the
lower-level production science blobs to canonical, inherits the independent
F-VQ75 sign/rollback/temporal/fail-closed oracle and F-CI62P canonical
admission, replays PPA-WU01 mode-7 and mode-5 application preservation, and
confirms the SWBOTB=6 zero-flux adapter is byte-unchanged.

This admission is deliberately narrower than legacy SWBOTB=2. It does not add
the SW2 sine/table generator, DATE2/QBOT2 parser, oven-dry `2 -> -2`
continuation, file I/O or any new groundwater semantics.


## Closure

PPA-WU02 is closed as an inventory plus bounded admissions. The B1.11 selector catalogue no longer carries a common-mode authority-unclear remainder. PPA-WU02-A is canonical for homogeneous typed prescribed qbot, and PPA-LOW02-TIME is canonical for the B1.11 SW2 sine/table law plus exact state-derived oven-dry continuation. The remaining frozen slices are standalone legacy SWBOTB=5 DATE5/HBOT5 application semantics and SWBOTB=1, 3, 4 and 8. General legacy SWP/BBC parsing remains outside the admitted PPA-LOW02-TIME scope.


## PPA-LOW02-TIME canonical closeout

The second lower-boundary migration slice was reconciled onto live canonical base
`e473afc2d378a2567a59cc0db1577b4c724feeb2` and qualified at
`8d238bb46c9d4d77e38802e75458d99f59794d11`. The PPA-LOW02-TIME workflow
run `35426047814` passed both owner job `105852054740` and independent job
`105852181968`. The same postimage also preserved the active successor
surfaces required for this shared backend: F-ROSS12 production wiring
`35426047903`, F-CI96 postimage preservation `35426047828`, F-GC42
`35426047891`, F-GC44 participant `35426047827`, F-GC44 end-to-end
`35426047766`, and F-VQ116 `35426047859` all passed.

PR #360 admitted the capability at canonical merge
`6c63b8d0e340669d9722bc5e3d947d42d2b467a5`. The admitted production
mutation is confined to `src/runtime/mod_fmr_serialized_reference_backend.f90`.
The control is immutable typed forcing. For each physical advance, the
Reference backend resolves the exact SW2 time law from that substep's time and
derives effective mode 2 or internal -2 from the trial-start bottom pressure
head. The configured selector itself is never mutated, so rollback and re-entry
remain properties of the existing transaction owner rather than a second
continuation state.

The closeout deliberately does not claim a generic SWP/BBC parser, raw DATE2
calendar-string ingestion, internal -2 as a normal user selector, mixed
bottom-mode applications, RossFast execution of this legacy control, or new
groundwater-coupling semantics. Those boundaries are machine-recorded in
`integration/audits/PPA_LOW02_TIME_STATUS.json`.
