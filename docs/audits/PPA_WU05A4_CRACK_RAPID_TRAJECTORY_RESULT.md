# PPA-WU05-A4 accepted-state crack/rapid trajectory result

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_RESULT / ACCEPTED_STATE_TRAJECTORY_PASS`

Workflow run: `36770067804`

Head: `12378e86dd44b5a2cbdc4be1766e50b387303d48`

## Purpose

Verify that the typed A4 controller remains correct across multiple accepted steps when:

- the matrix candidate from one step becomes the next accepted matrix state;
- the macropore candidate becomes the next accepted continuation state;
- crack hysteresis is active;
- rapid drainage is an external outflow;
- sorptivity exchange remains internal;
- cumulative matrix + macropore + boundary + rapid-drain mass remains closed.

## Trajectory

Four accepted steps, each `0.05 d`.

### Step 1

- dynamic crack: `0.0 cm`;
- macropore water: `0.4526035079 cm`;
- rapid outflow: `0.0106633425 cm`;
- matrix theta at active node: `0.3085012868`.

### Step 2

- dynamic crack: `0.3092807260 cm`;
- macropore water: `0.4272172809 cm`;
- rapid outflow: `0.0093272253 cm`;
- matrix theta: `0.2986134195`.

### Step 3

- dynamic crack: `0.3092807260 cm`;
- macropore water: `0.4062386331 cm`;
- rapid outflow: `0.0082230860 cm`;
- matrix theta: `0.2906544207`.

### Step 4

- dynamic crack: `0.3092807260 cm`;
- macropore water: `0.3879330280 cm`;
- rapid outflow: `0.0072596331 cm`;
- matrix theta: `0.2839890244`.

## Cumulative result

- cumulative rapid drainage: `0.0354732868 cm`;
- final dynamic crack: `0.3092807260 cm`;
- final macropore water: `0.3879330280 cm`;
- cumulative combined mass residual: `4.38e-14 cm`.

O0 and O2 outputs are identical.

## Interpretation

The first step closes the initial crack under the current wetting state.

As the accepted matrix state subsequently dries, the source-bound crack branch reopens the dynamic crack and the accepted history persists across later steps.

Rapid drainage remains explicitly external and decreases as the available macropore water/storage head declines.

The trajectory therefore demonstrates that:

- accepted macropore continuation state is carried across steps;
- crack hysteresis is not reinitialized each call;
- external rapid drainage remains single-owned;
- internal exchange and external rapid drainage coexist without mass duplication;
- candidate-to-accepted promotion is sufficient to reproduce the intended history semantics.

## Qualification

`QUALIFIED_ACCEPTED_STATE_MACROPORE_CONTROLLER_TRAJECTORY`.

This completes the A4 research-controller phase.

## Holds

A4 still does **not** establish:

- full exact multi-domain B1.11 macropore physics;
- production activation;
- exact top-inflow partition/redistribution;
- multi-level drainage topology;
- canonical admission;
- parallel MultiSWAP macropore ownership.

Those belong to follow-on work.
