# PPA-WU04-B Boesten-Stroosnijder evaporation admission

Date: 2026-09-19

Status: **QUALIFIED / READY FOR CANONICAL ADMISSION**

Qualified production head: `eb0e635975b77ec92084e1416038b1bc1f8232bc`

Qualification: workflow **35439112147**, job **105886744366**, PASS.

## Scope

PPA-WU04-B is the bounded production migration of legacy `SWREDU=2` Boesten-Stroosnijder bare-soil evaporation reduction. It reuses the transaction, forcing and hydraulic ownership seams admitted by PPA-WU04-A and does not modify solver algorithms, solver selection, groundwater coupling, SWINTER physics or Black reduction.

The persistent continuation state is the atomic pair `SPEV/SAEV`.

## Source equation

For a nonponded trial of duration `dt`, with net wetting rate `W = nrai + nird`:

```text
if W < PEVA:
    SPEV1 = SPEV0 + (PEVA - W) * dt
    if SPEV1 < COFRED^2:
        SAEV1 = SPEV1
    else:
        SAEV1 = COFRED * sqrt(SPEV1)
    EMPREVA = (W * dt + SAEV1 - SAEV0) / dt
else:
    EMPREVA = PEVA
    SAEV1 = max(0, SAEV0 - (W - PEVA) * dt)
    if SAEV1 < COFRED^2:
        SPEV1 = SAEV1
    else:
        SPEV1 = (SAEV1 / COFRED)^2
```

With ponding, `EMPREVA=PEVA` and both continuation scalars reset exactly to zero.

These equations are traced independently to `SWAP-model/SWAP@07d74a82e9ba0465ec81a74e4d82b3dc03d856d9`, `src/atmosphere/et.f90:reduceva(task=2)`, in addition to the frozen B1.11/PPA-WU04 authority.

## Bounded COFRED profile

The production slice admits `0 < COFRED <= 1`.

Legacy input validation permits zero, but the exact rewetting branch contains `(SAEV/COFRED)^2`. At `COFRED=0`, a zero-consistent state can therefore evaluate `0/0`. PPA-WU04-B does not silently repair or reinterpret that legacy edge case. It fails closed at zero pending separate physics/bugfix authority.

## Transaction and restart semantics

`SPEV` and `SAEV` form one option-specific continuation state:

1. both are read from the same committed checkpoint;
2. both candidate values are evaluated for the actual trial `dt`;
3. both are discarded together on rejected or explicitly discarded trials;
4. changed-`dt` retries recompute from the same committed pair;
5. both commit atomically with the accepted hydraulic state;
6. restart persists and restores the pair exactly at accepted transaction boundaries;
7. BASE, Black and Boesten restart layouts are not interchangeable.

No `SPEV`, `SAEV` or `EMPREVA` quantity is entered as an independent water-mass contribution.

## Runtime composition

PPA-WU04-B introduces `FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION` and the state family `fmr_b110_boesten_evaporation_state_t`.

The WU03-to-Boesten adapter carries resolved precipitation and surface irrigation as the wetting-rate inputs. Snowmelt and runon remain outside this restricted slice and must be zero. The previous fixed top flux is neutralized so that the existing B110 dynamic top-boundary provider remains the sole owner of accepted actual surface evaporation and top water exchange.

Black and Boesten are mutually exclusive production options. No runtime option switching is admitted.

## Qualification

Workflow 35439112147 passed at both `-O0` and `-O2` with identical stable output. The qualification covers:

- exact drying equation;
- exact rewetting equation;
- exact ponding pair reset;
- deterministic A/B/A replay;
- explicit rejection of `COFRED=0`;
- production application reachability;
- hard water-mass closure at `1e-12`;
- rejected-trial committed-pair immutability;
- changed-`dt` retry equality with a direct same-`dt` trial from the same committed pair;
- exact SPEV/SAEV restart roundtrip;
- BASE/Black/Boesten restart-layout mismatch rejection;
- PPA-WU04-A Black behavioral preservation;
- PPA-WU01 and PPA-WU03 behavioral preservation;
- preregistered production-delta enforcement.

Older repository workflows that assert immutable serialized-backend blobs or prohibit all new `src/**` production successors are expected to signal supersession on this PR. They are not used as scientific evidence for or against the WU04-B process implementation.

## Admission boundary

PPA-WU04-B may claim restricted typed production availability for `SWREDU=2` with `0 < COFRED <= 1`, atomic transactional/restart `SPEV/SAEV`, retry-local recomputation and unchanged hydraulic ownership of actual evaporation.

It does not claim `COFRED=0`, SWINTER=1/2, legacy weather/calendar parsing, snowmelt/runon composition, groundwater mode 5, RossFast composition or any solver/coupling change.
