# NUM-UNC P0B0 preregistration: lower-boundary exchange-reversal locator

Date: 2026-09-19
Timing: before any P0B numerical execution
Baseline authority: `integration/f-ci-canonical@187e30153c890151768e929170d14bb22af1d86d`

## Purpose

P0B tests a second hydrological-transition family after P0C closed as `THRESHOLD_PROXIMITY_ONLY`.

The mechanism was already part of the original NUM-UNC hypothesis family: transition between downward recharge/drainage and upward capillary support under a prescribed groundwater head.

This workunit does not use groundwater coupling. The lower boundary is a fixed prescribed pressure head, so coupling-window numerics, outer coupling tolerance and MODFLOW are outside scope.

## Reconciliation with the original P0 manifest

The prose P0 protocol already listed net bottom exchange upward/downward as a primary Experiment B inference. The first machine-readable manifest captured only the stress-timing labels. P0B0 corrects that machine-readable under-specification before any B data exist.

No new physical endpoint is introduced by this amendment.

## Physical case

Discovery material: B01.

Grid:

- 16 cell-centred cells;
- cell thickness 10 cm;
- total depth 160 cm;
- surface-to-first-node distance 5 cm;
- internal node distances 10 cm;
- bottom face 5 cm below the last cell centre.

Initial effective saturation:

[
S_e=0.85.
]

The initial pressure head is uniform and obtained from the B01 van Genuchten retention relation.

No root uptake, drainage, irrigation, snow, macropores or surface ponding process is active.

Top boundary is explicit prescribed flux.

## Forcing schedule

The flux amplitudes are inherited from P2E08 rather than selected from NUM-UNC outcomes.

Let (K_0) be the canonical B01 hydraulic conductivity evaluated at the initial (S_e=0.85).

Each forcing block lasts 0.0064 day.

Blocks 1 through 8 use the P2E08 WETTING factor:

[
q_{top}=+0.025K_0.
]

Blocks 9 through 32 use the P2E08 DRYING factor:

[
q_{top}=-0.005K_0.
]

Total horizon:

[
32	imes0.0064=0.2048 {m day}.
]

The physical forcing blocks will later be identical for N0 and N1.

## Continuation coordinate

The prescribed bottom pressure head is written as

[
h_{bot}=h_0+rac{Delta z}{2}+delta_h
]

where (h_0) is the uniform initial pressure head and (Delta z/2=5) cm is the distance from the last cell centre to the lower boundary.

The prospectively frozen search offsets are:

[
delta_h=(-100,-50,-25,0,25) {m cm}.
]

This is a fixed declared envelope. It is not widened after observing B0.

## Exchange quantity and sign

The solver-native bottom flux is used:

- (q_{bot}>0): water enters the soil profile from the lower boundary, interpreted as upward capillary support;
- (q_{bot}<0): water leaves the soil profile through the lower boundary, interpreted as downward recharge/drainage.

For prescribed-head mode 5, the current Reference binding materializes terminal (q_{bot}) from the accepted storage and boundary balance after the nonlinear state solve.

Therefore P0B treats exchange direction as a model-output regime classification but does not claim an independent typed mass-residual diagnostic for mode 5.

## Primary B0 classification

For the dry phase, blocks 9 through 32, define

[
Q_{dry}=sum_{j=9}^{32} q_{bot,j}Delta t.
]

Classification:

- `NET_DRAINAGE` if (Q_{dry}<0);
- `CAPILLARY_SUPPORT` if (Q_{dry}>0);
- `ZERO_WITHIN_REPRESENTATION` only if (|Q_{dry}|le 1024epsilon(1)max(1,|Q_{dry}|)).

B0 uses N0 only.

The first adjacent prospective offset pair whose classifications change between `NET_DRAINAGE` and `CAPILLARY_SUPPORT` defines the bracket.

If no bracket exists, P0B closes as `NO_TRANSITION_IN_DECLARED_ENVELOPE`. The offset envelope is not expanded.

If a bracket exists, bisection uses N0 only, at most 12 iterations, stopping early at relative/scale-normalised head-bracket width <= 0.001.

The frozen B- and B+ cases are defined additively, because the continuation coordinate is a pressure head:

- B- = (delta_h^* - 10) cm;
- B0 = (delta_h^*);
- B+ = (delta_h^* + 10) cm.

For a valid freeze B- must be `NET_DRAINAGE` and B+ must be `CAPILLARY_SUPPORT`. The ±10 cm offsets are not widened after observing results.

## Study admissibility

A route is admissible only when:

- every Reference solve reports `SW_SOLVE_CONVERGED`;
- no internal retry occurs;
- no alternative linear solver is called;
- all state and bottom-flux values are finite;
- water content remains inside the B01 constitutive range;
- the requested fixed step is retained;
- the solver uses bottom mode 5 and the same physical forcing history.

For each step, the bookkeeping identity

[
R_B = Delta S-Delta t(q_{bot}-q_{top})
]

is also evaluated. With no distributed source/sink this must close within (10^{-12}) cm.

This identity is a consistency check on the prescribed-head materialization path, not an independent PDE residual theorem.

## Data firewall

B0 may execute N0 only.

N1 may not be compiled into or executed by B0.

The B-, B0 and B+ bottom heads must be persisted before a B1 N0-versus-N1 comparison is preregistered.

## Kill interpretation

B0 is only a locator. It cannot support the NUM-UNC claim.

Even if B1 later changes exchange classification, a positive NUM-UNC mechanism requires preregistered trajectory amplification, not merely a sign flip close to (Q_{dry}=0).
