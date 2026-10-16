# F-PE-PZG23-06 — post-research closure

Date: 2026-09-30

Status: CLOSED_LOCAL_NONLINEAR_SOLVABILITY_BLOCKER

Canonical baseline:
`integration/f-ci-canonical@c400b02d9956f35c9c20fac09f94b34d5e2ee09f`

Research authority:
- PZG23-01: localized second-interval blocker to origins 10 and 11;
- PZG23-02: accepted temporal-history content and hidden solver scratch falsified as primary causes;
- PZG23-03: solver rejection identified as dominant rejection channel;
- PZG23-04: doubling max_iterations from 32 to 64 shown insufficient;
- PZG23-05: backtracking-depth exhaustion shown not to be the primary terminal mechanism;
- PZG23-06: terminal convergence shown to be multi-criterion.

Qualified PZG23-06 computational evidence:
- branch: `research/f-pe-pzg23-06-terminal-criterion-attribution`;
- computational postimage: `c249db32bf4ef6de678b6983b915eca91404569e`;
- result commit: `b7328d27b5afd71f23e1a7b3b16cfb9b1a61e133`;
- workflow run: `36765065843`;
- job: `110057047768`;
- terminal criterion computation step: SUCCESS.

## Closed blocker

The pZg23 second-interval failure is a localized wet positive-forcing nonlinear
Richards solvability blocker.

Frozen failing origins:

1. h0=+2 cm, forcing delta=+0.035 cm/day;
2. h0=+2 cm, forcing delta=+0.050 cm/day.

The fourteen other frozen pZg23 origins complete interval B.

## Causal narrowing

The blocker is not:

- a worker/OpenMP defect;
- invalid interval-A construction;
- hard-mass rejection;
- accepted temporal-history content;
- hidden solver scratch outside the committed carrier;
- simply max_iterations=32;
- primarily max_backtracking=12;
- a single convergence tolerance sitting marginally above threshold.

At terminal failed HeadCalc states, all of the following remain violated:

- compartment balance;
- total balance;
- pressure-head change.

The violations are often orders of magnitude above their configured
tolerances. Ponding is inactive in the failing route.

## Production consequence

No production solver-policy change is justified.

Do not:

- widen the admitted 0.20 cm application budget;
- relax hard mass;
- relax compartment/total-balance or head tolerances;
- increase MaxIt or MaxBackTr as a default repair;
- reset temporal history;
- remove pZg23 from scientific evidence merely to qualify the scheduler.

The admitted GENERATED ELAS + mode-7 application policy remains unchanged.

## Scheduling consequence

F-PE-SCHED01 established that column count alone is insufficient for
worker-count selection.

F-PE-SCHED02 showed that lagged committed solver work is a plausible abstraction
but cannot be qualified on the preregistered five-profile domain because pZg23
does not provide a valid common two-interval calibration domain.

Therefore no automatic mode-7 worker-count selector is admitted.

Worker count remains explicit application/runtime policy.

## Closure

The PZG23-01..06 attribution chain is closed.

Further solver development is justified only if this wet pZg23 regime becomes a
material production reliability problem in real applications, not merely to
complete the scheduler calibration set.

The next useful performance work should return to application-scale runtime
measurement or broader production priorities, not further local pZg23
parameter tuning.
