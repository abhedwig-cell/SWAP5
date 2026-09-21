# NH03 nonlinear-storage derivation

Date: 2026-09-21  
Status: MATHEMATICAL ORACLE DERIVED, NO PRODUCTION CHANGE

NH03 retains the NH01 fixed geometric interface and internal vertical conductance, but replaces constant top-system storage by

\[
\Delta V_S(x)=S_0x+\tfrac12 S_1x^2,\qquad x=z_{p1}-z_{p0}.
\]

The groundwater increment is \(y=H_{c1}-H_{c0}\). With equal initial heads and no groundwater external input,

\[
S_My=C\Delta t(x-y)
\]

so

\[
y=\frac{C\Delta t}{S_M+C\Delta t}x.
\]

For the preregistered values \(S_M=0.10\), \(C\Delta t=0.20\), this is \(y=2x/3\).

The top balance is

\[
S_0x+\tfrac12S_1x^2=W_S-C\Delta t(x-y).
\]

Substitution gives

\[
0.5x^2+0.166666666666667x-0.01=0.
\]

The physically continuous root near the initial state is

\[
x=0.0519146174767334\;m,
\]

hence

\[
z_{p1}=8.051914617476733\;m,
\]

\[
H_{c1}=8.034609744984489\;m,
\]

and

\[
E_c=0.00346097449844889\;m.
\]

Top storage changes by \(0.00653902550155111\) m and groundwater storage by \(0.00346097449844889\) m, summing exactly to the 0.010 m external input.

## Distinct storage measures

At the accepted state the physical local storage tangent is

\[
S_{tan}=S_0+S_1x=0.151914617476733.
\]

The finite-window secant storage coefficient is

\[
S_{sec}=\frac{\Delta V_S}{x}
=S_0+\tfrac12S_1x
=0.125957308738367.
\]

They are already materially different in this deliberately nonlinear oracle. Neither may be silently called \(u\).

## Exact condensed response derivative

For a trial interface head \(H_c\), the top-system implicit equation is

\[
G(z_p,H_c)
=
\Delta V_S(z_p)-W_S+C\Delta t(z_p-H_c)=0.
\]

Implicit differentiation gives

\[
\frac{dz_p}{dH_c}
=
\frac{C\Delta t}{S_{tan}+C\Delta t}.
\]

Since

\[
E_c=C\Delta t(z_p-H_c),
\]

\[
\frac{dE_c}{dH_c}
=
-C\Delta t\frac{S_{tan}}{S_{tan}+C\Delta t}.
\]

Define the accepted local condensed response magnitude

\[
u_{loc}
=
C\Delta t\frac{S_{tan}}{S_{tan}+C\Delta t}.
\]

At the NH03 root,

\[
u_{loc}=0.086335\ldots
\]

and

\[
dE_c/dH_c=-u_{loc}.
\]

Thus the NH01 structure survives, but the storage entering the local response is the **accepted local tangent**, not the finite-window secant storage.

## Predictor-derived response

For an imposed predictor bottom flux \(q_b\) positive into the top system,

\[
\Delta V_S(z_p)=W_S+q_b\Delta t,
\qquad
H_c=z_p+\frac{q_b}{C}.
\]

Differentiation gives

\[
\frac{dH_c}{dq_b}
=
\frac{\Delta t}{S_{tan,pred}}+\frac1C,
\]

therefore the historical construction gives

\[
u_{pred}
=
\frac{\Delta t}{dH_c/dq_b}
=
C\Delta t\frac{S_{tan,pred}}{S_{tan,pred}+C\Delta t}.
\]

This is a local tangent tied to the **predictor trajectory**. In a nonlinear system different predictor fluxes generally produce different \(S_{tan,pred}\) and hence different \(u_{pred}\).

This is the central NH03 prediction: production-style \(u\) need not equal the accepted-state condensed tangent unless the predictor origin is sufficiently close, or the response is relinearized/iterated.

## Scientific consequence

NH03 separates four quantities:

1. physical local storage tangent \(S_{tan}\);
2. finite-window storage secant \(S_{sec}\);
3. predictor-derived condensed tangent \(u_{pred}\);
4. accepted corrector response \(dE_c/dH_c=-u_{loc}\).

They coincide only in special linear/limiting cases. This gives a precise mathematical mechanism for why real-SWAP \(u\) can be close to, but not exactly equal to, measured accepted storage sensitivity.
