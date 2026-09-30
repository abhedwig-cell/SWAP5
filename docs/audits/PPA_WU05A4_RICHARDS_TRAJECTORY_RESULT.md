# PPA-WU05-A4 real-Richards strict-versus-practical trajectory result

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_RESULT / MAX_THREE_CORRECTOR_PRACTICAL_CANDIDATE_SUPPORTED`

Workflow run: `36767379536`

Head: `9e196c89acdb04c1cd68b4eec576b2f7c1bbff9f`

## Purpose

Compare a strict converged outer coupling route against an adaptive practical route capped at three outer correctors over a short accepted multi-step trajectory using the real Richards solver.

## Setup

- B01 hydraulics;
- initial head `-50 cm`;
- six accepted physical steps;
- `dt = 0.05 d`;
- repeated macropore recharge;
- source-shaped sorptivity exchange;
- outer damping `omega=0.5`.

### Strict route

- up to 50 outer correctors;
- exchange convergence criterion `1e-8`;
- failure to reach the criterion invalidates the strict step.

### Practical route

- at most three outer correctors;
- early-stop criterion `1e-3`.

## Strict convergence

Every strict step reached the required outer convergence criterion.

The reported strict iteration count was 22 for each step.

This supersedes the earlier trajectory probe where the strict route merely reached the previous 20-iteration cap.

## Exchange sequence by accepted step

Strict / practical [cm d-1]:

1. `1.73367207 / 1.76932670`
2. `0.77479880 / 0.78106891`
3. `0.62012278 / 0.62402259`
4. `0.54014599 / 0.54306497`
5. `0.48863944 / 0.49100691`
6. `0.45161672 / 0.45362362`

The practical route remains consistently close and does not diverge from the strict trajectory.

## End-of-trajectory differences

Versus strict:

- cumulative exchange absolute difference: `0.0026559 cm`;
- cumulative exchange relative difference: approximately `1.15%`;
- maximum matrix-theta absolute difference: `1.998e-4`;
- maximum pressure-head absolute difference: `0.0987 cm`;
- macropore-storage absolute difference: `0.0026559 cm`;
- cumulative bottom-flux absolute difference: `0.0020622 cm`.

O0 and O2 outputs are identical.

## Interpretation

The practical max-three-corrector route remains close to a genuinely converged strict reference over this real-Richards trajectory.

The observed trajectory errors are consistent with the intended practical-mode accuracy range:

- order-1% exchange/flux deviation;
- very small theta error;
- sub-millimetre pressure-head-scale difference in this case;
- exact transaction/mass ownership retained.

This is substantially stronger evidence than the earlier one-step comparison.

## Research decision

`MAX_THREE_CORRECTOR_ADAPTIVE_ROUTE = PRACTICAL_ADMISSION_CANDIDATE_FOR_FURTHER_QUALIFICATION`

The strict route remains the scientific/reference oracle.

This result does **not** yet make three correctors a universal production constant.

The route still needs:

- timestep-retry ownership integrated with the controller;
- crack-history and rapid-drain active trajectories;
- broader soil/profile regimes;
- runtime/solve-count characterization;
- canonical integration review.

## Current policy direction

### Strict scientific mode

- iterate to exchange convergence;
- allow damping;
- propagate Richards retry outward;
- require combined mass closure.

### Practical coupling candidate

- early stop when convergence criterion is already met;
- otherwise cap at three correctors;
- retain damping;
- propagate solver retry outward;
- preserve the same physical equations and state semantics.

The practical route approximates the coupled solve, not the macropore physics itself.

## Next step

Extend the controller prototype from research tests into a typed research component that:

1. owns outer corrector sequencing;
2. consumes A2 macropore candidate state;
3. uses the existing source/sink provider seam;
4. returns one coupled candidate or retry;
5. exposes strict and max-three research policies explicitly.

After that, qualify crack-history and rapid-drain trajectories through the same controller.
