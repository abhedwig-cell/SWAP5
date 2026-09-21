# Fixed-interface SWAP-MODFLOW coupling theory

Date: 2026-09-21  
Status: RESEARCH THEORY, NO PRODUCTION CHANGE  
Scope: physical and mathematical formulation before numerical implementation

## 1. Research proposition

The intended coupling is defined around a fixed geometric coupling plane at elevation (z_c), located at the lower boundary of the SWAP profile.

MODFLOW supplies the hydraulic head (H_c) at that plane. SWAP uses the same (H_c) as its lower hydraulic boundary condition and resolves the state and fluxes of the top system above the plane.

The MODFLOW coupling state is therefore **not defined as the phreatic groundwater elevation**. The phreatic elevation (z_p) is a state derived inside the top-system solution. In a hydrostatic limiting case (H_c=z_p) can occur, but that equality is a consequence of the hydraulic state, not the definition of the coupled variable. Under vertical gradients, (H_c) and (z_p) generally differ.

This fixed-interface proposition is the primary hypothesis to be derived and tested. Shared-phreatic h-link and finite-resistance two-head q-link formulations remain comparison/limit cases, not competing default architectures.

## 2. Four separate proof layers

The research must not infer physical or mathematical correctness from solver success.

1. **Physical/conceptual correctness**: control volumes, state variables, storage inventories, external fluxes and the geometric interface represent the intended hydrological system without overlap or omission.
2. **Mathematical correctness**: the coupled equations and sign conventions conserve mass and express continuity at the interface.
3. **Numerical correctness**: the implemented response condensation, affine linearization, iteration and timestep algorithm solve the stated mathematical problem.
4. **Numerical quality**: convergence rate, robustness, timestep sensitivity and tolerances are adequate for production use.

Evidence at a later layer cannot repair an error at an earlier layer.

## 3. Physical control volumes

Let (Omega_S) be the SWAP top-system control volume above (z_c), and (Omega_M) the MODFLOW groundwater control volume below/adjacent to the same geometric interface. Their accepted physical inventories are (V_S) and (V_M).

The intended base contract is disjoint physical ownership:

[
Omega_S cap Omega_M = arnothing
]

apart from their common boundary (Gamma_c).

This statement concerns physical mass accounting, not whether either numerical model carries auxiliary state that extends beyond the strict physical accounting volume.

Let (q_c) be positive downward/outward from SWAP through (Gamma_c). The same transfer enters MODFLOW with the opposite component sign. It is internal to the complete coupled system.

## 4. Interface conditions

The two fundamental interface conditions are:

### 4.1 Hydraulic-head continuity

[
H_c^S = H_c^M = H_c.
]

This is continuity of hydraulic head at one geometric plane. It is not equality between MODFLOW head and SWAP phreatic elevation.

### 4.2 Flux continuity

With (q_c>0) defined from SWAP to MODFLOW,

[
q_{c,S}^{out}=q_c,
qquad
q_{c,M}^{in}=q_c.
]

Equivalently, with outward-normal fluxes for both component domains,

[
q_{c,S}^{out}+q_{c,M}^{out}=0.
]

No finite-resistance law (q=C(H_1-H_2)) is required at this interface because the base contract does not introduce two distinct heads separated by an artificial resistance.

## 5. Component and complete balances

For one coupling window ([t_n,t_{n+1}]), define integrated external volumes (W_S^{ext}) and (W_M^{ext}), positive into their respective control volumes, and interface transfer

[
E_c=int_{t_n}^{t_{n+1}} q_c A_c,dt
]

positive from SWAP to MODFLOW.

Then

[
Delta V_S = W_S^{ext} - E_c
]

and

[
Delta V_M = W_M^{ext} + E_c.
]

Adding both equations eliminates the internal interface transfer:

[
Delta V_S+Delta V_M
=
W_S^{ext}+W_M^{ext}.
]

This complete-system balance is the primary mass oracle. Any implementation that converges while violating this declared physical balance is scientifically wrong.

## 6. SWAP response operator

For a committed SWAP state (mathbf{x}_S^n), forcing history (mathbf{f}_S), coupling-window duration (Delta t), and imposed interface-head trajectory or its chosen finite-window representation, define the exact top-system response abstractly as

[
mathcal{S}:
(H_c,mathbf{x}_S^n,mathbf{f}_S,Delta t)
mapsto
(E_c,mathbf{x}_S^{n+1},Delta V_S,mathbf{y}_S).
]

Here (mathbf{y}_S) may include phreatic elevation, ET, drainage and diagnostic process quantities.

This operator is the physical/mathematical object that a reduced coupling response must represent. The phreatic elevation is an output/state of (mathcal{S}), not the definition of (H_c).

## 7. Coupled scalar residual in the one-cell reduction

If the MODFLOW side can be written over the same window as an inventory/external-flow relation dependent on the trial interface head,

[
Delta V_M(H_c)-W_M^{ext}(H_c)-E_c(H_c)=0,
]

then define

[
F(H_c)
=
Delta V_M(H_c)-W_M^{ext}(H_c)-E_c(H_c).
]

The coupled solution satisfies

[
F(H_c)=0.
]

The exact Jacobian is

[
F'(H_c)
=
rac{dDelta V_M}{dH_c}
-
rac{dW_M^{ext}}{dH_c}
-
rac{dE_c}{dH_c}.
]

The SWAP contribution (dE_c/dH_c) can contain storage, ET, drainage and internal-memory effects. It is therefore not, in general, identical to a physical storage coefficient or a physical interface conductance.

An equivalent residual can be derived from the complete-system balance. The chosen algebraic form must preserve the same accepted root and mass ledger.

## 8. Response condensation and current u/q_u

Only after the exact response and residual are defined may a local affine approximation be introduced:

[
R_S(H_c)
approx
R_* + J_*(H_c-H_*).
]

The existing production pair (u,q_u), and its conversion to MODFLOW HCOF/RHS, must be tested as a candidate numerical condensation of this response.

The direction of reasoning is mandatory:

[
	ext{physical domains}
ightarrow
	ext{exact balances}
ightarrow
	ext{coupled residual}
ightarrow
	ext{response derivative}
ightarrow
	ext{affine coefficients}.
]

It is not acceptable to infer the physical meaning of the interface from the dimensions or names of (u), (q_u), HCOF or RHS.

Current research evidence already shows that (u) is window dependent and that the production affine partial derivative is not generally the same object as the accepted corrector bottom-flux derivative. Those observations are compatible with response condensation and do not by themselves falsify the fixed-interface coupling.

## 9. Hydrostatic equality is a limiting observation, not state identity

A deliberately simple high-conductivity or hydrostatic profile can yield

[
H_c=z_p.
]

That experiment remains useful because it gives an elementary analytical oracle. Its interpretation must now be explicit: equality occurs because the vertical hydraulic gradient/resistance makes the interface head coincide numerically with the phreatic elevation.

The decisive next theoretical extension is a profile with nonzero vertical hydraulic gradient for which

[
H_c 
e z_p.
]

A correct coupling must then reproduce both quantities independently while preserving interface flux continuity and the complete mass balance.

This is a stronger test than another shared-phreatic experiment because it directly discriminates the intended state semantics.

## 10. Proof programme

Each increase in dummy-SWAP physics must pass the same chain:

[
	ext{CONCEPT}
ightarrow
	ext{MATHEMATICS}
ightarrow
	ext{INDEPENDENT ORACLE}
ightarrow
	ext{NUMERICAL IMPLEMENTATION}
ightarrow
	ext{QUALIFICATION}.
]

The planned progression is:

- hydrostatic linear control;
- finite vertical resistance above the fixed interface, explicitly separating (H_c) and (z_p);
- nonlinear/depth-dependent storage;
- unsaturated/capillary response;
- head/state-dependent ET;
- drainage;
- internal memory;
- lateral MODFLOW forcing;
- N:1 SWAP-column aggregation;
- transient forcing and coupling-window/timestep variation.

For each case the oracle should expose, where applicable,

[
H_c(t),quad z_p(t),quad q_c(t),quad V_S(t),quad V_M(t)
]

and the complete-system mass ledger.

## 11. Falsification criteria

The fixed-interface coupling hypothesis is falsified for a tested regime if, after separating implementation defects from the mathematical formulation, any of the following persists:

- no consistent control-volume balance can be written without duplicated or missing physical inventory;
- head continuity and flux continuity at the declared plane cannot simultaneously be satisfied;
- the numerical coupling converges to a different root than the independently derived coupled equations;
- accepted interface exchange does not cancel between the component ledgers;
- the complete-system mass balance fails beyond the preregistered numerical tolerance;
- a nonhydrostatic oracle requires treating MODFLOW head as phreatic elevation to obtain the correct answer.

A failure of iteration speed or solver robustness alone is a numerical-quality failure, not a falsification of the physical coupling equations.

## 12. Role of H-link and q-link research

The earlier HLINK and finite-resistance experiments remain useful evidence for distinguishing semantic objects and limiting cases. They are no longer on the main proof path.

In particular:

- shared-phreatic h-link literature is a comparison architecture;
- finite-resistance q-link is relevant only where two physical heads and a real resistance are deliberately introduced;
- neither is required to define the intended fixed-interface SWAP-MODFLOW contract.

## 13. Immediate next derivation

Before adding another live MODFLOW experiment, derive a minimal analytical nonhydrostatic top system with a fixed bottom interface head. It must have:

1. an explicit vertical resistance or constitutive relation above (z_c);
2. a separately calculable phreatic elevation (z_p);
3. an exact or semi-analytic interface flux (q_c);
4. explicit top-system storage;
5. a complete coupled mass balance with a simple MODFLOW storage element.

The preregistration must state the analytical solution and falsification criteria before implementation. That experiment will be the first direct test of the intended fixed-interface semantics rather than of an H-link alternative.
