# F-ROM-LARE BC2 moving-water-table authority

## Status

**SOURCE DYNAMIC-WATER-TABLE GEOMETRY EXISTS; MOVING-DOMAIN CONSERVATION MUST BE RECONCILED BEFORE SWAP BRIDGING**

BC2 starts from the moving-water-table formulation in He et al. (2021) and its 2022 assessment. It does not start from SWAP groundwater coupling and it does not import a fitted moving-boundary law.

Primary source:

He, J., Hantush, M. M., Kalin, L., Rezaeianzadeh, M. & Isik, S. (2021).
*A two-layer numerical model of soil moisture dynamics: Model development*.
Journal of Hydrology 602, 126797.
DOI: 10.1016/j.jhydrol.2021.126797.

Supporting assessment:

He, J., Hantush, M. M., Kalin, L. & Isik, S. (2022).
*Two-Layer numerical model of soil moisture dynamics: Model assessment and Bayesian uncertainty estimation*.
Journal of Hydrology 613A, 128327.
DOI: 10.1016/j.jhydrol.2022.128327.

The U.S. EPA also publishes the model-generated input/output data associated with the 2021 article under DOI 10.23719/1524300. Those data are a preferred external reproduction oracle when their exact bytes are available. They are not required to establish the control-volume algebra below.

## Coordinates and source scenario

The source uses depth `z` positive downward and water flux positive downward.

The root-zone depth is `h`.

The water-table depth is `H(t)`.

For the published dynamic-water-table demonstration:

- `h = 10 cm`;
- initial/original water-table depth `H0 = 40 cm`;
- at `t=0` the profile is hypothetically saturated by an instantaneous water-table rise to the surface, `H=0`;
- the water table then declines according to

`H(t) = H0 * [1 - exp(-0.03 t)]`;

- the scenario is run for 100 days;
- the reported computational time step is 0.001 day;
- rainfall `i=0`;
- potential transpiration `Tp=0`;
- source materials are Carsel-Parrish sandy loam, loam and clay loam.

The regime transition `H=h` occurs at

`t_h = -ln(1-h/H0)/0.03`

which is approximately 9.5894 days.

The paper explicitly notes that the lower layer remains saturated until about 9.6 days and starts desaturating only after the water table falls below the fixed first-layer boundary.

## Source virtual-layer geometry

### Water table inside the first layer: 0 < H <= h

Only the interval `0..H(t)` is unsaturated.

Define

`theta_bar_1u = (1/H) * integral_0^H theta dz`.

The remainder `H..h` of the physical first layer is saturated.

The source reports the moving-boundary equation as

`H * d(theta_bar_1u)/dt - theta_1s * dH/dt = q0 - qH - H*S_u`

and the water-table flux closure

`qH = Ks1 * [1 + 2*(psi_b-thetaPsi(theta_bar_1u))/H]`

with `psi_b=0` at the water table.

### Water table below the first layer: H > h

The first unsaturated layer is fixed, `0..h`.

The second virtual unsaturated layer is `h..H(t)`.

Define

`theta_bar_2 = 1/(H-h) * integral_h^H theta dz`.

The 2021/2022 formulation reports the lower moving-layer equation in the form

`(H-h) * d(theta_bar_2)/dt - theta_2s * dH/dt = q1-qH`

for the no-sink lower layer.

The interface flux follows the same first-order layer-average closure used elsewhere in this work:

`q1 = Kint * [1 + 2*(psi_bar_2-psi_bar_1)/H]`

with

`Kint = ((H-h)*K_bar_1 + h*K_bar_2)/H`.

At the water table

`qH = Ks2 * [1 + 2*(0-psi_bar_2)/(H-h)]`.

## Conservation discrepancy requiring BC2-A adjudication

The moving-average definitions above imply an exact Leibniz control-volume identity.

For a generic moving interval `a..H(t)`, define

`U(t) = integral_a^H theta dz = [H(t)-a] * theta_bar(t)`.

The continuity equation gives

`dU/dt - theta(H,t)*dH/dt = q(a)-q(H)-integral_a^H S dz`.

At a water table `theta(H,t)=theta_s`.

Therefore the exact conservative product form is

`d/dt{[H-a]*theta_bar} - theta_s*dH/dt = q_in-q_out-Qsink`.

Expanding the product yields

`(H-a)*d(theta_bar)/dt + (theta_bar-theta_s)*dH/dt = q_in-q_out-Qsink`.

This is not algebraically identical to a literal reading of the printed average-state equations

`(H-a)*d(theta_bar)/dt - theta_s*dH/dt = ...`

because the expanded control-volume identity contains the additional `theta_bar*dH/dt` term.

BC2 must not silently choose one interpretation.

Possible explanations include:

- the printed equation is shorthand for a product derivative in the derivation;
- a term was dropped when converting from integrated storage to an average-state ODE;
- the source implementation follows a different form than the displayed equation;
- publication/typesetting or notation hides the intended derivative structure.

The earlier Rezaeianzadeh derivation explicitly writes a product derivative for a moving lower domain, strengthening the need to test rather than assume equivalence.

## BC2-A questions

BC2-A therefore asks, in order:

1. Does the exact Leibniz/product-storage form preserve the moving-control-volume ledger to numerical roundoff under manufactured fluxes and the published `H(t)`?
2. Does a literal implementation of the printed average-state form preserve the same ledger?
3. Are the two forms numerically distinguishable over the published dynamic-water-table trajectory?
4. If exact EPA author output becomes available, which form reproduces the published model-generated trajectory?
5. Is the regime transition at `H=h` continuous in storage and flux without clipping, hidden remapping water, or empirical correction?

No source form will be relabelled an error solely because it differs from an independently derived conservative form. The outcome may instead be `SOURCE_EQUATION_SEMANTICS_UNRESOLVED`.

## State choice for the conservation audit

BC2-A uses moving **storage** as the primary state:

- `U1 = H * theta_bar_1u` while `H<=h`;
- `W1 = h * theta_bar_1` and `U2 = (H-h)*theta_bar_2` while `H>h`.

This avoids representing a zero-thickness layer by an undefined average at `H=0`.

Average water content is a derived quantity only when the relevant thickness is positive.

At the switch `H=h`:

- the one-layer unsaturated storage becomes the fixed first-layer storage;
- the second-layer storage is initialized as zero;
- no artificial mass transfer is permitted.

## Separation from SWAP

BC2-A is source/theory reproduction only.

BC2-B may later prescribe the same external groundwater-head trajectory to Reference Richards and the reduced model, but must distinguish:

- the externally prescribed groundwater hydraulic-head coordinate;
- the zero-pressure crossing reconstructed from the actual transient Reference profile.

These are not assumed identical under non-hydrostatic flow.

BC2-C, if ever authorized, may address an actual bidirectionally coupled groundwater model.

## Firewalls

- no SWAP production physics change;
- no groundwater-coupler modification;
- no moving-grid fitting;
- no empirical `dH/dt` coefficient;
- no clipping at `H=0` or `H=h`;
- no hidden correction water;
- no application acceptance;
- no speed claim;
- no production ROM.
