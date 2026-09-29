# F-PE-NLGLOB14O closeout — first-retreat full-column TG handoff admissibility

Date: 2026-09-29

Final status:

`NLGLOB14O_FULL_COLUMN_TG_HANDOFF_ORIGIN_ADMISSIBLE`

Qualification authority:

- run `36585663754`;
- job `109465241511`;
- conclusion: SUCCESS.

## Closure

NLGLOB14O closes the first full-column TG handoff-origin probe positively under the existing provider contract.

All 12 first-retreat accepted states have finite positive provider capacity on all active nodes.

The accepted control trajectories remain unchanged persistent-KLAG trajectories and remain finite and mass-clean.

## Critical interpretation

The positive result is narrower than a physical claim that the saturated lower block behaves like an ordinary unsaturated TG domain.

For saturated nodes the current B1.10 provider deliberately returns:

`C = step_duration * 1e-7`.

The observed lower-block capacities therefore shrink linearly with timestep and reach `7.8125e-13` at the finest dt.

This is existing numerical regularization.

It is sufficient to pass the frozen NLGLOB14O positive-capacity gate, but not sufficient to establish a safe TG predictor or solve.

## Direct successor

Open:

`F-PE-NLGLOB14P — first-retreat full-column TG predictor admissibility`.

At the same first-retreat accepted origins:

1. evaluate actual dry-phase top and internal fluxes;
2. derive physical `theta_dot` for all nodes;
3. use the existing provider capacity without modification;
4. form `h_tilde = h + dt*theta_dot/C`;
5. test finiteness and constitutive/predictor-domain admissibility;
6. preserve persistent KLAG as the accepted control trajectory.

No solve, handoff or capacity-floor change is allowed in NLGLOB14P.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14O

BRANCH: `research/f-pe-nlglob14o-first-retreat-shadow-handoff`

STATUS: closed positive provider-origin admissibility

TEST STATUS: 12-case six-level probe PASS

QUALIFICATION STATUS: `NLGLOB14O_FULL_COLUMN_TG_HANDOFF_ORIGIN_ADMISSIBLE`

NEXT SAFE STEP: preregister full-column TG predictor admissibility at the qualified first-retreat state.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
