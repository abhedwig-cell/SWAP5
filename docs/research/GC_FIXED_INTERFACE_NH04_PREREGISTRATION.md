# NH04 state-dependent process preregistration

Date: 2026-09-21  
Status: PREREGISTERED MATHEMATICS, NOT IMPLEMENTED  
Production changes: none

NH04 keeps constant top storage and the fixed-interface hydraulic structure of NH01, then adds exactly one transparent external sink. This isolates process sensitivity before memory or Richards nonlinearity is introduced.

Let integrated ET over the coupling window be

\[
E_T(z_p)=E_{T0}+K_T(z_p-z_{p0}).
\]

Parameters are

\[
S_S=0.10,\ S_M=0.10,\ C=0.20/day,\ \Delta t=1day,
\]
\[
W_S=0.010m,\ W_M=0,\ E_{T0}=0.002m,\ K_T=0.020.
\]

The balances are

\[
S_Sx=W_S-E_{T0}-K_Tx-C\Delta t(x-y)
\]

and

\[
S_My=C\Delta t(x-y).
\]

The preregistered exact root is

\[
x=0.0428571428571429m,\qquad
y=0.0285714285714286m.
\]

Therefore

\[
z_{p1}=8.042857142857143m,
\quad
H_{c1}=8.028571428571429m,
\]
\[
E_c=0.00285714285714286m,
\quad
E_T=0.00285714285714286m.
\]

The complete external balance is

\[
\Delta V_S+\Delta V_M=W_S-E_T.
\]

## Condensed derivative

At fixed trial \(H_c\), the top equation is

\[
(S_S+K_T)(z_p-z_{p0})-W_S+E_{T0}
+C\Delta t(z_p-H_c)=0.
\]

Hence

\[
\frac{dz_p}{dH_c}
=
\frac{C\Delta t}{S_S+K_T+C\Delta t}
\]

and

\[
\frac{dE_c}{dH_c}
=
-C\Delta t\frac{S_S+K_T}{S_S+K_T+C\Delta t}.
\]

The process derivative enters the condensed interface response alongside storage, but it is not physical storage.

For these parameters the response magnitude is

\[
u_{cond}
=
0.20\frac{0.12}{0.32}
=
0.075.
\]

This deliberately differs from the NH01 value 0.0666667 even though physical storage \(S_S\) is unchanged.

## Falsification gates

Implementation must reproduce the exact root, ET, interface transfer and complete mass ledger to \(10^{-12}\) m.

It must separately report:

- physical storage derivative \(S_S=0.10\);
- process derivative \(K_T=0.020\);
- combined top-balance tangent \(S_S+K_T=0.12\);
- condensed response magnitude \(0.075\);
- physical interface derivative \(dE_c/dH_c=-0.075\).

Calling the 0.075 coefficient "storage" fails the semantic gate even if the numerical root is correct.
