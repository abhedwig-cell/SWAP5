# Richards discretisation and nonlinear solve

## Discrete reference problem

The qualified historical reference formulation uses a one-dimensional vertically compartmented grid and an implicit backward finite-difference treatment of the soil-water balance.

For compartment `i`, the storage contribution over an attempted step is based on the **actual water-content difference** between the candidate endpoint and the accepted start state:

```text
theta_i(t1) - theta_i(t0)
```

rather than replacing nonlinear storage by an independently invented linear storage law. Internodal Darcy fluxes connect adjacent compartments, while admitted boundary and distributed source/sink terms enter the same discrete conservation residual.

The frozen reference `SWKIMPL=0` route uses its admitted old-time-level conductivity linearisation for the conductivity contribution. The storage relation remains nonlinear through `theta(h)`. This page documents that restricted reference route only; it does not promote other historical SWAP numerical switches.

## Residual system

The compartment equations form a nonlinear residual system

```text
F(h) = 0
```

where `h` is the candidate vector of compartment pressure heads. Each residual combines, with the process-specific signs and units required by the admitted formulation:

- compartment storage change;
- upper and lower internodal/boundary water fluxes;
- admitted distributed sources;
- admitted distributed sinks such as root extraction or drainage where active.

The continuous hydraulic convention and the distinction between hydraulic flux signs, process sink magnitudes and normalized mass-accounting signs are documented in [Water balance, signs and units](../science/water-balance-and-conventions.md).

## Newton-Raphson reference route

The frozen reference nonlinear route solves the residual system by Newton-Raphson iteration. At an iteration, the implementation constructs the Jacobian associated with the residual system and solves the resulting tridiagonal linear update problem.

The qualified historical route does not blindly accept every full Newton update. It:

1. forms the candidate Newton correction;
2. attempts the full correction;
3. evaluates the residual objective;
4. backtracks when the full update does not improve that objective;
5. continues until the admitted convergence criteria are met or the attempt fails.

This is a description of the frozen reference route, not a general requirement that every future solver use Newton-Raphson.

## Convergence criteria

Historical F-DOC18 records that the restricted reference route retains compartment water-balance and pressure-head convergence criteria together with applicable total-balance criteria. F-DOC21 does not assign new numerical values to those criteria and does not turn one case-specific tolerance into a universal model tolerance.

A nonlinear solver can therefore fail because the iterative criteria are not satisfied even when finite candidate values exist. Conversely, iterative convergence alone does not establish that the surrounding model attempt may be committed.

## Convergence is not commit

Convergence of `F(h)=0` produces a **candidate** numerical state. It does not itself make that state persistent.

The transaction layer owns the attempt lifecycle:

```text
committed checkpoint
        |
        v
candidate solve
        |
        v
assessment
   /          \
accept        reject
  |             |
commit        rollback/retry
```

This separation prevents solver internals from silently owning global state-commit policy. A later assessment can reject a converged candidate when an applicable hard scientific or numerical criterion fails.

## Mass criteria

Mass/conservation criteria are hard guards where the owning capability requires them. A candidate cannot become scientifically acceptable merely because the Newton iteration converged if the applicable mass gate fails.

The mass identity is evaluated on accepted physical transfers. A rejected trial may expose provisional storage and flux information for diagnostics, but those provisional amounts do not become committed accounting. See [Water balance, signs and units](../science/water-balance-and-conventions.md) and the [Mass-accounting contract](../verification/mass-accounting-contract.md).

## Failure and retry

A solver attempt can report failure, or a candidate can fail a later assessment. In either case, the surrounding transaction controller may request a bounded retry according to its admitted policy.

The preservation invariant is that retry starts from accepted authority, not from a partially mutated rejected state. Solver workspace or warm-start information may be reusable only where the owning contract permits it; it cannot redefine the accepted physical start state.

## What this numerical authority does not prove

The reference Richards authority does not establish:

- RossFast or another alternative nonlinear solver as part of the frozen Status-A review denominator;
- a universal iteration tolerance;
- a universal time step;
- a universal nonlinear true-error theorem;
- monotonic improvement of every indicator as the time step is shortened;
- permission for a numerical indicator to override a hard mass failure;
- permission for rejected candidate state to leak into committed state.

## What to inspect in code review

Reviewers should follow the capability-specific implementation/evidence chain and check:

- sign and unit consistency in residual and boundary terms;
- Jacobian consistency with the residual actually solved;
- storage derivative/constitutive consistency;
- the frozen conductivity treatment where reference equivalence is claimed;
- convergence criteria and nonfinite handling;
- behaviour near ponding/boundary transitions;
- full-step/backtracking behaviour;
- separation between solver scratch, candidate state and committed state;
- exact preservation evidence at O0/O2 where required.

The current authority map is [Status-A traceability](../status-a/TRACEABILITY.md). Historical F-DOC18 supplies bounded scientific/numerical lineage; current implementation and admission authority remain the frozen production postimage plus the Status-A capability chain.
