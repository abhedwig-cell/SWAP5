# F-ROMV2 purpose-dependent fidelity proposition

## Status

**INDEPENDENT RESEARCH PROPOSITION. NOT A RECLASSIFICATION OF F-ROMV. NOT PRODUCTION ROM AUTHORITY.**

F-ROMV2 is opened after the canonical F-ROMV terminal decision
`CLOSED_NO_GO_UNDER_CURRENT_PROPOSITION`.

The historical F-ROMV result remains immutable:

- the preregistered global nine-state bilinear closure failed its scientific early-kill gates;
- physical-state admissibility, held-out bottom-flux sign and reversal timing failed;
- no direct performance-comparator stage was reached;
- no production ROM, cross-material ROM or ROM-2 closure was authorized.

F-ROMV2 does not relax those gates after the result. It asks a different research question.

## Governing distinction

Two acceleration problems must not be judged by the same equivalence rule.

### Alternative numerical route

A route such as Reference Richards versus an alternative solver aims at essentially the same process-model solution. Tight numerical and hydrological equivalence is therefore appropriate.

### Deliberately reduced hydrological model

A reduced model intentionally discards information or simplifies dynamics. Its admissibility depends on whether it preserves the hydrological information required by a declared application while delivering useful computational value.

The governing question is:

> **For which SWAP5/MultiSWAP application classes can a deliberately reduced, conservative unsaturated-zone model occupy a useful computational-cost versus hydrological-fidelity frontier, without violating physical integrity or hiding its domain of validity?**

Numerical identity with Reference Richards is not a universal F-ROMV2 requirement.

## Immutable integrity constraints

Purpose-dependent fidelity does not mean arbitrary approximation.

Every prognostic reduced model must satisfy, within its claimed domain:

- explicit water accounting;
- no hidden correction flux used to erase structural drift;
- finite and physically admissible published state;
- declared material/template, forcing, boundary and capability identity;
- deterministic persistence/restart semantics when the reduced model owns state;
- fail-closed behaviour outside the qualified domain.

Failure of these constraints is application-independent.

## Purpose-dependent fidelity axes

Hydrological fidelity is decomposed rather than collapsed into one RMSE:

- long-term water balance and storage drift;
- cumulative and mean actual evapotranspiration;
- drainage and groundwater recharge;
- root-zone and profile soil moisture;
- groundwater-head response where coupled;
- fast-event timing and magnitude;
- extrema, drought onset, persistence and recovery;
- regime-transition timing;
- systematic bias;
- OOD behaviour and robustness.

No universal percentage tolerance is preregistered. A value such as 1% or 2% annual ET is only illustrative until justified by a concrete application, decision or scientific inference.

Thresholds for final application qualification must be frozen before the corresponding final validation evidence is exposed.

## Initial application classes

F-ROMV2 distinguishes at least:

1. **Long-term regional water balance.** Cumulative ET, recharge/drainage, storage drift and systematic bias dominate; sub-daily event timing can be secondary when it does not alter those quantities.
2. **Operational soil-moisture and drought.** Root-zone state, drought onset/recovery, stress response and robustness to state updating dominate.
3. **Groundwater-coupled many-column simulation.** Recharge/capillary exchange, storage response, groundwater feedback, mass integrity and iterative coupling stability dominate.
4. **Fast-event / threshold-sensitive simulation.** Event timing, threshold activation and extrema are primary.
5. **Scientific process or extreme-event inference.** Highest fidelity demand; a reduced model may be inappropriate if the scientific conclusion depends on discarded state structure.

Passing one class never implies passing another.

## Precedent

MetaSWAP is relevant as precedent for **purpose-dependent approximate unsaturated-zone modelling**, not as a code or algorithm donor.

The published MetaSWAP work deliberately used quasi-steady information derived from detailed unsaturated-zone physics and assessed usefulness through application-facing groundwater and evapotranspiration behaviour across soils, groundwater depths, root-zone configurations and meteorological years. Its known differences around rapid wetting and percolation/capillary-rise transitions show why application envelopes matter.

Other simplified unsaturated-zone formulations, including pseudo-steady and kinematic-wave approaches, reinforce the same point: computational reduction is scientifically meaningful only together with a hydrological regime and application boundary.

F-ROMV2 retains the clean-sheet rule. No MetaSWAP source or algorithm is inherited automatically.

## Candidate families

The first research comparison treats three families as genuinely different.

### A. Local conservative dynamic reduction

A low-dimensional prognostic state is advanced by a bounded local closure. The exploratory post-F-ROMV nearest-neighbour table result is feasibility evidence only and is not confirmatory authority.

### B. Quasi-steady or integrated-manifold physical reduction

Online state evolution uses a low-dimensional conservative balance plus precomputed or derived hydraulic manifolds. This family is especially relevant to long-term regional and groundwater-coupled use.

### C. Output-specific surrogate

For UQ, calibration, data assimilation or optimization, a surrogate may emulate only declared outputs. This is an emulator, not automatically a prognostic ROM.

ROM-assisted full-order solving remains a solver-workstream comparator/handoff when difficult nonlinear tails dominate.

## Existing evidence reinterpreted, not reclassified

ROM-1's strict numerical-floor ambiguity result remains valid.

F-ROMV2 may additionally report the absolute hydrological scale of that ambiguity. For example, the frozen Z8 collision-pair probes showed maximum total-storage response separation of about 0.00342 cm, while maximum terminal bottom-flux separation reached about 0.316 cm/day.

Those numbers illustrate why cumulative-balance fidelity and event/flux fidelity must be judged separately. They do not turn ROM-1 into a positive closure result.

## Computational-value gate

A scientifically acceptable reduced model is still not useful when the accelerated work is not a material cost.

Final value requires:

- a declared many-query workload;
- end-to-end cost decomposition;
- comparison with current admitted direct routes including RossFast where applicable;
- spatially coarsened Richards;
- a simple physical-reduction comparator where scientifically comparable;
- offline cost and amortization;
- fallback cost;
- a non-dominated point on the application-specific cost-fidelity frontier.

The F-ROSS24 shared-host screen remains bounded evidence, not a formal MultiSWAP baseline.

## Research stages

- **V2-P:** proposition and purpose-dependent acceptance authority.
- **V2-D:** discovery-only architecture discrimination without consuming final validation.
- **V2-V:** newly generated, preregistered blind validation on current-canonical accepted trajectories.
- **V2-F:** cost-fidelity frontier against direct and simplified comparators, only after a V2-V scientific gate.
- **V2-X:** transfer to additional templates/materials, only if separately preregistered.

The old H01-H04 states are exposed and may not serve as blind V2 validation.

## Valid negative outcomes

Valid closures include:

- `NO_REDUCED_MODEL_VALUE`;
- `INTEGRITY_FAILURE`;
- `APPLICATION_FIDELITY_INSUFFICIENT`;
- `EVENT_FIDELITY_ONLY_NO_GO`;
- `LONG_TERM_BALANCE_ONLY`;
- `GROUNDWATER_COUPLING_ONLY`;
- `COARSE_RICHARDS_DOMINATES`;
- `PHYSICAL_REDUCTION_DOMINATES_DYNAMIC_ROM`;
- `DIRECT_RUNTIME_VALUE_DOMINATES`;
- `NO_PRACTICAL_AMORTIZATION`.

## Production gate

F-ROMV2 authorizes research only.

No production ROM is authorized until a later proposition demonstrates, for at least one declared application:

1. integrity;
2. blind hydrological fidelity;
3. fail-closed domain behaviour;
4. robustness;
5. a non-dominated cost-fidelity point;
6. realistic amortization;
7. governance compatible with the then-current SWAP5 application/runtime architecture.
