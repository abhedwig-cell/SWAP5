# PPA-WU04-A Black evaporation reduction admission

Date: 2026-09-19

Status: **QUALIFIED / READY FOR CANONICAL ADMISSION**

Qualified production head: `f1fd0fa5633cea1fa5f3870eb2aa7b236d40a938`

Qualification: workflow **35438366101**, job **105884808295**, PASS.

## Scope

PPA-WU04-A is the bounded production migration of legacy `SWREDU=1` Black bare-soil evaporation reduction. It implements the source-bound PPA-WU04 transaction contract without changing solver algorithms, solver selection, groundwater-coupler semantics, SWREDU=2 or interception physics.

The admitted continuation state is exactly one scalar, `LDWET`.

## Scientific equation authority

The B1.11 authority remains the corrected SWAP 4.3.1 source identity frozen by PPA-WU04. The Black branch is equivalent to legacy `MOD_meteo.f90:reduceva(task=2)`:

```text
dry:
  empreva = min(peva,
                cofred * (sqrt(ldwet + dt) - sqrt(ldwet)) / dt)
  candidate_ldwet = ldwet + dt

ponded:
  empreva = peva
  candidate_ldwet = 0
```

A wetting reset is represented as an explicit event at a transaction-span boundary. The target implementation does not reproduce the legacy hidden calendar predicate. The source-window/calendar layer must decide whether a wetting reset event exists before entering this process.

## Transaction semantics

`LDWET` is process continuation state. It is neither hydraulic state nor worker scratch.

For every physical trial:

1. the trial starts from the committed transaction checkpoint;
2. the Black reduction is evaluated for that trial's actual `t0/t1` and therefore its actual `dt`;
3. the dynamic top-boundary provider consumes the resulting empirical demand;
4. the hydraulic solve owns actual evaporation and water-mass accounting;
5. candidate `LDWET` is copied into the transaction candidate only after the hydraulic solve converges;
6. a rejected or explicitly discarded candidate leaves committed `LDWET` unchanged.

This removes the legacy control-flow hazard in which `reduceva()` mutated `LDWET` before the SoilWater nonconvergence retry loop.

## Runtime composition

The implementation adds the option-discriminated optional-state layout
`FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION`.

The committed state family `fmr_b110_black_evaporation_state_t` extends the existing hydraulic physical-state carrier with a distinct Black process-state component. Generic committed restart serialization therefore transports `LDWET` exactly, while the restart contract rejects BASE versus SWREDU=1 layout substitution.

The existing B110 dynamic top-boundary solver provider remains the actual surface-water-mass owner. PPA-WU04-A does not create an evaporation ledger or subtract `empreva` independently.

The outer application adapter consumes the already-admitted PPA-WU03 common forcing result, retains raw precipitation/irrigation and potential evaporation demands, and deliberately neutralizes the old pre-resolved fixed top flux. Dynamic top forcing is reconstructed inside each physical transaction trial.

## Qualification evidence

Run 35438366101 passed at both `-O0` and `-O2`, with identical stable output. The gate includes:

- exact Black source-equation cases across multiple `LDWET` and `dt` values;
- explicit wetting-reset and ponding-reset oracles;
- deterministic A/B/A replay;
- fail-closed invalid inputs;
- production application reachability through the PPA bootstrap;
- hard mass closure at `1e-12`;
- proof that a discarded trial does not mutate committed `LDWET`;
- changed-`dt` retry candidate identity against a direct trial from the same checkpoint;
- exact bit-level `LDWET` restart roundtrip;
- fail-closed BASE/SWREDU=1 restart-layout mismatch;
- PPA-WU01 behavioral preservation;
- PPA-WU03 behavioral preservation;
- preregistered production-delta enforcement.

The temporal tolerance used by the qualification fixture is deliberately not the scientific acceptance criterion for this workunit. Black reduction introduces a time-varying demand rate, so a zero full-versus-two-half hydraulic tolerance would conflate timestep-control policy with the process migration. Mass closure, rollback, restart and source-equation identity remain independently hard-gated.

## Preservation interpretation

A number of older repository workflows are expected to fail on this PR because they encode historical immutability conditions such as exact serialized-backend blob identity or a prohibition on any `src/**` delta. Examples include publication experiment freeze gates, F-CI72/F-CI79 moving-preservation checks and older postimage reconciliations.

Those failures are **successor signals**, not evidence that PPA-WU04-A changed the preserved behavior. PPA-WU04-A therefore does not rewrite unrelated publication, EB, solver or governance locks. The direct predecessor behavior is re-executed in the WU04-A qualification build, and canonical governance can supersede historical blob locks against the eventual admitted postimage.

## Admission boundary

PPA-WU04-A may claim restricted typed production availability for `SWREDU=1`, transactional `LDWET`, exact committed-boundary restart, retry-local recomputation and hydraulic ownership of actual evaporation.

It does not claim `SWREDU=2`, `SWINTER=1/2`, legacy meteorological file/calendar ingestion, Black composition with snowmelt/runon, Black composition on groundwater mode 5, RossFast composition, or any new solver/coupling capability.
