# F-PE-TIMEARCH04 Hupsel real-workload event context

Date: 2026-09-28

Status: `SUPPORTING_REAL_WORKLOAD_CONTEXT`

Canonical authority at assessment:

`integration/f-ci-canonical@b0269f6fe7e7cbfcf47095cd6d471eb2fb180036`

## Authority

The exact Hupsel fixture authority is recorded in:

`integration/f-app/F-APP03_HUPSEL_AUTHORITY_RESTORED.json`.

That authority identifies the official SWAP 4.3.1 Hupsel input `swap.swp` by SHA-256:

`a54d110efa0cf003b23537109a3aea83f17f941fa875a5de6aefd65291405b5b`.

The restored non-interfering reference trace contains:

- 1096 daily records;
- 32518 timestep records;
- exact normalized BAL/BLC preservation.

The same pinned Hupsel `swap.swp` is available through the already-authorized public rswap copy at commit
`c30f40227004191ca729f25cc35f500301cb4bab`.

## Relevant input configuration

The exact Hupsel input has:

- NPRINTDAY = 1;
- SWMETDETAIL = 0;
- SWRAIN = 0;
- SWRUNON = 0;
- SWMACRO = 0;
- SWIRFIX = 1 with one fixed irrigation event on 2002-01-05;
- DTMIN = 1e-6 d;
- DTMAX = 0.04 d;
- MAXIT = 30;
- MAXBACKTR = 3;
- SWKIMPL = 0.

## Event implications

### Output cadence

NPRINTDAY=1 means the output interval is 1 day.

Initialization rule:

`DTMAX = min(DTMAX, 1/NPRINTDAY)`

therefore leaves the numerical DTMAX unchanged:

`min(0.04 d, 1 d) = 0.04 d`.

For this Hupsel case, output-frequency mutation of DTMAX is inactive.

### Detailed meteorology

SWMETDETAIL=0.

Therefore:

- detailed-meteo DTMAX mutation is inactive;
- subdaily detailed-meteo event clipping is inactive.

### Detailed rainfall

SWRAIN=0.

Therefore the separate detailed-rain event sequence is inactive.

### Runon

SWRUNON=0.

Therefore runon event clipping is inactive.

### Macropore retry

SWMACRO=0.

Therefore the macropore-specific timestep recovery path is inactive.

### Daily boundaries

Daily meteorological ownership, output cadence and calendar day-end occur on the same daily time grid in this case.

They should not be counted as three independent event densities.

There can still be process work at a day boundary, but the unique hard-time boundary is daily.

### Irrigation

One fixed irrigation date exists.

This is a real process event, but its density is negligible compared with 32518 total timestep records.

## Quantitative context

The restored reference run contains:

`32518 / 1096 = 29.67`

timestep records per day on average.

A global DTMAX of 0.04 d by itself permits at most 0.04 d per numerical step and therefore requires at least:

`ceil(1 / 0.04) = 25`

steps to cover one full day even before considering:

- nonlinear difficulty;
- growth transients after clipping/retry;
- daily hard boundaries;
- crop/process events;
- other active physics.

The daily hard boundary occurs at most once per day.

Relative to the reference timestep count, 1096 daily boundaries correspond to only about:

`1096 / 32518 = 3.37%`

of timestep records.

This is not an exact attribution of which records were clipped by day-end. It is an upper-context ratio for unique daily boundary opportunities.

## Interpretation

For the exact Hupsel configuration, fine-grained output, detailed meteorology, detailed rainfall, runon and macropore event controls cannot explain the roughly 30 timestep records per day because those mechanisms are inactive.

The numerical DTMAX=0.04 d is structurally active throughout the run and alone imposes a 25-step/day lower bound on numerical stepping.

This supports the TIMEARCH03 finding that fixed DTMAX is a material operating limiter rather than only an emergency safety ceiling.

It does not prove that DTMAX may safely be removed. Physical accuracy and wet-transition evidence still require a replacement local accuracy mechanism.

## Consequence for TIMEARCH04

For this real workload:

- removing duplicate output-induced DTMAX mutation would provide no benefit because that mutation is inactive;
- decoupling output from physical stepping would also provide little direct benefit at NPRINTDAY=1 because output is only daily and coincides with the day grid;
- the more important architectural target is numerical proposal/accuracy ownership, not output scheduling;
- event-scheduler extraction remains valuable for clean ownership and for workloads with subdaily forcing/output, but it is not the main Hupsel performance lever.

