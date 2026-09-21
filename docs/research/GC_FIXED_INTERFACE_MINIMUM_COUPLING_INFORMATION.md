# Fixed-interface minimum coupling information

Date: 2026-09-21  
Status: RESEARCH SYNTHESIS, NO PRODUCTION CHANGE

The NH01-NH05 analytical chain supports a sharper separation between **coupling state**, **SWAP internal state**, and **response information**.

## Coupling state

The physical coupling state is the hydraulic head \(H_c\) at the fixed geometric interface. MODFLOW and SWAP must refer to the same physical head at that plane.

The SWAP phreatic elevation is not an additional MODFLOW coupling state. It is an internal/diagnostic state of the top-system solution and may differ from \(H_c\).

## Internal SWAP state

NH05 proves by construction that two SWAP states can have equal \(H_c\) and equal instantaneous phreatic elevation but different next-window response because committed internal memory differs.

Therefore the response operator is generally

\[
\mathcal S(H_c,\mathbf x_S^n,\mathbf f,\Delta t),
\]

not merely \(\mathcal S(H_c)\).

The coupling API does not consequently need to export all of \(\mathbf x_S\). SWAP must, however, preserve the correct committed state internally while evaluating trial responses.

## Minimum response information for a local affine groundwater solve

For a scalar interface head and one coupling window, a local condensed response requires at least:

1. response origin \(H_*\);
2. response value/intercept \(R_*\) at that origin;
3. response tangent \(J_*=\partial R/\partial H_c\);
4. window identity and duration;
5. sign and unit contract;
6. provenance tying the response to one immutable committed SWAP origin state;
7. validity/admissibility information for the local response.

NH03 shows \(J_*\) is trajectory/local-state dependent under nonlinearity. NH04 shows \(J_*\) can contain process sensitivity in addition to storage/hydraulic sensitivity. NH05 shows \(R_*\) can change while \(J_*\) remains unchanged because of internal memory.

Therefore neither a head alone nor a tangent coefficient alone is a sufficient general coupling response.

## Accepted-state ledger remains separate

A predictor response is not the accepted physical exchange. The coupling must separately retain/produce the committed whole-window interface ledger after convergence.

The minimum conceptual API therefore has two distinct products:

### Trial response

\[
(H_*,R_*,J_*,provenance,validity)
\]

used to solve the groundwater trial equation.

### Accepted ledger

\[
E_c^{accepted}
\]

plus the component mass-accounting evidence required to commit the window.

These must not be conflated.

## Relation to current u/q_u

The current pair \(u,q_u\) is structurally capable of carrying a scalar affine response, provided its exact origin, sign, units and provenance correspond to the derived fixed-interface residual.

The analytical chain suggests:

- \(u\) is best named a **condensed response coefficient** unless a narrower identity is proved for a particular regime;
- \(q_u\) is a **response intercept/balance term**, not automatically the accepted physical interface flux;
- the accepted bottom/interface ledger remains authoritative for physical mass transfer;
- SWAP internal memory remains owned by SWAP, not serialized into MODFLOW merely because it affects \(q_u\) or \(u\).

## What has not yet been proved

The NH chain does not yet prove that the production HCOF/RHS mapping has the correct sign and origin convention.

It also does not prove that one scalar affine response is adequate for all nonlinear real-SWAP regimes. Strong curvature may require relinearization, smaller coupling windows or a richer response representation.

Those are subsequent numerical/qualification questions, not changes to the physical interface concept.
