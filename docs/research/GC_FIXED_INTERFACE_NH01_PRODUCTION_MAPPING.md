# NH01 production-response mapping

Date: 2026-09-21  
Status: THEORY-TO-PRODUCTION HYPOTHESIS, NO PRODUCTION CHANGE

## 1. Exact dummy response

NH01 gives, after eliminating the internal phreatic state,

\[
E_c(H_c)=\beta[W_S+S_S(z_{p0}-H_c)],
\qquad
\beta=\frac{C\Delta t}{S_S+C\Delta t}.
\]

\(E_c\) is integrated interface transfer, positive from SWAP/top system to groundwater. Therefore

\[
\frac{dE_c}{dH_c}=-\beta S_S.
\]

Define outward interface flux \(q_c=E_c/\Delta t\). Then

\[
\frac{dq_c}{dH_c}=-\frac{\beta S_S}{\Delta t}.
\]

For NH01 this is \(-0.0666666667/day\).

## 2. Predictor experiment on the same dummy physics

Production obtains \(u\) from the inverse response of terminal bottom/interface head to an imposed predictor bottom flux.

To mirror that definition, prescribe a predictor bottom flux \(q_b\) positive **into the top system**, with \(H_c\) as the terminal interface head. Over the window the top-system balance is

\[
S_S(z_p-z_{p0})=W_S+q_b\Delta t
\]

and the internal hydraulic relation is

\[
q_b=C(H_c-z_p).
\]

Eliminating \(z_p\) gives

\[
H_c
=
z_{p0}+\frac{W_S}{S_S}
+
q_b\left(\frac{\Delta t}{S_S}+\frac{1}{C}\right).
\]

Hence

\[
\frac{dH_c}{dq_b}
=
\frac{\Delta t}{S_S}+\frac{1}{C}.
\]

Applying the production definition

\[
u=\frac{\Delta t}{dH_c/dq_b}
\]

gives

\[
u
=
\frac{\Delta t}
     {\Delta t/S_S+1/C}
=
\frac{C\Delta t\,S_S}{S_S+C\Delta t}
=
\beta S_S.
\]

This is exact for NH01.

Therefore

\[
\boxed{u=\beta S_S}
\]

and

\[
\boxed{\frac{dq_c}{dH_c}=-\frac{u}{\Delta t}}.
\]

This reproduces, in a fully analytical fixed-interface model, the sign/magnitude structure observed in MAP03: storage-like condensed response \(+u\), accepted outward interface-flux response \(-u/\Delta t\).

## 3. Meaning of u in this oracle

This result is more precise than either "u is storage" or "u is exchange conductance".

For NH01, \(u\) is the **finite-window condensed top-system response coefficient** obtained after eliminating the internal phreatic state:

\[
u=S_S\frac{C\Delta t}{S_S+C\Delta t}.
\]

It depends jointly on:

- physical top-system storage \(S_S\);
- internal vertical hydraulic conductance \(C\);
- coupling-window duration \(\Delta t\).

Thus:

- \(u\to S_S\) for \(C\Delta t\gg S_S\);
- \(u\to C\Delta t\) for \(C\Delta t\ll S_S\);
- \(u\) is window dependent for finite \(C\);
- \(u/\Delta t\) is not the physical conductance \(C\);
- \(u\) need not equal the full physical storage coefficient \(S_S\).

This provides an analytical explanation for the previously observed window dependence of production \(u\).

## 4. q_u algebra on the dummy

Production defines

\[
q_u=u\frac{H_{c,end}-H_{c,start}}{\Delta t}-q_b.
\]

For the predictor equations above, multiply the head-change relation by \(u/\Delta t\):

\[
u\frac{\Delta H_c}{\Delta t}
=
\frac{u}{S_S\Delta t}W_S
+
q_b\,u\left(\frac{1}{S_S}+\frac{1}{C\Delta t}\right).
\]

Because the definition of \(u\) implies

\[
u\left(\frac{1}{S_S}+\frac{1}{C\Delta t}\right)=1,
\]

the predictor flux cancels exactly and

\[
\boxed{q_u=\frac{u}{S_S}\frac{W_S}{\Delta t}
=\beta\frac{W_S}{\Delta t}}.
\]

So in this transparent linear oracle \(q_u\) is the condensed non-bottom forcing contribution passed to the groundwater equation. It is independent of which predictor \(q_b\) was used to estimate the response.

For NH01,

\[
q_u=(2/3)\,0.010/1=0.0066666667\;m/day.
\]

The affine groundwater-directed response represented with production sign is

\[
q_u^{aff}(H_c)
=
q_{u,*}+\frac{u}{\Delta t}(H_c-H_*).
\]

This has slope \(+u/\Delta t\), while the physical outward bottom/interface corrector flux has slope \(-u/\Delta t\). They are different response objects, exactly as the MAP evidence indicated.

## 5. Exact groundwater equation in production-style affine form

The exact groundwater balance can be written

\[
S_M\frac{H_c-H_{c0}}{\Delta t}
=
\frac{W_M}{\Delta t}
+
\beta\frac{W_S}{\Delta t}
+
\frac{u}{\Delta t}(z_{p0}-H_c).
\]

Since \(u=\beta S_S\), the SWAP contribution is affine in \(H_c\). Therefore the dummy admits an exact HCOF/RHS-style condensation, not merely a first-order approximation.

This is the correct place to compare signs and unit conversions with the MODFLOW backend. The comparison is numerical/algebraic; it does not redefine the physical interface.

## 6. New prospective claims

NH01 supports the following hypotheses for later numerical testing:

1. Production-style \(u\) can emerge exactly from fixed-interface physics without being a q-link conductance or a phreatic-state identity.
2. Window dependence of \(u\) is physically expected when internal top-system hydraulic equilibration is finite.
3. The \(+u/\Delta t\) production affine slope and the \(-u/\Delta t\) accepted interface-flux derivative can coexist without contradiction because they belong to different algebraic response objects.
4. In the hydrostatic/fast-equilibration limit \(u\to S_S\), explaining why a simple test can make \(u\) look like a storage coefficient.
5. A successful numerical implementation should recover the exact NH01 root independently of predictor \(q_b\), provided the affine response is constructed consistently.

These are now mathematical predictions. They are not yet postimage numerical qualification.
