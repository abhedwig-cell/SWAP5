# Fixed-interface theory to production reconciliation

Date: 2026-09-21
Status: RESEARCH RECONCILIATION, NO PRODUCTION CHANGE

## Physical state contract

The current typed interface contract and independently derived fixed-interface theory agree on the primary coupled-state semantics. SWAP mode 5 is converted between lower-face pressure head and hydraulic head using explicit bottom-boundary elevation. The interface residual compares the SWAP and groundwater hydraulic heads at that plane and enforces flux action/reaction. Nothing in the typed contract defines this head as the SWAP phreatic elevation.

## Production response chain

The predictor computes:

    u = dt / (dH_bot/dq_bot)
    q_u = u*(H_end-H_start)/dt - q_bot

Native q_bot is positive into SWAP; public q_u is documented positive outward from SWAP.

The MultiSWAP cell response reanchors every tile at a common groundwater-cell reference head:

    q_u_ref = q_u_pred + (u/dt)*(H_ref-H_pred)

It area-weights q_u_ref and u and defines:

    dq_u/dH = u_cell/dt

The linear backend then constructs:

    Q(H) = Q_ref + K*(H-H_ref)
    K = area*dq_u/dH
    HCOF = K
    RHS = K*H_ref - Q_ref

and evaluates Q(H)=HCOF*H-RHS. Thus HCOF/RHS exactly reconstructs the public affine response law.

## Source-proved alignment with the analytical programme

The production code already carries the essential numerical response metadata identified by NH01-NH05: response origin, response value, tangent, window, lineage/provenance, area aggregation and deterministic reanchoring.

Therefore the theory does not imply that MODFLOW must receive SWAP internal memory. Memory can remain encapsulated in SWAP, provided every trial response is generated from the correct immutable committed SWAP origin.

## HCOF/RHS sign reconciliation

The linear backend itself adds no unexplained sign inversion. It evaluates exactly the public response law.

The remaining sign question is at the point where this positive-outward-from-SWAP response is inserted into the MODFLOW groundwater residual/package convention. That insertion must be checked before end-to-end sign qualification.

## NH01 relation

NH01 proves for the transparent fixed-interface system:

    u = C*dt*S_S/(S_S+C*dt)
    dE_c/dH_c = -u

while the historical response condensation has:

    dq_u_affine/dH_c = +u/dt

Current source implements the latter positive affine slope. This is not a contradiction because q_u is a condensed groundwater-balance response, not the accepted bottom-exchange ledger.

The decisive test is whether inserting the positive-slope response into MODFLOW gives the independently derived coupled root and whether the accepted physical ledger then closes.

## NH03-NH05 relation

NH03 predicts trajectory-local u under nonlinear physics. Current source carries an explicit response origin and supports reanchoring. This is structurally compatible but does not prove tangent validity over large nonlinear excursions.

NH04 predicts process derivatives can enter the condensed tangent. Current derivative coverage explicitly tracks dynamic top boundary, root uptake, drainage and other state-dependent sources/sinks before an analytic trajectory tangent is authoritative. This strongly agrees with the theory.

NH05 predicts equal head can have different response intercepts because of committed internal memory. Current predictor lineage carries SWAP lineage and origin revision. This is structurally appropriate, but a dedicated stale-origin/memory qualification is still required.

## Architecture assessment

No conceptual production redesign is justified at this point. Current source is substantially aligned with fixed-interface theory:

- lower-face hydraulic-head semantics are explicit;
- response origin and tangent are explicit;
- process derivative coverage is explicit;
- provenance is explicit;
- MultiSWAP aggregation preserves affine response structure;
- backend HCOF/RHS exactly encodes that affine law.

The remaining questions are narrower qualification questions:

1. end-to-end MODFLOW package sign and residual placement;
2. accepted physical ledger versus predictor response at the converged root;
3. nonlinear tangent validity/relinearization;
4. committed SWAP-memory origin validity;
5. N:1 physical ledger aggregation.
