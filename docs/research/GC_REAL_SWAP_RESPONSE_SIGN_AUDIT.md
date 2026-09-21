# Real-SWAP response sign audit after MAP02

Date: 2026-09-21  
Status: RESEARCH EQUATION RECONCILIATION  
Production source: read-only

## 1. Observed MAP02 fact

For the F-GC45 drainage-free real-SWAP fixture, within the prospectively fixed
admitted head band:

```
production affine slope dq_u/dH
    = +3.9385833764804317e-06 1/s

real corrector slope dq_swap/dH
    = -3.9386e-06 1/s
```

The magnitude agrees to about 1e-5 relative, while the sign is opposite.

The accepted corrector mass ledger closes exactly against the integrated
`q_swap` flux.

This is a bounded observation. It is not yet a production-defect verdict.

## 2. Native SWAP lower-boundary sign

The canonical interface conversion states:

```
native qbot > 0 : into the SWAP soil profile
q_swap > 0      : outward from SWAP
```

therefore

```
q_swap = -qbot * unit_conversion
```

and, for a fixed coupling duration,

```
d q_swap / dH = - d qbot / dH * unit_conversion.
```

## 3. Historical predictor algebra

F-GC30 reproduces the historical SWAP coupling equation:

```
u   = dt / (dH / dqbot)
q_u = u * (H_end-H_start) / dt - qbot
```

Hence, by construction,

```
dqbot/dH = u/dt
```

for the local inverse response represented by the accepted-trajectory tangent.

Because physical bottom-interface flux uses the opposite qbot sign:

```
dq_swap/dH = -u/dt
```

after unit normalization.

This is exactly the sign relation observed in MAP02.

## 4. F-GC40/F-GC33 interpretation

F-GC40 promotes the historical response to:

```
q_u(H) = q_ref + (u/dt)*(H-H_ref)
```

and F-GC33 maps it without an extra sign inversion to:

```
Q(H) = HCOF*H - RHS
HCOF = A*u/dt_day
```

The documented F-GC33 contract calls this the MODFLOW-facing exchange response
and states that positive `q_u` is infiltration into MODFLOW.

Thus the F-GC40/F-GC33 slope is explicitly:

```
dq_u/dH = +u/dt.
```

## 5. Production corrector reanchor

The F-GC49 application context obtains a real head-driven SWAP corrector flux
`q_swap(H)`.

When the coupled residual does not close, it reanchors the current linear term
at the measured pair:

```
(H_current, q_swap_current)
```

but preserves the previous `HCOF`, hence preserves the positive slope
`+u/dt`.

The next affine response is therefore:

```
q_reanchored(H)
  = q_swap_current + (u/dt)*(H-H_current).
```

MAP02 independently finds that the actual local corrector response is instead:

```
q_swap(H)
  ~= q_swap_current - (u/dt)*(H-H_current)
```

for this fixture.

The intercept is therefore made exact by reanchoring while the local tangent
has the opposite sign from the measured corrector tangent.

## 6. Why this is not yet enough for a defect claim

The unresolved semantic question is what physical quantity the historical
`q_u` represents.

Two distinct objects already exist:

1. bottom-interface exchange `q_swap`, whose accepted whole-window integral is
   the groundwater-interface mass-ledger authority;
2. historical `q_u/u` response, derived from the inverse qbot-to-head
   sensitivity and a storage-like head-change term.

If `u` is the local storage sensitivity

```
u ~= dS/dH,
```

then the opposite bottom-flux tangent follows directly from the water balance:

```
dE_bottom,out/dH ~= -dS/dH.
```

In that case the sign inversion is physically expected, but using a
`+u/dt` line after reanchoring its intercept to a physical bottom flux mixes
two response semantics.

If `u` is not a storage sensitivity, another explanation is required.

## 7. MAP03 decision test

MAP03 therefore measures, from the same real FMR transaction result:

```
accepted_storage_change
accepted_total_in
accepted_total_out
accepted_bottom_outward_exchange
accepted_mass_residual
```

at the same fixed heads as MAP02.

The prospectively registered local identities are:

```
d(storage_change)/dH          ~= +u
d(bottom_outward_exchange)/dH ~= -u
d(storage + bottom_outward)/dH ~= 0
```

for this simple fixture where other active external forcing is head-independent.

Only after this mass-response audit should the production response contract be
reinterpreted or modified.

## 8. Current boundary

No production source has been changed.

Do not:

- flip the F-GC33 sign from MAP02 alone;
- rename `u` to physical storage before MAP03;
- treat `q_u` and `q_swap` as synonyms;
- infer a finite-resistance q-link from this shared-head fixture.
