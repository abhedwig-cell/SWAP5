# F-PE-APPQUAL01 — MultiSWAP + MODFLOW6 application-qualified performance benchmark

Date: 2026-09-25

Status: `PREREGISTERED`

## Purpose

This workstream is the common performance authority for the post-zero-waste phase.

The objective is not bitwise equivalence to Reference Richards.

The objective is to compare alternative SWAP5 representations on the same coupled SWAP5-MODFLOW6 workloads and determine total coupled computational cost versus hydrological error.

Competing families:

- `CODE`: exact/reference-preserving implementation improvements;
- `ROSSFAST`: alternative solver;
- `ROM`: purpose-specific reduced-order representation;
- `COARSE`: spatial and/or vertical schematization reduction;
- hybrids may combine more than one family.

## Governing decision quantity

For candidate configuration c and application workload W:

`minimize T_total(c,W)`

subject to all application-qualified error-budget clauses for W.

Where:

`T_total = T_swap + T_modflow + T_coupling + T_management + T_overhead`

No candidate may claim superiority from SWAP micro-runtime alone.

## Frozen reference

The reference route is the cleaned production Reference Richards route from the zero-waste phase.

Reference outputs are frozen per workload before candidate comparisons.

The frozen reference includes:

- exact workload definition;
- source commit;
- model configuration;
- MODFLOW6 version and asset digest;
- compiler identity and flags;
- coupling convergence settings;
- accepted output transcript / machine-readable metrics.

## Benchmark levels

### B0 — live coupled semantic seed

Authority source: existing F-GC47 mixed-topology live MODFLOW6 end-to-end case.

Properties:

- real MODFLOW6 prepared solve;
- real SWAP transaction participants;
- one N:1 groundwater cell with two SWAP tiles;
- one 1:1 groundwater cell with one SWAP tile;
- three SWAP lineages total;
- two live MODFLOW API slots;
- transactional preflight/publication and per-cell ledger closure.

B0 is too small for scaling conclusions.

B0 exists to establish the common measurement seam:

- total coupling-loop seconds;
- coupling outer iterations;
- MODFLOW solve calls;
- final groundwater heads;
- interface fluxes;
- ledger exchanges;
- convergence/failure status.

### B1 — scaled coupled performance authority

B1 must preserve the same coupling semantics while scaling independent SWAP participants.

Target scales:

- S100: 100 SWAP columns;
- S1000: 1,000 SWAP columns;
- S10000: 10,000 SWAP columns.

The primary target is S10000 because that is the intended stress regime for large MultiSWAP applications.

B1 shall contain multiple groundwater cells, not 10,000 tiles attached to one artificial cell.

Initial target topology:

- 100 MODFLOW interface cells;
- 100 SWAP tiles per groundwater cell at S10000;
- lower scales obtained by reducing tiles per cell while keeping the groundwater-cell layout and forcing classes stable where possible.

The exact topology must be generated deterministically from a versioned benchmark manifest.

### B2 — hydrologically heterogeneous qualification

After B1 infrastructure is stable, add workload families that vary:

- soil hydraulic class;
- groundwater depth;
- atmospheric forcing;
- root-zone demand;
- drainage ownership/configuration;
- dry/wet regime;
- difficult versus easy Richards convergence;
- spatial aggregation structure.

B2 is required before a production approximation envelope is declared general.

## Required measured outputs

### Performance

- wall-clock total coupled runtime;
- SWAP runtime;
- MODFLOW runtime;
- coupling/orchestration runtime;
- number of SWAP trial solves;
- accepted SWAP solves;
- rejected/retried solves;
- nonlinear iterations;
- constitutive evaluations;
- MODFLOW outer/solve calls;
- coupling outer iterations;
- peak participant count and memory where measurable.

### Hydrology

Per cell and spatial aggregate where applicable:

- cumulative SWAP-MODFLOW exchange;
- recharge/capillary exchange sign and magnitude;
- groundwater head;
- groundwater drawdown;
- drainage;
- actual evaporation/transpiration when represented;
- irrigation demand when represented;
- total and component water-balance residuals;
- timing/magnitude of predefined extremes.

### Error decomposition

For every candidate relative to the frozen reference:

- signed bias;
- mean absolute error;
- maximum absolute error;
- relative error where numerically meaningful;
- cumulative error;
- timing error for extrema;
- spatial aggregation error.

A candidate can pass some quantities and fail others. No single scalar accuracy score is authoritative.

## Provisional application-qualified envelope mechanism

No universal tolerance is fixed in this preregistration.

Each B2 application class will define an error-budget packet containing:

- quantity;
- spatial aggregation level;
- temporal aggregation level;
- absolute tolerance if applicable;
- relative tolerance if applicable;
- cumulative-bias tolerance;
- extreme-event tolerance;
- source/provenance of the tolerance.

The existing coupling application accuracy contract for groundwater head/drawdown remains valid where applicable but is not sufficient for the full P2 envelope.

## Candidate lanes

### C0 — cleaned Reference Richards

Purpose:

- frozen reference;
- performance denominator.

### C1 — RossFast

Questions:

- total coupled speedup;
- error in interface flux and head;
- effect on coupling iteration count;
- failure/regime envelope.

### C2 — ROM

ROM is purpose-specific.

Initial coupling purpose:

`groundwater exchange + head response`

Do not require reproduction of the complete vertical Reference state unless the application needs it.

### C3 — coarser spatial schematization

Reduce SWAP participant count by deterministic clustering/aggregation.

Required reporting:

- original participant count;
- retained representative count;
- weights;
- grouping features;
- mapping back to groundwater cells;
- resulting flux/head bias.

### C4+ — hybrids

Examples:

- coarse + RossFast;
- coarse + ROM;
- ROM + zero-waste runtime;
- full Reference in sensitive cells + ROM/RossFast elsewhere.

Hybrids must disclose both component choices.

## Fair-comparison rules

1. Same MODFLOW workload and initial state.
2. Same atmospheric/management forcing authority.
3. Same coupling convergence rule unless changing it is the explicitly tested candidate feature.
4. Same publication/transaction semantics.
5. Measure warm and cold behavior separately if initialization cost is material.
6. Compile candidates with comparable optimization settings.
7. Run paired/repeated measurements and report dispersion.
8. Do not add independent speedups arithmetically.
9. A failed or unstable candidate remains in the ledger.
10. Approximation choices must be serialized into the run manifest.

## Phase transition rule

P0/P1 work continues until the current zero-waste/H04 tranche reaches a bounded closeout.

APPQUAL01 may build benchmark infrastructure in parallel, but no approximate candidate is admitted to production from B0 alone.

## Initial implementation sequence

1. Instrument F-GC47 as B0 and record coupling-loop timing/iteration counts.
2. Create machine-readable benchmark manifest/schema.
3. Build scalable B1 generator from the F-GC47/F-GC49 production application semantics.
4. Freeze C0 reference outputs at S100, S1000 and S10000.
5. Attach RossFast as first challenger.
6. Attach coupling-purpose ROM as second challenger.
7. Add deterministic spatial coarsening as third challenger.
8. Evaluate hybrids only after individual lanes have interpretable failure envelopes.
