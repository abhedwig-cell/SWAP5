# PPA-WU05-A4 R2 outer coupling controller contract

Date: 2026-09-30

Status: `PROPOSED_RESEARCH_CONTRACT / SUPPORTED_BY_A4 CHARACTERIZATION`

## Scope

This contract defines ownership and control flow for the research R2 macropore/Richards coupling.

It does not admit production macropore physics and does not change the Richards solver ABI.

## Ownership

### Richards solver owns

- one matrix solve for a supplied frozen internal exchange vector;
- solver convergence diagnostics;
- solver retry/failure status;
- matrix candidate state;
- solver-native mass diagnostics.

It does **not** own macropore state, damping policy, outer fixed-point convergence, timestep retry policy, or final coupled commit.

### Macropore process owns

- evaluation of matrix/macropore exchange from a supplied matrix hydraulic state;
- source-shaped macropore candidate history and storage;
- rapid drainage and other macropore process rates as later added;
- no mutation of accepted state during evaluation.

### Outer coupling controller owns

- predictor/corrector sequencing;
- exchange fixed-point convergence;
- optional exchange under-relaxation;
- propagation of Richards RETRY/FAILED outward;
- combined matrix+macropore mass reconciliation;
- return of one coupled candidate or one retry/failure decision.

### Transaction/timestep layer owns

- checkpoint authority;
- acceptance/rejection;
- physical timestep retry/reduction;
- atomic commit of matrix and macropore continuation state.

## Research algorithm

For one physical attempt from accepted state:

1. capture accepted matrix + macropore checkpoint;
2. run a Richards predictor from the accepted matrix state without tentative macropore exchange, or with the accepted predictor convention selected by the research slice;
3. evaluate raw macropore exchange from predictor matrix state and accepted macropore history;
4. run Richards corrector from the **same accepted matrix base state** with the current frozen exchange vector;
5. evaluate raw exchange again from the resulting matrix candidate;
6. assess outer convergence;
7. if required, form a damped next exchange vector and repeat step 4;
8. if Richards returns RETRY/FAILED at any corrector, abandon the coupled candidate and propagate retry/failure outward;
9. once outer convergence is accepted, construct the macropore candidate using the same final exchange receipt;
10. reconcile combined matrix + macropore mass, with internal exchange cancelling exactly;
11. return one coupled candidate;
12. only the transaction layer may commit it.

## Damping

Research evidence supports damping as an outer numerical device.

Damping:

- modifies only the exchange iterate used to seek a consistent candidate;
- is not physical macropore state;
- is not persisted in restart;
- must not mutate accepted history;
- may be activated when raw exchange iteration shows oscillation or poor contraction.

The tested value `omega=0.5` is evidence of feasibility, not a universal production constant.

## Retry

A Richards `RETRY_ADVISED` is authoritative evidence that the current coupled attempt is not admissible.

The outer controller must not conceal that status by silently clipping exchange or changing physics.

It returns retry to the owning timestep controller.

A smaller timestep may be attempted from the original accepted checkpoint.

The A4 timestep characterization explicitly shows that success is not guaranteed monotonically by dt, so retry remains outcome-based rather than assumption-based.

## Convergence observable

The preferred first observable is the exchange-vector change between successive outer iterations.

For scalar research probes:

`r_q = |q_k - q_{k-1}| / max(|q_{k-1}|, q_floor)`.

For the future vector route, the norm and floor must be preregistered before qualification.

No universal tolerance is frozen in this contract.

## Strict versus practical routes

### Strict research route

- iterate outer coupling until the selected exchange-convergence criterion passes;
- allow bounded damping;
- propagate solver retry outward;
- require combined mass closure;
- use this route as the comparison oracle for practical coupling.

### Practical candidate route

May use a bounded lower corrector count only after state and flux errors are quantified against the strict route.

A practical route must still:

- preserve exact accepted/rejected ownership;
- close combined water mass;
- preserve macropore history semantics;
- propagate genuine solver failure/retry.

## Evidence motivating this contract

A4 has demonstrated:

- mild fresh case: fast fixed-point convergence;
- aged case: very weak coupling;
- mid-fresh adversarial case: strong but convergent coupling;
- dry-fresh adversarial case: undamped period-two oscillation, resolved by outer damping;
- wet-fresh adversarial case: frozen-exchange corrector can request timestep retry, resolved for some smaller steps;
- no tested case requires macropore exchange in the Richards Newton Jacobian.

## Next research task

Quantify the cost/error tradeoff of fixed corrector counts against the converged strict-route sequences.

The first comparison should use:

- mild fresh;
- aged;
- mid-fresh;
- damped dry-fresh.

Report errors in:

- exchange;
- matrix theta;
- bottom flux;
- combined storage/mass;
- Richards solve count.

This will support a later strict/practical policy without weakening the scientific reference route.
