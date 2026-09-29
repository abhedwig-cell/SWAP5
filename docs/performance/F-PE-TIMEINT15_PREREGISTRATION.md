# F-PE-TIMEINT15 preregistration — all-storage conservative BDF2 and physical interval flux quadrature

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`

Parent authority:

- TIMEINT13: extrapolated-conductivity BDF2 retains near-second-order behavior on smooth fixed-flux trajectories and has near-KLAG work on completed dynamic-top cases.
- TIMEINT14/14A: the large ordinary physical interval ledger under BDF2 is exactly the BDF2 soil-storage history term. There is no hidden mass leak, but the standard multistep storage equation is incompatible with SWAP5's unchanged one-step physical transaction mass identity.

## Purpose

Test whether the BDF2 modernization path can retain:

1. physical endpoint storage as the published storage;
2. exact per-interval physical water balance;
3. second-order temporal accuracy;
4. predicted-conductivity cost advantages;

by applying the multistep time discretization consistently to every storage term in the controlled water system and by using a BDF2-consistent quadrature for external interval fluxes.

Research-only. No production source changes.

## Constant-step conservative formulation

For constant-step BDF2:

`a0=3/2, a1=-2, a2=1/2`.

For any storage component `X`:

`a0 X_(n+1) + a1 X_n + a2 X_(n-1) = h G_(n+1)`.

Because `a0+a1+a2=0`:

`Delta X_n = (h/a0) G_(n+1) + (a2/a0) Delta X_(n-1)`.

For constant-step BDF2:

`Delta X_n = (2/3) h G_(n+1) + (1/3) Delta X_(n-1)`.

This recurrence defines the candidate interval quadrature for a physical flux component.

It does not relabel numerical history as physical storage.

## Soil storage

Use the already qualified TIMEINT13 mechanism:

- BE bootstrap;
- BDF2 soil-water storage thereafter;
- history-predicted nodal conductivity;
- conductivity fixed during Newton;
- exact candidate theta(h) and C(h);
- corrected BOFEK00 fixed-K dynamic-top route.

## Surface ponding storage

TIMEINT13 advanced ponding with the existing one-step surface balance while soil storage used BDF2.

TIMEINT15 instead applies the same temporal coefficients to ponded surface storage.

For zero evaporation and controlled rainfall:

`a0 P_(n+1)+a1 P_n+a2 P_(n-1) = h (rain + q_top - q_runoff)`.

The generalized dynamic-top algebra is derived from this equation.

### Flux route

Let `q0` be net atmospheric water input and `P_n,P_(n-1)` accepted ponding storage.

The top soil flux required for a candidate zero-ponding endpoint is:

`q1 = (a1 P_n + a2 P_(n-1))/h - q0`.

For BE bootstrap this reduces exactly to the current production formula:

`q1 = -q0 - P_n/h`.

### Ponded head route without runoff

Let:

`p1 = K_surface/d_surface * h`.

Then:

`P_(n+1) = [-a1 P_n - a2 P_(n-1) + q0 h - K_surface h + p1 h_top] / (a0+p1)`.

### Linear runoff route

For `RSROEXP=1`:

`P_(n+1) = [-a1 P_n - a2 P_(n-1) + q0 h - K_surface h + p1 h_top + (h/RSRO) PMAX] / (a0+p1+h/RSRO)`.

Runoff rate:

`q_runoff = max(0, (P_(n+1)-PMAX)/RSRO)`.

Runoff interval mass is not assumed equal to `h*q_runoff` after bootstrap. It is published through the integrator-consistent recursive interval quadrature below.

### Surface Jacobian derivative

For fixed top-node conductivity:

- no-runoff head route:
  `dP_(n+1)/dh_top = p1/(a0+p1)`;
- linear-runoff route:
  `dP_(n+1)/dh_top = p1/(a0+p1+h/RSRO)`.

For BE bootstrap these reduce exactly to the BOFEK00-qualified production derivatives.

## Physical external interval flux quadrature

For each external physical flux rate component `f_(n+1)`, define its physical interval integral recursively:

`I_n = (h/a0) f_(n+1) + (a2/a0) I_(n-1)`.

Components in the controlled bank:

- rainfall input;
- runoff output;
- bottom exchange.

The BE bootstrap uses:

`a0=1, a2=0`

so `I_1=h*f_1`, exactly matching current one-step semantics.

The published physical interval mass ledger remains:

`(Ssoil_(n+1)+P_(n+1)) - (Ssoil_n+P_n) - I_rain + I_runoff - I_bottom`.

No BDF2 history storage term is added to physical storage.

## Numerical history ownership

The candidate requires numerical history:

- previous accepted soil theta;
- previous accepted conductivity;
- previous accepted ponding depth;
- previous accepted interval integral per external flux component;
- previous accepted dt for later variable-step generalization.

These are integrator-history variables, not physical storage and not independently publishable mass.

A rejected trial may not modify them.

## P0 — BE reduction / provider equivalence

Before BDF2 exposure, prove the generalized test-only dynamic-top provider reduces to production BOFEK00 semantics when:

- `a0=1`;
- `a1=-1`;
- `a2=0`.

Use a deterministic grid spanning:

- dry flux route;
- near switch;
- ponded no-runoff route;
- linear-runoff route;
- representative B01/B12/O05/O14 top hydraulic parameters.

Frozen P0 gates:

1. same status and regime for every point;
2. max absolute surface head difference <=1e-12 cm;
3. max absolute top-flux difference <=1e-12 cm/day;
4. max absolute candidate ponding difference <=1e-12 cm;
5. max absolute runoff-depth difference <=1e-12 cm;
6. max absolute surface-head derivative difference <=1e-12 where available.

If P0 fails, stop.

## P1 — constant-step dynamic-top conservative mechanism

Use the same 12 TIMEINT13 dynamic-top cases:

- B01/B12/O05/O14;
- MOIST h0=-50 cm, rain=8 cm/day;
- WET h0=-20 cm, rain=12 cm/day;
- POND h0=-5 cm, rain=25 cm/day;
- dt=0.005 d;
- horizon=0.12 d;
- MAXIT=8;
- BALTOL02;
- BE bootstrap then constant-step extrapolated-K BDF2.

All trajectories are reported, including incomplete cases.

Frozen P1 gates for mechanism qualification:

1. at least 10/12 trajectories complete;
2. all completed steps have max physical interval ledger <=5e-8 cm;
3. every completed trajectory cumulative physical ledger <=5e-8 cm;
4. BE bootstrap physical ledger <=5e-8 cm;
5. no nonfinite state or flux integral;
6. rainfall and runoff interval integrals are nonnegative;
7. no numerical-history term is included in published physical storage;
8. no alternative-solver pathology.

Known O05/POND common-domain and O14/POND candidate robustness failures are not silently removed. Completion remains reported separately from conservation.

## P2 — smooth second-order preservation

Only if P0 and P1 conservation gates pass.

Use the TIMEINT13 smooth fixed-flux bank and dt ladder:

- B01 and O05;
- infiltration 2 and 4 cm/day;
- dt 0.010, 0.005, 0.0025, 0.00125 d;
- horizon 0.04 d.

Frozen gates:

1. 4/4 ladders complete;
2. median refined top-head temporal order >=1.6;
3. at least 3/4 individual refined orders >=1.5;
4. storage spread <=1e-10 cm;
5. no conductivity clamps;
6. candidate work per step <=1.05 times TIMEINT13 extrapolated-K BDF2.

## Interpretation boundary

P1 proves a conservative constant-step mechanism only.

It does not yet qualify:

- variable-step recursive quadrature;
- hard-event restart;
- adaptive control;
- production dynamic-top execution;
- removal of user DTMIN/DTMAX.

## Stop rule

If the conservative formulation cannot close the unchanged physical interval ledger while retaining the TIMEINT13 endpoint/order mechanism, close the multistep route.

Do not relax the physical mass gate.

## Possible outcomes

- `CONSERVATIVE_BDF2_PHYSICAL_INTERVAL_MECHANISM_QUALIFIED`;
- `BLOCKED_DYNAMIC_TOP_SURFACE_MULTISTEP_ROBUSTNESS`;
- `CLOSED_CONSERVATIVE_BDF2_LEDGER_FAIL`;
- `CLOSED_CONSERVATIVE_BDF2_ORDER_FAIL`.

## Production boundary

No production `src/**` changes.

`LEGACY_NUMERICS` remains default.
