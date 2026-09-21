# PB01 production reanchoring source audit

Date: 2026-09-21
Status: SOURCE MECHANISM CONFIRMED; ORCHESTRATION USE STILL REQUIRES CALL-SITE PROOF

## Confirmed source behavior

The production backend `mod_modflow6_linear_response_backend.f90` explicitly exports
`reanchor_modflow6_linear_boundary_term`.

Given an existing linear term, a hydraulic head H_k and a supplied flux q_k, it keeps
`hcof_m2_per_day` unchanged and recomputes

    RHS_k = HCOF * H_k - A*86400*q_k.

Consequently the reanchored MODFLOW boundary satisfies exactly

    Q_sur(H_k) = HCOF*H_k - RHS_k = A*86400*q_k.

Thus the backend has a first-class operation implementing the reanchoring object used
in the PB01 mathematical analysis.

The same module also confirms the base convention

    Q(H) = HCOF*H - RHS

with

    HCOF = A*86400*dq_u_dh

and the MultiSWAP composer currently supplies

    dq_u_dh = u / duration_s.

Therefore the current backend preserves the positive +u/dt slope during reanchoring.

## What this proves

It proves that reanchoring is not merely an artifact invented in the F-GC44 test harness:
the production runtime contains an explicit reanchoring primitive with precisely that
mathematical operation.

It does NOT yet prove that every actual production outer coupling iteration calls that
primitive, at which point in the solve it is called, or whether damping/relaxation changes
the head update.

## PB01 consequence

For NH01, executed analytical evidence gives error amplification rho=-4 for an undamped
outer iteration that repeatedly reanchors while retaining +u/dt. Therefore existence of
the reanchor primitive is insufficient to establish convergence.

The remaining production audit must locate:
1. call sites of the reanchor primitive or equivalent RHS update;
2. the accepted SWAP flux supplied to q_k;
3. any head/flux relaxation, damping, under-relaxation, retry or solver-side nonlinear
   treatment between successive anchors.

No production sign change is justified before that audit and the live one-cell fixture.
