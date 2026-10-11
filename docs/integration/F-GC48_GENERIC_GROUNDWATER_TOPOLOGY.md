# F-GC48 — Generic groundwater topology composition

## Purpose

F-GC48 replaces qualification-specific topology wiring with one typed, deterministic production topology authority. It does not change groundwater physics, SWAP transaction ownership, predictor/corrector semantics, MODFLOW solve ownership or publication ordering.

## Normalized topology model

The topology has two contract levels.

`groundwater_topology_tile_t` owns tile-local identity: `tile_id`, `swap_lineage_id`, `ledger_id`, `groundwater_cell_id` and `area_fraction`.

`groundwater_topology_cell_t` owns cell-local identity: `groundwater_cell_id`, `coupling_id`, `groundwater_service_id`, `groundwater_lineage_id`, MODFLOW `package_slot` and `modflow_node_id`.

Cell-level coupling metadata is intentionally not duplicated on every tile. This makes the ownership relation explicit: many tiles may belong to one groundwater cell, but every tile, SWAP lineage and ledger has exactly one topology owner and every groundwater cell has exactly one MODFLOW API binding.

## Admission validation

Materialization is fail-before-publication and non-mutating. It rejects:

- invalid or non-positive identities;
- duplicate tile ids;
- duplicate SWAP lineage ids;
- duplicate ledger ids;
- duplicate groundwater cell ids;
- duplicate coupling ids;
- duplicate groundwater lineage ids;
- duplicate package slots;
- duplicate MODFLOW node ids;
- package slots outside the complete 1..N active prefix;
- tiles referencing missing groundwater cells;
- groundwater cells without a tile;
- non-finite or non-positive area fractions;
- per-cell area fractions that do not close to one.

`groundwater_service_id` may be shared by multiple cells because one MODFLOW service/model can own multiple groundwater-cell lineages.

## Determinism

After validation, cells are stored in ascending `groundwater_cell_id` order and tiles in `(groundwater_cell_id, tile_id)` order. MODFLOW API bindings are emitted in `package_slot` order. Per-cell fractions use compensated summation before the closure check.

This canonicalization makes the same logical topology independent of input ordering and provides one deterministic order for future application orchestration and publication.

## Existing capability preservation

F-GC48 materializes the already admitted downstream types rather than introducing replacements:

- per-cell tile mappings become `groundwater_direct_tile_binding_t` for F-GC40;
- per-model cell mappings become `modflow6_api_slot_binding_t` for F-GC34.

The qualification reproduces the topology structures admitted by F-GC45 (N:1 one cell), F-GC46 (multi-cell 1:1) and F-GC47 (mixed N:1 plus 1:1) from this one generic contract.

## Evidence boundary

F-GC48 is a topology/ownership capability. Supporting N:1 mappings is not a scientific assertion that heterogeneous forcing, soils or groundwater dynamics can be represented by an equivalent unsaturated-zone column. That transferability remains a separate SCALE research question.

F-GC48 also does not create a generic application orchestrator. It creates the typed, validated topology authority that such an orchestrator can consume in the next bounded workunit.
