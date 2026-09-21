# Dummy-SWAP / MODFLOW6 shared-storage research line

Date: 2026-09-21
Status: PROPOSED RESEARCH HARNESS
Canonical baseline: `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`

## Purpose

This workstream replaces real SWAP physics with deliberately transparent toy
models while preserving the existing SWAP5-MODFLOW6 coupling mathematics and
MODFLOW6 prepared-solve boundary. The purpose is to determine what the current
exchange flux and coupling storage coefficient mean physically, especially
when SWAP and MODFLOW represent a shared groundwater state or overlapping
storage volume.

This is not a production SWAP replacement and does not change Reference
Richards, RossFast, production groundwater coupling, transaction ownership or
the F-GC49 production ABI.

## First physical oracle

Use one vertical column of unit horizontal area:

- soil surface elevation: 10 m;
- model bottom datum: 0 m;
- initial groundwater head: 8 m, hence groundwater depth 2 m;
- column thickness: 10 m;
- drainable storage / effective porosity: 0.20;
- precipitation over one day: 0.010 m;
- no runoff;
- no evapotranspiration;
- no capillary rise;
- no drainage;
- no lateral flow;
- no vertical resistance;
- instantaneous atmospheric transfer to groundwater.

For the physical system, if the 0.20 storage is counted exactly once,

```
Delta H = P / S = 0.010 / 0.20 = 0.050 m
H1      = 8.050 m
```

That 5 cm rise is the first independent oracle.

## Dummy-SWAP response

For a prescribed lower-boundary trial flux `q_bot`, positive upward into the
dummy column, the transparent bucket is

```
H_end = H_start + (R + q_bot) * dt / S
dH_end / dq_bot = dt / S
```

Using the historical SWAP coupling transform already implemented in
`mod_modflow6_swap_predictor_response`,

```
u   = dt / (dH_end/dq_bot)
q_u = u * (H_end-H_start) / dt - q_bot
```

the dummy model gives exactly

```
u   = S
q_u = R
```

for every prescribed `q_bot`. This is useful because both quantities have a
known meaning before MODFLOW is involved.

## Important distinction

The repository field `coupling_storage_coefficient_u` is dimensionless and
the admitted F-GC40/F-GC33 route turns it into

```
dq_u/dH = u / dt
```

and then into a MODFLOW HCOF term. It must therefore not be called a generic
"exchange conductance" without qualification. In this first oracle it is
exactly the dummy column's drainable storage coefficient.

A separate vertical-resistance experiment will later introduce a true
head-difference-controlled conductance. Keeping these concepts separate is a
main goal of this workstream.

## Shared-storage question

For the zero-resistance dummy with predictor `q_bot=0`:

```
H_ref = H_start + R*dt/u
q_ref = R
q_u(H) = q_ref + (u/dt)*(H-H_ref)
       = (u/dt)*(H-H_start)
```

Thus the rainfall disappears from the explicit intercept after the predictor
reference point is substituted; it is encoded in the location of
`(H_ref,q_ref)`.

If MODFLOW also assigns storage coefficient `S_mf=u` to the same physical
water volume, its local transient storage flux has the same magnitude and
head dependence as the coupling tangent. Under a same-volume interpretation
this creates a possible duplicated/shared-storage degeneracy. That is the
specific hypothesis to test. It is stronger and more precise than the loose
statement "storage may be counted twice".

The alternative interpretation is that SWAP's `u` and MODFLOW storage belong
to physically disjoint storage volumes that merely share a head. Then both
terms may legitimately coexist. The experiment must distinguish those domain
definitions rather than infer correctness from numerical convergence alone.

## Pre-registered first experiments

### DSW-01A: analytic identity

Prove in a dependency-free oracle that:

1. the physical one-storage answer is +0.050 m;
2. dummy-SWAP produces `u=0.20` and `q_u=0.010 m/day`;
3. the F-GC affine response passes through zero flux at the initial head for
   the `q_bot=0` predictor;
4. with `S_mf=u`, the MODFLOW storage slope and coupling slope are identical
   in magnitude.

This is an algebraic diagnosis only. It does not assume MODFLOW's assembled
matrix sign convention.

### DSW-01B: live MODFLOW6 one-cell experiment

Run MODFLOW6 6.8.0 with one convertible 1 m2 cell, no horizontal flow and
`sy=0.20`.

Control:

- API term is constant +0.010 m3/day recharge;
- expected head is 8.050 m.

Current-coupling probe:

- use the affine term implied by `u=0.20`, `H_ref=8.050 m`,
  `q_ref=0.010 m/day`;
- record convergence and the resulting head;
- do not tune coefficients after observing the result.

The control must pass the 8.050 m oracle. The current-coupling probe is
diagnostic: singularity, non-convergence, no rise, a different rise or the
expected rise are all evidence to interpret against the exact assembled
equation.

## Planned progression

After DSW-01, increase complexity one mechanism at a time:

1. **DSW-02 vertical resistance**: add a linear lower-zone resistance and
   separate conductance from storage response.
2. **DSW-03 depth-dependent storage**: let drainable storage vary with
   groundwater head, including the proposed coarse-to-fine depth profile.
3. **DSW-04 head-dependent ET**: add a bounded monotone evaporation sink as
   groundwater approaches the root zone.
4. **DSW-05 drain**: add a linear drain above a fixed drain elevation.
5. **DSW-06 controlled nonlinearities**: piecewise/nonlinear storage,
   resistance, ET and drainage while retaining an independent numerical
   oracle.
6. **DSW-07 domain-partition sweep**: vary the fraction of physical storage
   owned by dummy SWAP versus MODFLOW and test which coupling representation
   preserves one physical water balance.

Every stage must retain a known mass-balance oracle and a declared storage
ownership map.

## Decision rule

Do not change production coupling from this research branch. First determine
which of these statements is supported:

- `u` is a response tangent whose storage contribution is correctly
  complementary to MODFLOW storage under the admitted domain partition;
- `u` represents storage already present in MODFLOW for overlapping domains
  and therefore needs an explicit shared-storage correction/partition;
- the current affine transform is correct only for a narrower coupling
  topology than presently assumed;
- another interpretation is required by the live assembled equations.

Only after that result is stable should a separate production contract change
be proposed.
