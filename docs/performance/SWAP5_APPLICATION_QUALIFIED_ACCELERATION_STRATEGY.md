# SWAP5 performance phase transition: exact cleanup to application-qualified acceleration

Date: 2026-09-25

Status: `STRATEGIC_NEXT_PHASE_DEFINED`

## Purpose

The current zero-waste and reference-preserving phase is not the end goal.

Its purpose is to remove avoidable work, establish a trustworthy performance baseline, and make the cost of genuinely necessary physics and numerics visible.

After this phase, SWAP5 performance work must deliberately enter an application-qualified regime for large MultiSWAP + MODFLOW6 systems.

The governing question then becomes:

> What is the fastest representation of the coupled system that remains hydrologically fit for the intended application, with every approximation explicit and quantified?

Exact agreement with the standard SWAP/Richards trajectory is no longer the primary acceptance criterion in that phase.

## Strategic premise

For large coupled applications with many SWAP columns above MODFLOW6, total coupled runtime is a first-class design constraint.

Small deviations are acceptable when they are:

- physically interpretable;
- bounded for the target application;
- unbiased or acceptably biased over the relevant aggregation scale;
- documented as deliberate numerical/model choices;
- evaluated on coupled outputs rather than only internal SWAP state.

No universal percentage tolerance is fixed here. A few-percent deviation may be immaterial for one quantity and unacceptable for another.

## Four main acceleration families

### 1. CODE / exact work reduction

Continue to remove remaining execution waste and improve implementation efficiency.

Examples:

- work avoidance;
- phase-specific constitutive evaluation;
- prepared/cached immutable data;
- fewer allocations and copies;
- solver/timestep improvements that preserve the reference equations;
- better coupling response information.

This family should remain the preferred route whenever equivalent physics can be retained at lower cost.

### 2. ROSSFAST / alternative solver

RossFast is treated as a production-relevant challenger to standard Richards.

Research questions:

- in which hydrological regimes is it faster;
- where does it remain sufficiently accurate;
- how do errors accumulate over seasons and groundwater exchange;
- what happens to coupled MODFLOW convergence;
- can tables or other constitutive accelerations further improve RossFast;
- when should runtime choose RossFast versus Reference Richards.

RossFast is not judged only by single-column speed. Total coupled cost and hydrological error matter.

### 3. ROM / reduced-order representation

ROM is a separate representation family rather than merely a solver optimization.

Existing ROM work already shows that useful vertical state placement is purpose-dependent.

The performance phase should therefore test purpose-specific ROMs for quantities relevant to coupling, for example:

- groundwater exchange;
- recharge/capillary rise;
- root-zone water availability;
- ET/stress response;
- drainage/management demand.

The relevant question is not whether one ROM reproduces every internal SWAP state. It is whether the smallest purpose-specific state can meet the application error budget at materially lower cost.

### 4. COARSER SCHEMATIZATION / fewer columns or states

Performance must also be attacked above the individual-column level.

Possible dimensions include:

- horizontal aggregation of similar SWAP columns;
- larger spatial units where subgrid differences do not materially affect coupled outputs;
- fewer vertical compartments where application-qualified;
- adaptive spatial detail, with fine representation only where gradients, management, soil heterogeneity or groundwater interaction require it;
- clustering columns with equivalent forcing/parameter/state behavior.

This family can provide multiplicative gains because it reduces the number of solves rather than merely making each solve faster.

It must be evaluated together with MODFLOW discretization and coupling semantics. Coarsening SWAP while retaining an incompatible groundwater exchange scale is not automatically valid.

## Combined performance space

The four families are not mutually exclusive.

A realistic production configuration may combine:

`fewer columns × cheaper representation × faster solver × lower code overhead`

For example:

`spatial clustering × ROM × RossFast × zero-waste runtime`

or:

`full SWAP columns × RossFast × adaptive hydraulics`

or:

`coarse background columns + full Richards columns in sensitive zones`.

The research objective is therefore a performance envelope, not one globally fastest mode.

## Application-qualified error budget

Qualification must move from internal bit identity to application outputs.

At minimum measure:

- cumulative water-balance closure;
- cumulative actual evaporation/transpiration;
- recharge to MODFLOW;
- capillary rise;
- SWAP-MODFLOW interface flux;
- groundwater-head response;
- drainage;
- irrigation/water demand when applicable;
- timing and magnitude of hydrological extremes;
- systematic bias separately from random/compensating error.

Evaluation scale matters:

- timestep;
- day;
- season;
- year;
- groundwater-management period;
- spatial aggregate.

A daily flux error can be acceptable while an annual recharge bias of the same percentage is not.

## Coupled cost metric

The primary production metric is total coupled cost:

`T_total = T_SWAP + T_MODFLOW + T_coupling + T_management + T_overhead`

A method that makes each SWAP solve cheaper but increases coupling iterations may lose overall.

Conversely a slightly more expensive SWAP response can be advantageous if it improves the coupled nonlinear response and reduces outer iterations.

## Required experimental design

Every approximate candidate should be compared against a frozen reference workload and report:

1. runtime and operation-count change;
2. error by hydrological quantity;
3. systematic bias;
4. temporal accumulation;
5. spatial aggregation effects;
6. coupling-iteration count;
7. total coupled runtime;
8. failure/stability regimes.

The choice made by the production configuration must be explicit and reproducible.

## Phase order

### Phase P0 — zero waste

Remove objectively unnecessary work.

### Phase P1 — reference-preserving acceleration

Tables, exact caching/reuse, analytic derivatives, solver improvements, RossFast characterization where strict reference comparison remains useful.

### Phase P2 — application-qualified acceleration

Explicitly allow controlled deviation.

Compete:

- Reference Richards;
- RossFast;
- purpose-specific ROM;
- spatial/vertical coarsening;
- hybrid combinations.

### Phase P3 — coupled production envelope

Select the representation dynamically or statically by application/regime and qualify the full SWAP5-MODFLOW6 system.

## Decision principle

Do not ask:

> Which method is most exact?

and do not ask only:

> Which method is fastest?

Ask:

> Which configuration minimizes total coupled computational cost while staying inside the hydrological error budget for the intended application?

## Documentation rule

Every admitted production approximation must record:

- what is approximated;
- why;
- expected speed benefit;
- known error mechanism;
- qualification workloads;
- accepted error envelope;
- known failure regimes;
- fallback route;
- whether the choice is global, spatially selective or dynamically selected.

Approximation must be a visible model choice, never an undocumented side effect of optimization.

## Strategic consequence

The current zero-waste work should continue to closure.

After that, the performance program should broaden deliberately instead of remaining trapped in micro-optimization.

The principal next-phase research portfolio is:

`CODE + ROSSFAST + ROM + COARSER SCHEMATIZATION`

with total coupled SWAP5-MODFLOW6 performance and hydrological fitness as the common authority.
