# RIBASIM-DUMMY-03 head-dependent exchange diagnostic

## Purpose

DUMMY-02 established the management rule for a prescribed forecast and actual
groundwater exchange. DUMMY-03 asks the next narrower question:

> What changes when the groundwater exchange itself depends on the Ribasim
> Basin level and groundwater head?

The work unit remains a research oracle. It does not implement a MODFLOW
boundary package.

## Linear exchange surrogate

The signed groundwater exchange volume over one coupling window is

```text
V_ex = C * dt * (h_basin - h_gw)
```

where:

- `C` is a conductance with units area/time;
- `dt` is the coupling-window duration;
- `h_basin` is the Ribasim Basin level;
- `h_gw` is the groundwater head.

Sign convention:

```text
V_ex > 0  : Basin -> groundwater infiltration
V_ex < 0  : groundwater -> Basin drainage
V_ex = 0  : no exchange
```

This choice is intentionally analogous to the linear head-difference principle
used by a MODFLOW General-Head Boundary. It is not a claim of GHB, RIV, SFR or
other package equivalence. Current MODFLOW documentation describes
head-dependent boundary flow as proportional to a head difference through a
conductance.

External references checked for the physical form:

- https://docs.modflow.ai/mf6/mf6suptechinfo.pdf
- https://pubs.usgs.gov/tm/06/a55/tm6a55.pdf

## One-pass experiment

For one window:

1. use committed Basin level with forecast groundwater head to obtain forecast
   exchange;
2. allocate SWAP/UserDemand through the qualified DUMMY-02 rules;
3. use the same committed Basin level with actual groundwater head to obtain
   one-pass actual exchange;
4. realize physical exchange and managed delivery through DUMMY-02;
5. do not commit;
6. recalculate the same head-dependent exchange using the realized Basin end
   level and actual groundwater head.

The endpoint exchange residual is

```text
R_ex = V_ex_one_pass - V_ex_at_realized_end_level
```

No acceptance tolerance is attached to `R_ex` in this work unit.

## What the residual means

A nonzero residual says only that the physical exchange evaluated from the
committed start level differs from the exchange implied by the realized end
level under the same linear relation.

It does **not** establish that the endpoint value is the correct time-integrated
flux. It also does not prove that a production coupling must iterate. Those
questions require a separately defined temporal integration and fixed-point
contract.

This distinction is deliberate. DUMMY-03 is a state-dependence diagnostic,
not an iterative coupling algorithm.

## Canonical late-conflict case

Use:

```text
Basin area                     100 m2
start storage                  100 m3
start Basin level                1 m
SWAP request                    50 m3
C                               60 m2/time
dt                               1 time
forecast groundwater head        1 m
actual groundwater head          0 m
```

Forecast exchange:

```text
60 * 1 * (1 - 1) = 0 m3
```

so all 50 m3 can be allocated.

One-pass actual exchange:

```text
60 * 1 * (1 - 0) = 60 m3 infiltration
```

DUMMY-02 therefore leaves 40 m3 for managed delivery and records 10 m3
realization shortage.

The realized end storage is zero, hence the realized end level is zero. If the
same exchange law is evaluated at that endpoint:

```text
60 * 1 * (0 - 0) = 0 m3
```

and the endpoint exchange residual is 60 m3.

That is intentionally a severe case. It demonstrates that a physically
state-dependent exchange cannot in general be treated as an arbitrary
same-window constant without an explicit temporal/coupling interpretation.

## Decision boundary

If the preregistered tests pass, DUMMY-03 establishes only:

- correct sign and scaling of the linear head surrogate;
- a physically state-derived version of the DUMMY-02 late conflict;
- a measurable endpoint-consistency residual when Basin level changes;
- zero endpoint residual in the zero-state-change control;
- independence of the start-state physical exchange from management demand;
- fail-closed preservation when the head-derived infiltration is physically
  impossible for available Basin water.

The next work unit may then compare explicit, predictor-corrector and
fixed-point formulations under a frozen temporal exchange definition.
