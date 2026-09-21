# Shared-state storage mapping: literature versus current SWAP5 route

Date: 2026-09-21
Status: RESEARCH RECONCILIATION
Baseline: `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`

## Question

Does the current SWAP5-MODFLOW6 affine API term represent the same mathematical
object as the phreatic storage coefficient in the shared-state h-link
formulation of Van Walsum and Veldhuizen (2011)?

At this stage the answer is **not established**. The implementations place the
storage-related information in different MODFLOW mechanisms and must therefore
be compared at equation level.

## Literature h-link

Van Walsum and Veldhuizen (2011) use the phreatic level as a shared state
variable. Their complete vertical-profile balance can be written as

```
S_new = S_star + (q_msw + q_mod) dt
```

where `S_star` is storage after the unsaturated-process substep, `q_msw`
is the remaining unsaturated flux for the phreatic update, and `q_mod` is the
net saturated-flow contribution calculated by MODFLOW.

MetaSWAP also communicates the storage response of the complete vertical
profile to changes in shared head. In linearized form:

```
mu * (h_new-h_old) = (q_msw+q_mod) dt
```

The paper's q-link equivalence experiment makes additional MODFLOW storage
almost zero. This is evidence that independent aquifer storage is not simply
added on top of the h-link complete-profile storage when both describe the same
physical volume.

Reference: P.E.V. van Walsum and A.A. Veldhuizen (2011), Journal of Hydrology
409, 363-370, DOI 10.1016/j.jhydrol.2011.08.036.

## Current iMOD Coupler statement

Current iMOD Coupler technical documentation states that MetaSWAP provides
recharge and sets the storage in coupled MODFLOW cells. Multiple SVAT storages
are summed for a MODFLOW cell.

Reference: https://deltares.github.io/imod_coupler/technical.html

## Current SWAP5 route

Current canonical SWAP5 constructs

```
u   = dt_day / (dH_bot_cm / dq_bot_cm_per_day)
q_u = u * (H_end_cm-H_start_cm) / dt_day - q_bot
```

in `src/runtime/mod_modflow6_swap_predictor_response.f90`.

F-GC40 then uses

```
q_u(H) = q_ref + (u/dt_s) * (H-H_ref)
```

and F-GC33 maps it to the MODFLOW API package as

```
Q(H) = HCOF*H - RHS
HCOF = A*86400*dq_u/dH
```

The MODFLOW API package adds supplied HCOF directly to the solution matrix
diagonal and supplied RHS to the solution right-hand side. It does not by
definition replace the STO package.

The current F-GC49D/F-GC45 qualification fixtures contain a MODFLOW STO package while the F-GC33 affine API term is active. Both mechanisms can therefore coexist in the admitted implementation. MAP11 shows, however, that coexistence in these synthetic fixtures is not evidence that both mechanisms own the same physical storage volume.

## Current F-GC state/domain distinction

MAP11 adds a source-bound distinction that is required before applying the
literature h-link analogy to the current F-GC route.

The canonical coupling contract maps SWAP mode-5 lower-boundary pressure head
to hydraulic head using

```
H_interface = z_bottom_face + psi_bottom_face.
```

The prescribed-qbot bottom-face implementation explicitly documents this as a
coupling-plane head and states that it is not the freatic groundwater level.

The head-driven FMR corrector performs the inverse mapping and writes the result
to `bottom_head`. It does not, through that adapter, overwrite the SWAP
physical state's stored groundwater-level field.

The F-GC45 qualification fixture also does not construct a geometrically
coextensive storage domain:

- MODFLOW uses a 1 m by 1 m cell, 2 m thick, with `Sy=0.15` and
  `Ss=0.02 1/m`;
- the FMR fixture uses the four-node legacy test grid
  `dz=[0.5,0.5,1.0,1.0]`, which is passed into the coupling-face routines in
  centimetre units;
- no authority file declares those two storages to be the same physical
  volume.

Therefore F-GC45 can qualify the numerical interface coupling and its accepted
mass ledger, but it cannot prove either storage duplication or storage
partition equivalence between SWAP and MODFLOW STO.

## Why equivalence cannot be assumed

For the DSW-01 transparent bucket,

```
S = u = 0.20
R = 0.010 m/day
h0 = 8.00 m
href = 8.05 m
qref = 0.010 m/day
```

the current affine response simplifies to

```
q_u(H) = (S/dt)*(H-h0)
```

The same coefficient magnitude can then appear in the physical shared-storage
law, in MODFLOW STO if `Sy=S`, and in the SWAP5 API HCOF response if
`u=S`. Whether that is correct, complementary, duplicated or cancelling
depends on exact assembled signs and intended domain ownership.

## Competing hypotheses

1. **STO replacement equivalence**: API term plus MODFLOW configuration is
   algebraically equivalent to replacing phreatic storage with the SWAP
   complete-profile response.
2. **Complementary partition**: MODFLOW STO and SWAP `u` describe disjoint
   storage volumes and correctly sum to total storage.
3. **Overlapping duplication**: STO and `u` partly or wholly describe the
   same volume, causing duplicate or misplaced storage.
4. **Pure tangent interpretation**: `u` is only a trajectory
   response/Jacobian, not storage ownership. If so, a separate derivation must
   prove that the affine API equation still reproduces the physical balance.

## Required proof

Before changing or defending production semantics:

1. derive the one-cell MODFLOW STO plus API equation with exact signs;
2. reproduce it with a live one-cell solve;
3. map the DSW-01 bucket into it;
4. sweep storage ownership independently of convergence;
5. verify final physical storage change against external volume;
6. prove reference-point invariance;
7. test the finite-resistance q-link limit separately;
8. repeat for nonlinear storage where tangent and secant differ.

A converged mixed-topology application test is not sufficient evidence for
these equation-level claims.
