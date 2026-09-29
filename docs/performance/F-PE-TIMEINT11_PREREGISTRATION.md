# F-PE-TIMEINT11 preregistration — two-stage L-stable SDIRK2 embedded-pair feasibility

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@2bf6c717647dc3fce685d5b46af5a8d859d2255a`

Parent authority:

- TIMEINT05 qualifies variable-step fully implicit BDF2 on the smooth fixed-flux envelope for accepted adjacent step ratio 0.5 <= r <= 2.0;
- TIMEINT09 shows an exact final-Newton one-backsolve LTE response is strongly predictive but not conservatively classifying on blind materials;
- TIMEINT10 shows a raw BDF2/BE one-correction embedded difference is conservative but unusably restrictive;
- TIMEINT10 therefore requires a genuinely co-designed stiff embedded pair.

## Purpose

Test whether a two-stage L-stable SDIRK2 method can provide:

1. a genuine second-order Richards endpoint;
2. a lower-order embedded endpoint estimate derived from the same two stages;
3. a useful local error classifier without empirical scaling;
4. bounded deterministic cost with no third nonlinear solve.

This is test-only integrator research.

No production `src/**` change is permitted.

## Method

Use the two-stage singly diagonally implicit RK2 scheme with:

`gamma = 1 - 1/sqrt(2)`.

For the semidiscrete water equation written as:

`d theta / dt + S(h) = 0`

where `S` contains the fully implicit spatial flux/source operator.

### Stage 1

Solve:

`theta(Y1) - theta_n + gamma*h*S(Y1) = 0`.

This is exactly the existing fully implicit Backward Euler mechanism over effective duration `gamma*h`.

### Stage 2 / accepted endpoint

Solve:

`theta(Y2) - theta_n + h[(1-gamma)S(Y1) + gamma*S(Y2)] = 0`.

`Y2` is the accepted SDIRK2 endpoint.

For implementation with the current BE endpoint solver, divide by `gamma*h`:

`[theta(Y2)-theta_n]/(gamma*h) + S(Y2) + ((1-gamma)/gamma)S(Y1)=0`.

The known stage-1 operator contribution is materialized as a fixed per-compartment source/sink vector.

From stage 1:

`S(Y1) = -[theta(Y1)-theta_n]/(gamma*h)`.

No new hydraulic approximation is introduced.

## Embedded estimator

Construct a first-order stage-based endpoint prediction:

`h_emb = h_n + (h_Y1-h_n)/gamma`.

Raw embedded head difference:

`E11 = max_i |h_Y2_i - h_emb_i|`.

No multiplier, intercept, material term, forcing correction or post-hoc scale factor is allowed.

The estimator is a candidate mechanism to be tested, not presumed conservative.

## Scope

Initial mechanism qualification is deliberately restricted to the smooth fixed-flux envelope:

- explicit constant top flux;
- prescribed zero bottom flux;
- no dynamic-top transitions;
- no root extraction;
- no drainage;
- no macropores;
- fully implicit conductivity;
- BALTOL02-compatible balance floor;
- same hydraulic archetypes used by prior TIMEINT work.

Dynamic-top is excluded until smooth-regime mechanism and cost qualify.

## P0 mechanism bank

Materials / forcing:

- B01 at infiltration 2 and 4 cm/day;
- O05 at infiltration 2 and 4 cm/day.

Horizon:

- 0.04 d.

Fixed physical timestep levels for local estimator characterization:

- 0.010 d;
- 0.005 d;
- 0.0025 d.

This gives at least 112 full-step local labels before any unavailable two-half research labels.

For each full SDIRK2 physical interval:

1. execute the two-stage full interval;
2. independently execute two half SDIRK2 intervals from the same accepted origin for local research authority;
3. retain the full SDIRK2 endpoint for the primary trajectory;
4. record E11 versus actual full-vs-two-half max head difference.

## Order ladder

For each of the four B01/O05 forcing cases, independently run fixed physical dt:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

Estimate observed terminal top-head order from consecutive differences:

`p = log2(|H_h-H_h/2| / |H_h/2-H_h/4|)`.

Use the two finest available triples where possible.

## Work accounting

Record separately:

- stage-1 nonlinear iterations/backtracks/Jacobian builds/linear solves;
- stage-2 equivalents;
- total SDIRK2 work per accepted physical interval;
- two-half authority work.

For paired cost reference, run the already qualified fully implicit fixed-step BDF2 mechanism over the same cases/horizons where history is available.

Cost comparisons are deterministic solver-work comparisons, not process-startup wall-clock claims.

## Frozen P0 gates

SDIRK2 mechanism advances only if all are true:

### Completion / balance

1. all four order ladders complete;
2. all P0 full SDIRK2 trajectories complete;
3. at least 80 complete full-vs-two-half local labels;
4. every accepted stage satisfies the unchanged integrated mass/ledger authority;
5. no alternative-solver path is used on primary authority points.

### Order

6. median observed terminal top-head order >= 1.8;
7. no completed case has terminal top-head order < 1.6.

### Embedded error signal

8. E11 finite and nonnegative for every complete labelled point;
9. overall Spearman(E11,E_HEAD) >= 0.85;
10. at E11 <= 0.01 cm, false-safe count = 0;
11. safe coverage >= 30%.

### Cost

12. exactly two nonlinear stage solves per normal full SDIRK2 interval;
13. no third nonlinear solve for E11;
14. median deterministic full-SDIRK2 work per physical interval <= 2.25 times the paired fully implicit BDF2 work per physical interval.

No gate may be relaxed after exposure.

## Blind holdout

Only if P0 passes, freeze gamma, equations, estimator and threshold unchanged and validate on:

- B12 and O14;
- infiltration 1, 3 and 5 cm/day;
- fixed dt 0.010, 0.005 and 0.0025 d;
- horizon 0.04 d.

Holdout requires:

1. all 18 full SDIRK2 trajectories complete;
2. at least 140 complete local labels;
3. zero false-safe at E11<=0.01 cm;
4. safe coverage >=30%;
5. overall Spearman >=0.80;
6. no primary alternative-solver use;
7. median SDIRK2/BDF2 deterministic work ratio <=2.25.

## Stop rule

If the smooth fixed-flux P0 fails, stop this SDIRK2 embedded-pair line.

Do not tune gamma.

Do not fit a multiplier to E11.

If P0 passes but holdout fails, close without dynamic-top extension.

Only after blind smooth-regime qualification may a separate successor consider dynamic-top boundary transitions and event/restart semantics.

## Possible outcomes

- `SDIRK2_EMBEDDED_PAIR_MECHANISM_QUALIFIED`;
- `SDIRK2_EMBEDDED_PAIR_HOLDOUT_QUALIFIED`;
- `CLOSED_SDIRK2_EMBEDDED_PAIR_NOT_QUALIFIED`.

## Production boundary

No production timestep or Richards-discretization change.

LEGACY_NUMERICS remains production default.

Variable-step BDF2 remains qualified research authority.
