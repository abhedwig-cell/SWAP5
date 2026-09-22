# NH05 internal-memory preregistration

Date: 2026-09-21  
Status: PREREGISTERED MATHEMATICS, NOT IMPLEMENTED  
Production changes: none

## Question

Is interface head \(H_c\), even together with instantaneous phreatic state \(z_p\), sufficient to predict the next-window SWAP response?

NH05 introduces one committed internal memory state \(m\) representing delayed top-system water release. It is deliberately simple and analytically transparent.

## Model

Keep the NH01 fixed-interface geometry with

\[
S_S=0.10,\quad S_M=0.10,\quad C=0.20/day,\quad \Delta t=1day.
\]

For the proof window use zero new atmospheric forcing:

\[
W_S=W_M=0.
\]

At the start both cases have

\[
z_{p0}=H_{c0}=8.0m,
\]

but different committed memory:

Case A:
\[
m_0=0.
\]

Case B:
\[
m_0=0.006m.
\]

Memory releases a fixed fraction

\[
r=\lambda m_0,\qquad \lambda=0.5
\]

during this window and the committed remainder is

\[
m_1=(1-\lambda)m_0.
\]

The released amount is an **internal transfer from memory inventory into mobile top-system water**, not an external source. Therefore the mobile top balance is

\[
S_S(z_{p1}-z_{p0})=r-E_c,
\]

the memory balance is

\[
m_1-m_0=-r,
\]

and groundwater is

\[
S_M(H_{c1}-H_{c0})=E_c.
\]

The complete inventory is

\[
V_{tot}=V_S+V_M+m.
\]

Hence with no external forcing

\[
\Delta V_S+\Delta V_M+\Delta m=0.
\]

## Exact predictions

Case A remains unchanged:

\[
z_{p1}=H_{c1}=8.0,\quad E_c=0.
\]

For Case B, \(r=0.003m\). Solving the same linear hydraulic partition as NH01 gives

\[
z_{p1}-z_{p0}=0.018m,
\]

\[
H_{c1}-H_{c0}=0.012m,
\]

\[
E_c=0.0012m.
\]

Mobile top storage increases by 0.0018 m, groundwater storage by 0.0012 m, and memory decreases by 0.003 m. Total change is zero.

## Semantic gate

At the beginning of the window both cases have identical \(H_c\) and \(z_p\), yet they have different future interface response because \(m_0\) differs.

Therefore a coupling formulation that assumes the future SWAP response is a single-valued function of interface head alone is incomplete whenever committed internal SWAP memory materially affects the window response.

This does **not** imply MODFLOW must receive the full SWAP state. It implies that SWAP must retain the committed internal state when constructing its response operator.

## Response implication

For this linear release law, the derivative \(dE_c/dH_c\) can remain the same between cases while the response intercept changes. Thus tangent information alone is insufficient to identify the future exchange law.

NH05 therefore tests both parts of a local affine response:

\[
R(H)=R_*+J_*(H-H_*).
\]

Equal \(J_*\) does not imply equal \(R_*\).

## Falsification gates

- Case A and B must begin with identical \(H_c,z_p\).
- They must produce the preregistered different future responses.
- The memory release must appear as an internal ledger transfer, not external water.
- Complete mass error including \(m\) must be at most \(10^{-12}m\).
- Omitting memory from the complete inventory must exhibit the expected false mass creation in Case B.
