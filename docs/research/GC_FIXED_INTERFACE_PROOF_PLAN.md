# Fixed-interface response hierarchy and proof plan

Date: 2026-09-21  
Status: RESEARCH PLAN, NO PRODUCTION CHANGE

## Purpose

The fixed-interface programme now has an explicit separation between physical theory, exact mathematics, response condensation and numerical implementation. The next experiments increase physical complexity only after the previous response object is understood.

## Level A: NH01 physical oracle

NH01 establishes one geometric coupling plane with one interface head \(H_c\), while the top-system phreatic state \(z_p\) can differ because of vertical resistance inside the top system.

Qualified mathematical target:

\[
z_p=8.06,\quad H_c=8.04,\quad E_c=0.004\;m.
\]

This is the minimum nonhydrostatic counterexample to the false identity \(H_c\equiv z_p\).

## Level B: NH02 response condensation

NH02 uses the same physics and asks whether the historical predictor construction recovers the exact eliminated response.

The prospective identities are

\[
u=\frac{C\Delta t S_S}{S_S+C\Delta t}
\]

and

\[
q_u=\frac{u}{S_S}\frac{W_S}{\Delta t}.
\]

For the linear oracle these are independent of predictor bottom flux. The physical corrector derivative is \(-u/\Delta t\), while the historical affine partial slope is \(+u/\Delta t\).

NH02 must first prove these identities independently. A later backend test may then prove the MODFLOW HCOF/RHS sign mapping.

## Level C: NH03 nonlinear top-system storage

Do not add new process physics yet. Replace constant \(S_S\) by a monotone storage law \(V_S(z_p)\), while retaining the same internal vertical conductance and fixed interface head.

The exact equations become

\[
V_S(z_{p1})-V_S(z_{p0})=W_S-C\Delta t(z_{p1}-H_c)
\]

and

\[
\Delta V_M=W_M+C\Delta t(z_{p1}-H_c).
\]

This test determines whether the response coefficient is a local tangent only and how predictor-derived \(u\) differs from the secant/integrated storage response over a finite window.

Preregister before implementation.

## Level D: NH04 state-dependent external process

After NH03, add one transparent head-dependent ET or drain term to the top-system balance. This determines how a physical external-process derivative enters the condensed response without being misclassified as storage.

The target is an exact decomposition

\[
J_{condensed}=J_{storage}+J_{process}+J_{hydraulic/memory}
\]

with every term tied to its parent physical quantity.

## Level E: NH05 memory

Add one internal state that is not determined by \(H_c\) or \(z_p\) alone. Equal interface head at the beginning of a window must be able to produce different response functions when the committed top-system memory differs.

This tests the minimum response state needed by a production coupling API.

## Level F: real SWAP bridge

Only after A-E are mathematically closed should the programme use real SWAP to ask whether the same structural identities survive Richards physics.

The real-SWAP bridge should measure independently:

1. accepted interface head;
2. accepted bottom/interface flux;
3. complete SWAP water-storage change;
4. phreatic elevation diagnosed by SWAP;
5. external ET/drain/top fluxes;
6. predictor \(dH_c/dq_b\);
7. corrector \(dq_c/dH_c\);
8. whole-window mass ledger.

The production \(u/q_u\) pair is then compared to these measured response objects. It is not the authority used to define them.

## Backend proof is a separate numerical unit

The HCOF/RHS mapping must be tested only after the exact response sign convention is frozen. The backend proof asks a narrower question:

> Does the MODFLOW affine term solve the already-derived scalar residual with the exact same root and ledger?

This avoids using a backend sign convention to infer physical meaning.

## Architecture gate

No production coupling change is justified by NH01/NH02 alone. Conversely, no production code success can override a failed analytical oracle. The current implementation remains a candidate realization of the fixed-interface theory until the theory-to-code chain is prospectively closed.
