# PPA-WU05-A5 qualification result — single-column macropore process composition

Date: 2026-09-30

Status: QUALIFIED_SINGLE_COLUMN_COMPOSITION_ARCHITECTURE / SOURCE_RATE_MIGRATION_FOLLOWON_REQUIRED

Qualified head: 6bc5936926b743d201a4a8f1abf1cd9f1a513e0a

Workflow run: 36772075072

## Qualified surface

A5 now composes, in one typed research contract:

- source-bound top/surface partition ownership;
- cross-domain top-excess redistribution and returned surface receipt;
- multi-domain/multi-compartment geometry;
- moving active domain bottoms;
- distributed matrix/macropore exchange ownership;
- explicit geometry-shrinkage return to matrix;
- single-owner rapid drainage;
- seven-field continuation-state restart/replay.

## Exact source conclusions preserved

### Top input

Top macropore input is a partition of the existing surface receipt, not a new source.

Unused macropore top input is returned to the surface/lateral route after cross-domain redistribution.

### Geometry

Dynamic crack volume and immutable static/configuration data determine current compartment and domain geometry.

ICpBtDm and VlMpDmCp remain accepted continuation fields for rollback/restart, while their next candidate values are derived.

### Distributed exchange

Domain-resolved exchange obeys:

QExc = QOutSat + QOutUns - QInIntSat - QInMtxSat.

The matrix receives the node-wise sum; the macropore candidate receives the equal/opposite amount.

### Rapid drainage

Rapid drainage is owned only by main domain 1 and is distributed across active compartments by source-shaped kD weighting.

It remains one external water transfer.

## Typed A5 components

Research components now include:

- mod_ppa_wu05a5_top_partition;
- mod_ppa_wu05a5_multi_domain_process;
- mod_ppa_wu05a5_macropore_restart.

The multi-domain compositor produces:

- one macropore candidate;
- one matrix-exchange vector;
- one returned-surface receipt;
- one rapid-drain external receipt;
- one explicit macropore mass residual.

## Restart/replay

Only the seven A2 continuation-state groups are serialized in the A5 research payload.

After restore:

- geometry is re-derived from immutable configuration and restored dynamic crack state;
- active bottoms reproduce;
- domain volume reproduces;
- the next composed multi-domain candidate is identical to the uninterrupted route;
- matrix-exchange receipts reproduce.

Markers:

- PPA_WU05A5_MULTI_DOMAIN_COMPOSITION=PASS;
- PPA_WU05A5_RESTART_REPLAY=PASS;
- PPA_WU05A5_TOP_PARTITION_GATE=PASS.

O0/O2 outputs are identical.

## What A5 does not claim

A5 does not yet provide a fully migrated typed Fortran implementation of every exact B1.11 rate equation.

In particular, the typed compositor currently consumes domain-resolved exchange and rapid-drain receipts that have been source-mapped and locally falsified, but their complete B1.11 rate generators remain to be migrated.

Therefore A5 is not production admission.

## Qualification decision

QUALIFIED_SINGLE_COLUMN_COMPOSITION_ARCHITECTURE_READY_FOR_SOURCE_RATE_MIGRATION.

The seven-field continuation surface remains sufficient in all A5 tests.

No mass-ownership falsification occurred.

No additional restart state was required.

## Follow-on

The next slice should migrate exact/source-bound rate generation into the typed multi-domain process architecture:

1. saturated exchange;
2. unsaturated absorption;
3. inter-domain saturated exchange;
4. multi-compartment rapid drainage;
5. source-bound top-input limitation/redistribution;
6. full accepted vertical-flux reconstruction.

That follow-on is designated PPA-WU05-A6.
