# F-GC33 — MODFLOW6 linear response backend

## Status

**DESIGN / IMPLEMENTATION AUTHORITY NOT YET QUALIFIED**

F-GC33 converts one already-qualified F-GC31 MultiSWAP groundwater-cell affine response into the linear boundary coefficients used by MODFLOW6.

This workunit is algebraic and non-committing. It does not write XMI pointers, choose an API package, map coupling cell identities to MODFLOW node numbers, execute MODFLOW6, or own predictor/corrector iteration.

## 1. Inputs from F-GC31

For one groundwater cell, F-GC31 provides

```text
q_u(H) = q_ref + s * (H - H_ref)
s      = dq_u/dH = u_cell / dt_s
```

with:

- `q_u` in m/s;
- `H` in m;
- `s` in 1/s;
- positive `q_u` directed outward from SWAP, hence into groundwater;
- an explicit coupling-cell identity and groundwater-origin provenance.

F-GC33 additionally requires the horizontal MODFLOW cell area `A` in m2.

## 2. MODFLOW6 boundary equation

Pinned external implementation evidence:

- repository: `Deltares/imod_coupler`
- inspected commit: `3ddeec26ba1a0f1fcb4cf681b3f3202b4a6de6b7`
- file: `imod_coupler/kernelwrappers/mf6_wrapper.py`
- `Mf6HeadBoundary.get_flux` documents and evaluates:
  `Flux = HCOF * X - RHS`
- its documented sign is positive for infiltration into MODFLOW6.

That sign matches F-GC31's positive outward-from-SWAP exchange.

## 3. Exact coefficient transform

Convert the F-GC31 areal flux to MODFLOW volume flux in m3/day:

```text
Q(H) = A * 86400 * q_u(H)
```

Therefore:

```text
Q(H)
  = A*86400*s * H
    + A*86400*(q_ref - s*H_ref)
```

Match this to:

```text
Q(H) = HCOF * H - RHS
```

giving the exact backend coefficients:

```text
HCOF = A * 86400 * s
RHS  = HCOF * H_ref - A * 86400 * q_ref
```

Equivalently, because `s = u_cell/dt_s`:

```text
HCOF = A * u_cell / dt_day
```

Units:

- `HCOF`: m2/day;
- `RHS`: m3/day;
- `Q`: m3/day.

No extra sign inversion is permitted.

## 4. Important identity boundary

`groundwater_cell_id` is a coupling-domain identity. F-GC33 MUST NOT reinterpret it as a MODFLOW6 `NODELIST` index.

The later XMI/API adapter must own the explicit mapping:

```text
groundwater_cell_id -> MODFLOW6 package slot / node
```

This prevents an accidental coupling-identity/index equivalence from becoming scientific state.

## 5. Typed output

The F-GC33 result should retain:

```text
groundwater_cell_id
coupling window
groundwater provenance
cell_area_m2
reference_head_m
q_ref_m_per_s
dq_u_dh_per_s
reference_volume_flux_m3_per_day
hcof_m2_per_day
rhs_m3_per_day
```

and expose an evaluator implementing exactly:

```text
Q(H) = HCOF*H - RHS
```

## 6. Qualification gates

### Q1 — F-GC31 closure

At `H_ref`:

```text
HCOF*H_ref - RHS
=
A*86400*q_ref
```

At another head:

```text
HCOF*H - RHS
=
A*86400*q_cell(H)
```

### Q2 — reference representation invariance

Compose the same underlying F-GC31 tile responses around two different valid `H_ref` values.

The resulting F-GC33 `HCOF` and `RHS` must be numerically identical within machine-scale arithmetic tolerance.

### Q3 — area scaling

Doubling cell area doubles `HCOF`, `RHS` and evaluated volume flux without changing the areal response.

### Q4 — sign preservation

Positive outward-from-SWAP `q_u` at the evaluated head must produce positive MODFLOW6 infiltration flux.

### Q5 — fail closed

Reject:

- invalid F-GC31 response;
- non-positive or non-finite cell area;
- non-finite F-GC31 linearization terms;
- non-finite evaluated head;
- arithmetic overflow/non-finite coefficient construction.

## 7. Explicit exclusions

F-GC33 does not:

- access MODFLOW6 through XMI;
- create or mutate API package arrays;
- choose `NODELIST` entries;
- change F-GC30/F-GC31 science;
- own MODFLOW nonlinear iteration;
- own SWAP corrector trials;
- alter groundwater transaction/commit semantics;
- couple Ribasim;
- implement irrigation;
- expand the admitted active-drainage envelope.

## 8. Next bounded step

Implement the pure typed HCOF/RHS transformer plus focused O0/O2 qualification. Stop after persisting qualified evidence. A later workunit may bind the typed terms to an actual MODFLOW6 API package.
