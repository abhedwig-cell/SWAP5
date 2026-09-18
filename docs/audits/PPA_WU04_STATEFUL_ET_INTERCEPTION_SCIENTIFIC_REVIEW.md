# PPA-WU04 Stateful ET/interception scientific review

Date: 2026-09-18

Status: `SCIENTIFIC_TRANSACTION_AUTHORITY_FROZEN / IMPLEMENTATION_HELD`

Canonical reconcile base: `integration/f-ci-canonical@8d78c305d12939bb061bbcb248b8a33730494f34`.

## Purpose

PPA-WU04 resolves the remaining scientific and transaction questions around legacy
`SWINTER=1/2` and `SWREDU=1/2` before any production migration.

This workunit does **not** implement these options. Its output is the source-bound
state/event/restart/rollback contract that a later implementation must satisfy.

The central conclusion is that the four options do not form one state family:

- `SWINTER=1/2` have no persistent physical interception storage under the
  B1.11 authority. Their difficult state-like concern is the provenance and
  partial consumption of a nonlinear source-window aggregate.
- `SWREDU=1` has one true continuation scalar, `LDWET`.
- `SWREDU=2` has one atomic continuation pair, `SPEV/SAEV`.

That distinction is essential for restart and retry correctness.

## B1.11 authority binding

The current corrected reference is SWAP 4.3.1 B1.11 with member-manifest SHA-256

`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

B1.11 differs from B1.10 only through SWAP-011, whose targets are:

- `MOD_MvG_functions.f90`;
- `WC_K_models_04_11.f90`;
- `MOD_RIA.f90`.

Those targets are hydraulic constitutive/Jacobian authority and do not alter
`ETpot`, `interception_daily`, `ProcessMeteoDT` or `reduceva`.

The earlier admitted SWAP-006 change does touch `MOD_meteo.f90`, but only the
dynamic-crop meteorological data-loading scan around line 260. It does not alter
the ET/interception/reduction routines used here. The B1.11 corrected
`MOD_meteo.f90` identity is therefore

`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`.

Other source identities relevant to this review remain:

- `swap.f90 = 39d1cbd93dbd0f99505e92af94ac0d23bddb496529c280397d2d7c2b7eb9b58a`;
- `swapoutput.f90 = 9fe6d939bd5213777a8a63a9b99ce154cd1aaa0e15b74895e41a33c2acac05ee`;
- `variables.f90 = 327a064ca74f6c4bebc327a38de367824c7fe535baa1a8611879f9a6a479c856`;
- `interface_plant.f90 = 2295a17a9597f016ed8ec538eede7c9400da0819914e96f7d641597ce71f64df`;
- `boundtop.f90 = 69d0d4703af64212d7200898f12568853d015cea29cb45f81915bece15b63c04`;
- corrected `MOD_cropdevelopment.f90 = aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210`.

PPA-WU04 therefore treats F-PM06's source-bound ET decomposition as valid
B1.11 semantic authority rather than as historical B1.10-only guidance.

## Existing owner boundaries retained

PPA-WU04 changes none of the existing production ownership decisions.

Potential ET quantities remain demands. They are not accepted water-mass sinks.

Actual surface evaporation remains owned by the hydraulic/top-boundary process.
Actual root-water uptake remains owned by the root-water-uptake process.
Crop biology remains crop-owned. Snow storage remains snow-owned.

No ET or interception implementation may acquire HeadCalc, Newton, Jacobian,
crop-biomass, snow-storage or groundwater-coupler ownership through this review.

## SWINTER=1 and SWINTER=2: aggregate authority, not storage state

Legacy `interception_daily()` computes `aintc` over a source forcing window.
For SWINTER=1 the method is Von Hoyningen-Hune/Braden; for SWINTER=2 it is Gash.
`ProcessMeteoDT` then apportions the aggregate into the active precipitation
interval, producing trial quantities such as `aintcdt`, net precipitation and
wet-canopy fraction.

The persistent physical state for both methods is therefore empty.

`aintc` is not canopy-water storage. It is an accepted/source-window process
aggregate with forcing provenance.

### Why this matters for numerical retries

These formulas are source-window nonlinear. A smaller Richards retry interval
must not silently become a new interception source window.

The following is therefore prohibited:

1. evaluate the daily/window formula on a full forcing window;
2. encounter a hydraulic retry;
3. re-evaluate the nonlinear formula independently on each smaller retry span;
4. sum the new results.

That changes the physics.

The allowed pattern is:

1. identify the immutable forcing/source window;
2. evaluate or reproducibly reconstruct its aggregate `aintc`;
3. apportion that same aggregate to numerical subspans;
4. publish only the accepted apportioned fraction;
5. leave aggregate-consumption progress unchanged for rejected trials.

This keeps physical forcing-window semantics separate from numerical timestep
policy.

### Mid-source-window restart

Although SWINTER=1/2 have no physical process storage, a restart can occur after
only part of the source window has been accepted.

The restart/runtime layer must therefore preserve enough provenance to know:

- source-window identity and bounds;
- the exact aggregate `aintc`, or immutable inputs sufficient to reproduce it;
- how much of the aggregate has already been accepted/apportioned.

This continuation metadata belongs to the forcing/runtime cursor and accepted
aggregate receipt. It must **not** be misclassified as canopy physical state.

A restart inside a source window must neither reapply an already accepted
interception amount nor lose the remaining amount.

### Mass identity

Gross precipitation/sprinkling, intercepted amount and net input are one
transfer identity. A migration may not ledger both gross and net precipitation
as independent accepted water inputs.

The sum of accepted apportioned interception over a fully consumed source
window must equal the frozen window aggregate, subject only to floating-point
representation.

## SWREDU=1: Black reduction and LDWET

F-PM06 binds `LDWET` as true restart continuation state for `SWREDU=1`.

The process consumes potential bare-soil evaporation, explicit wetting inputs
and a clean surface-water/ponding view, and produces:

- current empirical soil-evaporation demand `empreva`;
- trial candidate `LDWET`.

`empreva` remains a demand. The hydraulic top-boundary process decides actual
soil evaporation and owns the accepted water-mass flux.

### Legacy retry hazard

In legacy control flow, `Meteo(3)` and `reduceva()` run before the
SoilWater nonconvergence retry loop. `reduceva()` mutates `LDWET` before it
is known whether the hydraulic trial will be accepted.

That mutation order is historical control flow, not target transaction
semantics.

SWAP5 must instead:

1. checkpoint committed `LDWET`;
2. compute `empreva` and candidate `LDWET` for the trial span;
3. run the hydraulic transaction;
4. commit candidate `LDWET` only with the accepted physical interval;
5. discard it on rejection;
6. recompute any smaller retry from the same committed `LDWET`.

A rejected candidate can never become hidden history for the next retry.

### Restart

`LDWET` is persisted exactly for an accepted transaction boundary. It may not
be reconstructed from the hydraulic pressure-head profile.

The restart record must be option-discriminated as `SWREDU=1`; arbitrary
runtime switching to a different reduction model is outside this authority.

## SWREDU=2: Boesten-Stroosnijder and SPEV/SAEV

For `SWREDU=2`, `SPEV` and `SAEV` are true legacy restart continuation
state.

They form one atomic state pair. A target implementation must never commit or
restore one without the other.

The same checkpoint/trial/commit rules apply as for SWREDU=1:

- read the pair from committed state;
- create one trial-local candidate pair;
- discard both on rejection;
- recompute a smaller retry from the original committed pair;
- persist the pair only at accepted transaction boundaries.

Neither state delta is itself a water-mass flux. The authoritative water removal
remains accepted actual evaporation from the hydraulic/top-boundary owner.

## Wetting and ponding events

For both SWREDU options, wetting and surface ponding are explicit process inputs,
not hidden global state.

A forcing adapter/runtime must split or otherwise represent wetting onset at an
explicit event boundary. A process implementation must not infer a hidden
calendar-day transition.

When the legacy ponded-surface branch resets empirical dry-surface memory, the
candidate reset is transactional. If the enclosing physical trial is rejected,
the committed pre-ponding reduction state remains unchanged.

## Restart and transaction topology

The minimal target state layout is:

| option | physical persistent state | restart continuation |
|---|---|---|
| SWINTER=1 | none | source-window provenance/progress in forcing runtime |
| SWINTER=2 | none | source-window provenance/progress in forcing runtime |
| SWREDU=1 | LDWET | exact scalar at accepted boundary |
| SWREDU=2 | SPEV, SAEV | exact atomic pair at accepted boundary |

These states must not be copied into crop owner state, hydraulic state or worker
scratch.

The outer transaction ordering is:

```text
committed ET/reduction state
        |
        +--> interception source-window result / apportionment
        |
        +--> trial SWREDU candidate and empreva
        |
        +--> hydraulic top-boundary trial
        |
        +--> accept?
              | no  -> discard all trial state and accepted-progress deltas
              | yes -> atomically commit SWREDU state,
                       accepted interception progress,
                       actual evaporation mass receipt,
                       normal FMR committed hydraulic state
```

The interception aggregate itself may be deterministically recomputable. Its
**accepted progress** is not allowed to advance on a rejected trial.

## Required qualification for later implementation

Every implementation slice must carry its own source oracle and production
qualification. PPA-WU04 itself does not authorize production code.

Common gates:

- exact B1.11-equivalent equation/result oracle;
- O0/O2 identity;
- A/B/A replay;
- rejected-trial committed-state immutability;
- failed-then-accepted retry from the same checkpoint;
- restart roundtrip;
- exactly-once accepted mass receipt;
- PPA-WU01 and PPA-WU03 preservation.

Additional SWINTER=1/2 gates:

- full-source-window aggregate oracle;
- conservation of the aggregate across numerical partitioning;
- restart in the middle of a source window without duplicate or lost aggregate;
- proof that the nonlinear formula is not independently reevaluated on retry
  subwindows.

Additional SWREDU=1/2 gates:

- option-specific minimal state layout;
- option-discriminated restart;
- source-bound wetting/ponding reset cases;
- retry with changed `dt` from the same committed checkpoint;
- no mass ledger entry for `empreva` or the empirical state delta.

## Frozen migration slicing

PPA-WU04 freezes four later production slices rather than implementing them.

1. **PPA-WU04-A, SWREDU=1 Black.**
   One-scalar `LDWET` transactional state plus restart. This is the recommended
   first slice because application relevance is high and the state topology is
   minimal.
2. **PPA-WU04-B, SWREDU=2 Boesten-Stroosnijder.**
   Atomic `SPEV/SAEV` continuation behind the same reduction interface.
3. **PPA-WU04-C, SWINTER=1.**
   VonHHBraden source-window aggregate with explicit provenance and mid-window
   restart accounting.
4. **PPA-WU04-D, SWINTER=2.**
   Gash source-window aggregate under the same runtime contract but with its own
   independent nonlinear scientific oracle.

The order is a migration-risk order, not a statement that the later methods are
less scientifically valid.

## Existing SWINTER=3 authority

The current Rutter implementation remains separate. PPA-WU04 neither alters nor
broadens its production admission.

That separation is deliberate: SWINTER=3 has a real physical canopy-water
storage scalar and event-to-full/empty semantics, while SWINTER=1/2 are
source-window aggregate methods without physical canopy storage.

## Review verdict

`SCIENTIFIC_TRANSACTION_AUTHORITY_FROZEN_IMPLEMENTATION_HELD`

The scientific ambiguity that blocked implementation is removed:

- persistent state is known exactly;
- aggregate provenance ownership is explicit;
- retry semantics are explicit;
- restart semantics are explicit;
- mass ownership is explicit;
- migration slices are bounded.

No production claim follows from this review. The next production unit may start
with PPA-WU04-A without reopening the broad ET source/state audit.
