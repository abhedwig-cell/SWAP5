# F-GC49A — Generic groundwater application-plan materialization

## Purpose

F-GC49A is the first production stage of F-GC49. It converts one canonically admitted F-GC48 groundwater topology plus one predictor response per SWAP tile into an immutable, deterministic application plan for a single coupled MODFLOW service/window.

It is pure composition. It does not run SWAP trials, MODFLOW solves, predictor/corrector iterations, commits, rollback or publication.

## Inputs

The materializer consumes:

- one ready `groundwater_topology_t` from F-GC48;
- exactly one `groundwater_tile_predictor_input_t` per topology tile;
- exactly one positive finite cell area per topology groundwater cell.

Predictor input is keyed by `tile_id`. The response itself remains authoritative for SWAP and groundwater provenance.

## Provenance validation

Before producing a plan the materializer requires:

- predictor count equals topology tile count;
- predictor tile ids are unique;
- every topology tile has exactly one predictor;
- predictor SWAP lineage equals topology SWAP lineage;
- predictor coupling id equals the owning topology cell coupling id;
- predictor groundwater service id equals the owning cell service id;
- predictor groundwater lineage equals the owning cell lineage;
- every predictor belongs to one common coupling window;
- every topology cell belongs to the same groundwater service in the first F-GC49 envelope;
- cell-area records are unique, complete, finite and positive.

The common-service restriction is intentional: one F-GC49 application plan represents one live MODFLOW model/service and one prepared solve.

## Cell-plan materialization

For each canonical topology cell, F-GC49A asks F-GC48 for that cell's already-canonical tile bindings. It then resolves the matching predictor response for each tile.

The cell reference head is the compensated area-weighted sum of predictor terminal lower-face heads:

`H_ref,c = sum_i(a_i * H_end,i)`

F-GC49A then delegates all cell-response mathematics to the already-admitted F-GC40 `compose_modflow6_multiswap_cell_response`.

The resulting F-GC40 cell response is converted to the MODFLOW linear term by the already-admitted F-GC33 `compose_modflow6_linear_boundary_term`, using the explicitly supplied groundwater-cell area.

MODFLOW package-slot/node bindings are copied from F-GC48 through its admitted F-GC34 binding materialization.

F-GC49A therefore does not reproduce F-GC40, F-GC33 or F-GC34 mathematics.

## Application-plan structure

The immutable `groundwater_application_plan_t` retains:

- the one common coupling window;
- canonical F-GC48 topology tiles ordered by `(groundwater_cell_id, tile_id)`;
- canonical per-cell plans ordered by `groundwater_cell_id`;
- each cell's contiguous tile range in the canonical tile array;
- each cell's area-weighted reference head;
- the admitted F-GC40 cell response;
- the admitted F-GC33 linear term;
- F-GC34 API bindings in package-slot order.

The plan exposes copies only. It contains no SWAP committed state, no candidate handles and no MODFLOW/XMI pointers.

## Fail-closed conditions

Materialization fails before any downstream solver mutation for wrong predictor/area counts, duplicate predictor tile ids, missing predictor tiles, SWAP-lineage mismatch, cell provenance mismatch, cross-cell window mismatch, multiple groundwater services in one plan, invalid/duplicate/missing cell areas, rejected F-GC48 bindings, rejected F-GC40 cell responses, rejected F-GC33 terms, or internal canonical-order inconsistencies.

## Qualification

The owner gate reproduces the topology shapes previously admitted by F-GC44, F-GC45, F-GC46 and F-GC47 using one production materializer, checks input-order invariance, and exercises the fail-closed matrix under O0 and O2.

Independent F-VQ121 materializes the same mixed topology through F-GC49A and independently through direct F-GC40/F-GC33 calls. It then sends the plan-produced terms and bindings through the real F-GC34 publisher and checks slot/node/term identity plus preservation of the unmapped package tail.

## Evidence boundary

F-GC49A proves application-plan materialization only.

It does not yet expose production FMR participants across a language boundary, run the generic live coupling service, alter predictor/corrector ownership, expand the physical/numerical envelope, or make a scientific claim about heterogeneous N:1 transferability.

The next bounded stage is F-GC49B: production participant bridge over the already-admitted FMR/SWAP participant lifecycle.