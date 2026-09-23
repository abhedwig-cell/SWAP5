# SW-RIB-SWM01 legacy surface-water responsibility inventory

**Date:** 2026-09-23  
**Status:** BOUNDED INVENTORY / NOT RETIREMENT AUTHORITY  
**Canonical base:** `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`  
**Work branch:** `research/sw-rib-swm01-surfacewater-ownership`

## Evidence boundary

The exact SWAP 4.3.1 B0 identity records `SWAP/surfacewater.f90` as a 51,312-byte source with SHA-256
`d38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e`.
The repository intentionally keeps the authoritative B0 distribution as byte-exact binary archives rather than mirroring all unpacked source text. B1.11 does not patch `surfacewater.f90`, so B1.11 inherits that B0 body unchanged.

The responsibility inventory below combines:
1. exact B0 file identity;
2. repository migration authority;
3. the prior SWAP 4.3.1 documentation/code audit parameter inventory, which records literal TTUTIL identifiers and source locations;
4. the SWAP surface-water-management and drainage theory/input contracts;
5. current canonical SWAP5 F-CI52 restricted fixed-weir implementation and qualification.

It is therefore strong enough to freeze ownership classes and next tests, but it is **not** represented as a line-complete reconstruction of every executable statement in the raw legacy file. Any later whole-file retirement decision still requires exact-source reconstruction or equivalent accepted evidence.

## New architectural fact found during SW-RIB-SWM01

Current canonical SWAP5 already contains admitted restricted fixed-weir surface-water physics through F-CI52/F-VQ59. This production scope includes:

- optional surface-water storage state on feature-active columns;
- level/storage mapping;
- fixed-weir rating discharge;
- bounded supply below a level dip;
- attribution of positive secondary drainage;
- hard mass closure, rollback and restart semantics.

The restricted route explicitly rejects negative drainage/infiltration forcing.

Therefore SW-RIB-SWM01 must distinguish **application profiles**:

| Application profile | Surface-water state owner | Rule |
|---|---|---|
| Standalone SWAP5 fixed-weir profile | SWAP5 F-CI52 restricted fixed-weir process | May remain available under its admitted envelope. |
| SWAP5 + external Ribasim profile | Ribasim | Internal SWAP surface-water storage/weir/supply state must not be simultaneously authoritative. |
| SWAP5 + Ribasim exchange | SWAP for soil exchange, Ribasim for receiving/supplying surface-water state | Exactly one owner for each state and transfer. |

This means the target is **not deletion of all SWAP5 surface-water code**. The target is explicit mode-dependent ownership plus removal of duplicated authority.

## Responsibility classes

### A. RETAIN_IN_SWAP_EXCHANGE_PHYSICS

These responsibilities determine soil or drainage-system response to an externally supplied surface-water level and remain SWAP physics in a Ribasim-coupled application.

Observed legacy parameter family includes:

- drainage topology and level definitions: `NRSRF`, `LEV`, `SWDTYP`, `L`, `ZBOTDRE`;
- drainage/infiltration thresholds and resistances: `GWLINF`, `RDRAIN`, `RINFI`, `RENTRY`, `REXIT`;
- channel geometry used by drainage exchange: `WIDTHR`, `TALUDR`;
- distributed drainage configuration: `SWDIVD`, `SWDIVDINF`, `FACDPTHINF`, `COFANI`;
- discharge-layer configuration: `SWDISLAY`, `SWTOPDISLAY`, `ZTOPDISLAY`, `FTOPDISLAY`;
- rapid drainage/interflow family: `SWNRSRF`, `RSURFDEEP`, `RSURFSHALLOW`, `COFINTFL`, `EXPINTFL`, `SWTOPNRSRF`.

The coupled contract is:

```text
Ribasim accepted surface-water level
    -> SWAP drainage/infiltration exchange physics
    -> signed physical transfer
    -> Ribasim receiving/supplying surface-water ledger
```

Ribasim does not inherit these soil/drainage constitutive laws merely because it owns surface-water storage.

### B. SHARED_CONFIGURATION_MAPPING

Some legacy geometry has meaning on both sides of the coupling. It must not become two independently calibrated parameter sets.

Candidates include:

- control-unit elevation `ALTCU`;
- channel/drain geometry used both for exchange and for legacy surface-water storage mapping;
- level/order identifiers where one physical watercourse is represented both in SWAP exchange physics and the Ribasim network.

Target rule: one governed physical configuration, mapped explicitly into SWAP exchange parameters and Ribasim network/storage geometry. Equality of parameter names is not required, but physical provenance must remain traceable.

### C. RIBASIM_COUPLED_MODE_OWNER

In an external-Ribasim application these are system-level surface-water responsibilities and should not remain authoritative inside SWAP:

- dynamic surface-water storage and water level;
- initial/accepted surface-water state such as legacy `WLACT`;
- imposed primary/secondary level trajectories `DATEPRI/WLP` and `DATESEC/WLS` once the external network is the actual state owner;
- fixed-weir level/discharge relation:
  - `SWQHR`;
  - power-law family `SOFCU`, `HBWEIR`, `ALPHAW`, `BETAW`;
  - tabular family `HHTAB`, `QHTAB`;
- system-level supply realization and capacity, including the physical meaning represented by `WSCAP`;
- discharge routing/network composition beyond the local SWAP column.

For a Ribasim-coupled application, these map to Basin state/profile, TabulatedRatingCurve/Outlet/Pump/other network structures and allocation/supply routes as applicable.

### D. COUPLER_MANAGEMENT_POLICY

Legacy automatic control that observes SWAP soil state and requests a surface-water target is neither soil-flow physics nor surface-water hydraulics. It belongs above both models.

Observed family includes:

- `SWMAN=2` automatic management;
- observation depth `HDEPTH`;
- phase-specific managed target `WLSMAN`;
- groundwater criterion `GWLCRIT`;
- pressure-head criterion `HCRIT`;
- unsaturated-storage criterion `VCRIT`;
- `DROPR` and phase/index tables needed to select the active rule.

Target causal order:

```text
accepted SWAP state
    -> management-policy evaluation
    -> target/request
    -> Ribasim control/allocation/physical realization
    -> accepted Ribasim state
    -> next SWAP exchange trial
```

A rejected SWAP trial may not alter the management target or accepted Ribasim state.

### E. COUPLED_MODE_CONTROL_MAPPING

The fixed-level supply trigger represented by `WLDIP`, `INTWL` and related period scheduling is not a soil constitutive law. In coupled mode it must be expressed as explicit control/demand semantics against Ribasim-owned state. The exact mapping remains to be qualified and must not be assumed equivalent merely because Ribasim has a level-demand concept.

### F. STANDALONE_SWAP5_RETAINED

F-CI52 restricted fixed-weir physics remains a valid standalone SWAP5 capability under its admitted envelope. SW-RIB-SWM01 does not retire it.

Required future application-level invariant:

```text
surface_water_state_owner = SWAP_FIXED_WEIR
                         XOR EXTERNAL_RIBASIM
```

A coupled configuration that activates both owners for the same physical surface-water store must fail closed.

### G. LEGACY_INPUT_ADAPTER_CANDIDATE_RETIRE

Legacy file-driven period indices and parser/container responsibilities may become adapter-only or retire after typed mapping is proven. Examples include `NMPER`, `IMPER_4B`, `IMPER_4C`, `IMPER_4D`, `IMPER_4E1`, `IMPER_4E2`, `IMPPHASE`, `IMPTAB`, `IMPEND`.

This class never authorizes deletion of the physical or management behaviour that those inputs configured.

### H. UNRESOLVED

Any remaining legacy symbol or branch whose physical meaning cannot be bound from exact authority remains `UNRESOLVED`. In particular, broad switches such as `SWSRF` and any hidden interaction not covered by the bounded evidence above remain open until exact-source reconstruction or an accepted equivalent authority closes them.

## Immediate consequences

1. Whole-file retirement of `surfacewater.f90` remains prohibited.
2. The first external-owner equivalence test should not start with the full automatic-management feature set.
3. The qualified F-CI52 restricted fixed-weir process is the appropriate current SWAP5 oracle for the first real-Ribasim external-owner test.
4. The first test must use a profile in which SWAP's internal surface-water state is **not** active in the candidate route; it exists only as the comparator/oracle.
5. Automatic soil-state-driven weir control is a later, separate coupling-policy test because it crosses the accepted-state boundary.

## Test sequence

- **Q1A:** fixed-weir external-owner physical equivalence, no supply, real Ribasim.
- **Q1B:** bounded level-triggered supply realization.
- **Q2:** soil-state-driven automatic management policy and accepted-state rollback/replay.
- **Q3:** active signed SWAP drainage/infiltration exchange with Ribasim state ownership.
- **Q4:** retirement decision for remaining legacy container/parser responsibilities.

No Q-stage may silently broaden the production admission of F-CI52 or the current Ribasim management coupling.


## Exact-source reconciliation with F-PM08D

After the first SW-RIB-SWM01 inventory was frozen, the earlier F-PM08D readiness line was recovered and bound as read-only prior authority. That line had already reconstructed the byte-exact SWAP 4.3.1 `surfacewater.f90` at source-location level. The inventory can therefore be sharpened beyond parameter-name inference.

The relevant exact-source conclusions are:

- `SWST` is the authoritative conserved secondary surface-water storage in simulated mode; `WLS` is derived from that storage, not a second independent state.
- `WLSTAR` is genuine continuation-critical control memory for automatic management.
- `WLSBAK` and `OSSWLM` belong to numerical continuation/policy, not physical surface-water state.
- the extended drainage/infiltration law is stateless SWAP process physics;
- the legacy availability limiter is a **separate state-dependent coupling constraint** based on surface-water storage plus maximum supply;
- the fixed-weir balance has explicit drainage, rapid drainage, supply, discharge and top-surface exchange terms;
- the automatic-weir target policy observes groundwater level, total soil air volume and a selected pressure head;
- the legacy automatic capacity branch contains a documented SWQHR1/SWQHR2 head-selection asymmetry and must not be silently copied into a new coupling.

This changes one ownership class materially. In Ribasim-coupled mode the constitutive drainage/infiltration response stays in SWAP, but the legacy availability limiter cannot remain hidden inside SWAP because the quantities that make the transfer feasible, surface-water storage and available supply, are owned by Ribasim. The coupled route therefore needs:

```text
SWAP unconstrained signed exchange request
    -> coupling feasibility / Ribasim availability
    -> one authoritative realized signed exchange
    -> one mass booking on each side with opposite sign
```

That distinction prevents both double storage and double limiting.

### Refined automatic-management split

The automatic target-selection policy can move to the coupler while preserving its accepted-state inputs and target memory. The **hydraulic realization and capacity** of that target belongs to Ribasim. This is intentionally not defined as byte-for-byte reproduction of the legacy capacity branch, because F-PM08D5 already identified a source discrepancy there. Any behavioural change must be qualified explicitly rather than hidden as an implementation detail.

The bound prior authority is recorded in `integration/research/SW_RIB_SWM01_FPM08D_RECONCILIATION.json`.


## Primary versus secondary surface-water semantics

The exact F-PM08D source reconstruction also sharpens what the legacy SWAP "surface-water box" actually is.

- `SWSEC=1`: the secondary water level is prescribed forcing. There is no conserved `SWST` surface-water state.
- `SWSEC=2`: the **secondary** surface-water system owns conserved storage `SWST`; `WLS` is derived from that storage.
- where a primary system is configured, `WLP` is a prescribed primary-water-level forcing used by the drainage/exchange calculation. It is not part of `SWST`.
- the prepared storage relation `STTAB` aggregates secondary open-channel geometry only.

The Ribasim-coupled target should therefore not expose one undifferentiated "surface-water level" to SWAP. It needs an explicit mapping from Ribasim network entities to the water-level view required by each SWAP exchange level/order. A primary watercourse and the simulated secondary store can both be Ribasim-owned, but their SWAP-side roles remain distinct.

This also narrows the retirement question: the candidate for removal in external-owner mode is specifically legacy ownership of the **secondary storage/control subsystem**, not every surface-water-related input to the drainage law.
