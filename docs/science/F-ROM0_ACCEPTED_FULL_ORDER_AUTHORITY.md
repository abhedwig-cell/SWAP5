# ROM-0 Accepted Full-Order Authority

## Purpose

ROM-0 creates the scientific measuring instrument used by later F-ROM state-identification work.

It has two responsibilities: produce reproducible **accepted** Reference-Richards trajectories through the normal SWAP5 lifecycle, and establish the numerical/reference floor needed to interpret later projection ambiguity.

ROM-0 does not search for collisions, select a reduced state, fit a closure or implement a reduced solver.

## Governing correction

The superseded F-ROM01 pilot called the typed Reference Richards solver directly and required each requested attempt to converge.

That is not the required trajectory authority for this research. SWAP5 architecture separates solver candidate work from attempt assessment, retry/timestep policy and commit. ROM-0 therefore observes the accepted trajectory produced by the canonical runtime/transaction lifecycle.

A failed individual Reference solver attempt is attempt evidence. It is not by itself a failed physical trajectory if the admitted execution lifecycle can retry and reach an accepted state.

## Required implementation seam

ROM-0 must bind to the canonical accepted interval/trajectory path.

It may add research/test observation infrastructure, but it must not call a direct solver attempt and treat it as committed authority, change Reference Richards equations, change retry/timestep/commit policy, change production solver selection, modify RossFast, or introduce a special research-only physical solution path.

If the current canonical runtime does not expose enough observation information, ROM-0 stops and opens a separate observational-interface decision rather than silently bypassing ownership.

## First experiment capability

The first ROM-0 laboratory covers the ROM-P pure-hydraulics capability.

Minimum experiment families are steady/near-steady continuation, bounded top-flux wetting, bounded drying, bounded lower-head rise, bounded lower-head fall, and downward/upward direction reversal.

Exact amplitudes, durations and material fixtures are preregistered before execution.

## Accepted-state observations

At each research observation point ROM-0 preserves, where available: accepted time/interval identity, accepted pressure-head profile, accepted water-content profile, accepted total storage, accepted fixed-depth band storages, accepted top and bottom exchange, accepted mass-accounting diagnostics, accepted route/status diagnostics, forcing/boundary identity, material identity, and retry/substep summary needed to reproduce the accepted trajectory.

Candidate/rejected attempt states may be stored separately for numerical diagnostics but must never be mixed with accepted physical state records.

## Numerical Reference floor

ROM-0 establishes how much the accepted Reference trajectory changes under controlled numerical refinement that remains scientifically comparable.

The preregistered refinement matrix must consider the relevant subset of macro/observation interval refinement, permitted internal timestep/retry refinement, vertical discretization refinement, solver tolerance/resolution controls allowed by the canonical Reference contract, and compiler O0/O2 reproducibility where relevant.

The output is not one universal scalar. Numerical differences are recorded per relevant output and horizon.

ROM-1 projection differences are interpreted relative to this floor.

## Material challenge

ROM-0 preregisters at least two contrasting existing qualified material fixtures. Selection is based on hydraulic contrast and fixture authority, not observed favourability to a reduction hypothesis.

A layered/restrictive profile is a later challenge unless already needed to falsify the initial homogeneous-material claim.

## Data split discipline

Before ROM-1 begins, the trajectory-library design declares discovery histories, held-out histories, discovery future probes, held-out future probes and a material-transfer challenge.

A coordinate proposed after inspecting discovery failures is not admitted until it improves held-out evidence.

## Data schema

ROM-0 produces a versioned machine-readable schema suitable for replay and later projection analysis.

The schema preserves canonical authority, research-harness commit, material authority, forcing/boundary sequence, accepted-state sequence, numerical-control identity and observation units.

Large trajectory payloads may live in CI artifacts or approved scientific data storage, while hashes and summaries are persisted in the repository.

## Qualification gates

Q0.1 Ownership: the harness demonstrably observes accepted authority and cannot promote rejected candidate state.

Q0.2 Reproducibility: identical experiment definitions reproduce the accepted observation sequence within the declared deterministic boundary.

Q0.3 Conservation: every retained trajectory has valid mass-accounting evidence; failures are classified rather than silently filtered.

Q0.4 Bidirectional reachability: the harness can generate accepted drainage and capillary/upward-influence trajectories through admitted boundary routes.

Q0.5 Reference floor: at least one controlled numerical refinement comparison exists for every output used by ROM-1 state-sufficiency claims.

Q0.6 Non-mutation: ROM-0 does not alter production physics, solver selection, transaction ownership or accepted Reference semantics.

## Close decisions

ROM-0 closes as one of `PROCEED_TO_ROM1A`, `EXPAND_REFERENCE_FLOOR`, `EXPAND_ACCEPTED_TRAJECTORY_DOMAIN`, `BLOCKED_OBSERVATION_SEAM_REQUIRED`, or `NO_GO_REFERENCE_AUTHORITY`.

Only `PROCEED_TO_ROM1A` authorizes reachable-state generation for state-identification evidence.
