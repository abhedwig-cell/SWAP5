> Authority note: F-GC40 is the corrected identity of the historical owner-qualified MultiSWAP cell-response work that provisionally used F-GC31. Canonical F-GC31 is reserved for the F-CI98 active-drainage tangent. The production formula below is unchanged.

# F-GC40 — MultiSWAP MODFLOW6 cell-response contract

## Status

**DESIGN / IMPLEMENTATION AUTHORITY NOT YET QUALIFIED**

F-GC40 extends the canonically admitted drainage-free F-GC30 predictor response from one SWAP5 column to multiple SWAP5 tiles sharing one groundwater cell.

It does not introduce a MODFLOW6/XMI backend, a new coupling runtime, Ribasim coupling, irrigation allocation or new SWAP physics.

Baseline at workunit creation:

- canonical branch: `integration/f-ci-canonical`
- canonical head: `878ca73649c9a2e98ca81d45c3ecec2717604ba3`
- F-GC30 drainage-free predictor response: canonically admitted
- existing F-GC25 direct-groundwater MultiSWAP topology and transaction semantics: reused as architectural precedent, not modified by this workunit

## 1. Purpose

F-GC30 produces, for one SWAP column and one coupling window:

- predictor lower-boundary flux `q_bot`;
- terminal fixed-plane hydraulic head `H_bot,end`;
- MODFLOW-facing exchange `q_u`;
- coupling/storage response coefficient `u`;
- accepted-origin and derivative provenance.

Regional use requires several SWAP tiles to contribute to one MODFLOW groundwater cell. F-GC40 defines the typed reduction from those tile responses to one local affine groundwater-cell response.

The workunit is intentionally non-committing. It composes already-produced F-GC30 responses. It does not own SWAP trials, groundwater trials, publication or rollback.

## 2. Why simple averaging of q_u is insufficient

For tile `i`, let the admitted F-GC30 predictor response be evaluated at its predictor terminal head `H_i*`:

```text
q_i* = q_u,i(H_i*)
u_i  = coupling/storage response
```

For a fixed coupling window with duration `dt`, the local affine response represented by F-GC30 is:

```text
q_u,i(H) ~= q_i* + (u_i / dt) * (H - H_i*)
```

All quantities in the executable cell contract are normalized to SI for the affine evaluation:

- `q`: m/s
- `H`: m
- `dt`: s
- `u`: dimensionless
- `dq/dH`: 1/s

If several tiles have different predictor terminal heads, then:

```text
sum(f_i * q_i*)
```

is not, by itself, the cell exchange at one common groundwater head.

F-GC40 therefore requires an explicit cell reference head `H_ref`.

For each tile:

```text
q_i,ref = q_i* + (u_i / dt) * (H_ref - H_i*)
```

Then:

```text
q_cell,ref = sum(f_i * q_i,ref)
u_cell     = sum(f_i * u_i)
```

and the aggregate local response is:

```text
q_cell(H) ~= q_cell,ref + (u_cell / dt) * (H - H_ref)
```

This formulation preserves the exact weighted sum of the tile-local affine responses while allowing heterogeneous `H_i*`, `q_i*` and `u_i`.

The simpler identity

```text
q_cell = sum(f_i * q_i*)
```

is recovered only when the individual predictor responses are evaluated at the same head as `H_ref`.

## 3. Required topology and provenance invariants

A valid F-GC40 cell response requires:

1. at least one tile;
2. one response for each tile binding;
3. one common positive groundwater-cell identity;
4. unique tile identities;
5. valid area fractions with a total of one to machine-scale topology tolerance;
6. valid admitted F-GC30 predictor responses;
7. one common coupling window;
8. one common coupling identity;
9. one common groundwater service identity, lineage and origin revision;
10. unique SWAP lineage identities across the contributing tiles;
11. one finite explicit `H_ref`;
12. deterministic reduction in canonical ascending tile-id order.

F-GC40 does not require predictor terminal heads to be identical. Their difference is precisely why the reference-head reconciliation is explicit.

## 4. Typed output

The intended cell response exposes at least:

```text
groundwater_cell_id
window
reference_head_m
coupling_id
groundwater_service_id
groundwater_lineage_id
groundwater_origin_revision
tile_count
fraction_sum
area_weighted_predictor_q_u_m_per_s   # diagnostic only
q_u_at_reference_m_per_s               # authoritative affine intercept at H_ref
coupling_storage_coefficient_u          # u_cell
dq_u_dh_per_s                           # u_cell / dt_s
per-tile binding + complete F-GC30 response provenance
per-tile q_u at H_ref
```

The raw area-weighted predictor `q_u` is retained only as a diagnostic. The reference-reconciled value is the correct intercept for the common cell response when tile predictor heads differ.

## 5. Determinism

Input order is not scientific state.

F-GC40 sorts the reduction by ascending `tile_id` and uses compensated summation for:

- area fraction;
- raw predictor exchange;
- reference-reconciled exchange;
- `u`.

Permuting the caller's tile array must therefore not change the aggregate result or the canonical output tile order.

## 6. Relationship to existing MultiSWAP groundwater work

F-GC25 already establishes useful N:1 invariants:

- typed `groundwater_cell_id / tile_id / area_fraction` bindings;
- unique tile topology;
- area closure;
- deterministic tile order;
- transaction isolation;
- cell-level publication.

F-GC40 reuses the existing `groundwater_direct_tile_binding_t` mapping type. It does not modify the admitted F-GC25 `restricted-multiswap-pc1` runtime.

A later workunit may replace the current pc1 groundwater-exchange middle section with an F-GC30/F-GC40 response backend. That later composition is not part of F-GC40.

## 7. Qualification gates

### Q1 — single tile equivalence

With one tile of area fraction one and `H_ref = H_i*`:

- cell `q_u` equals the F-GC30 tile `q_u`;
- cell `u` equals tile `u`;
- cell tangent is `u/dt`.

### Q2 — heterogeneous two-tile affine closure

For two different predictor heads and response coefficients:

- direct weighted evaluation of both tile affine responses at `H_ref` equals the composed cell intercept;
- `u_cell = sum(f_i u_i)`;
- evaluating the cell affine response at a second common head equals the direct weighted tile evaluation there.

### Q3 — permutation determinism

Reversing input tile order produces bit-identical aggregate quantities and the same canonical tile order.

### Q4 — provenance fail-closed

Reject:

- wrong cell identity;
- duplicate tile identity;
- duplicate SWAP lineage;
- area fractions that do not close;
- invalid F-GC30 response;
- window mismatch;
- coupling identity mismatch;
- groundwater service/lineage/revision mismatch;
- non-finite reference head.

## 8. Explicit exclusions

F-GC40 does not:

- call MODFLOW6;
- define an XMI/BMI API;
- mutate F-GC30 response semantics;
- execute SWAP predictor or corrector trials;
- admit a runtime finite-difference fallback;
- relax F-GC30 active-drainage fail-closed behavior;
- define the later MODFLOW matrix representation of `q_u/u`;
- define head-driven corrector iteration;
- change F-GC25 publication semantics;
- couple Ribasim;
- implement irrigation;
- commit scientific state.

## 9. Next bounded step

Implement the pure typed cell-response composer and a focused O0/O2 qualification gate covering Q1 through Q4. Stop after qualification and persist the evidence before any MODFLOW backend or runtime composition work.


## Current-canonical requalification

F-GC40 was materialized from canonical `7b864853ca22baa73141b2dec9ed2f3915ef520d`.

The production module is byte-identical to the historical owner-qualified donor:

```text
src/runtime/mod_modflow6_multiswap_cell_response.f90
blob 288a274612f6c0be0b3ced149028066a066908ca
```

Owner requalification:

```text
head 7ab1f5567a55385f72c869a9fafc9abaa4b58300
run  35291893022
job  105436313416
conclusion SUCCESS
```

O0 and O2 outputs are identical. Single-tile equivalence, heterogeneous common-head affine closure, area-weighted `u`, deterministic tile reduction and fail-closed provenance all pass against current canonical dependencies.

**Verdict: OWNER_QUALIFIED_TYPED_MULTISWAP_AFFINE_CELL_RESPONSE.**
