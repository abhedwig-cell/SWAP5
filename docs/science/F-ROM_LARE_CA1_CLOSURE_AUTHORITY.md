# F-ROM-LARE CA1 closure authority

## Decision

**LARE_CLOSURE_AUTHORITY_COMPLETE_WITH_DECLARED_INTERPRETATION**

This authority is sufficient for a clean-sheet research implementation of the **fixed-layer interior LARE closure** and externally prescribed flux boundaries.

It is not yet sufficient for a general unsaturated prescribed-head bottom boundary or moving-water-table geometry.

No production ROM is authorized.

## Primary authority

The binding source chain is:

1. He, J., Kalin, L., Hantush, M. M. & Isik, S. (2026), *A Numerical Model for Integrated Form of Richards Equation*, Hydrological Processes 40(1), DOI 10.1002/hyp.70396.
2. He, J. (2021), *Modeling Soil Moisture Dynamics in Wetlands*, Auburn University dissertation, Chapter 4: *A Numerical Model for Multiple Layer-Averaged Richards Equation*.
3. He, J., Hantush, M. M., Kalin, L., Rezaeianzadeh, M. & Isik, S. (2021), *A two-layer numerical model of soil moisture dynamics: Model development*, Journal of Hydrology 602, 126797, DOI 10.1016/j.jhydrol.2021.126797.
4. He, J., Hantush, M. M., Kalin, L. & Isik, S. (2022), *Two-Layer numerical model of soil moisture dynamics: Model assessment and Bayesian uncertainty estimation*, Journal of Hydrology 613, 128327, DOI 10.1016/j.jhydrol.2022.128327.

The 2021 paper supplies the complete Taylor derivation of the two-layer interface operator. The dissertation explicitly states that the multi-layer LARE evaluates interfacial matric gradient and conductivity directly from each pair of adjacent layer-integrated states, their capillary pressures, conductivities and thicknesses using the same first-order Taylor principle. The 2026 paper is the current publication authority for the multi-layer method.

The literal indexed text available for the dissertation does not expose the final generic (i,i+1) equation. The multi-layer formula below is therefore marked as a **declared interpretation**, not quoted as a verbatim 2026 equation.

## Coordinate and sign convention

The source convention is:

- (z) positive downward;
- (psi) is capillary pressure head, i.e. the negative of conventional negative unsaturated pressure head;
- water flux (q) is positive downward.

Darcy-Buckingham flux is

[
q = Kleft(rac{partial psi}{partial z}+1ight).
]

This is the convention of He et al. (2021), Eq. (3).

A SWAP implementation must use an explicit sign adapter rather than silently mixing the source convention with SWAP native flux signs.

## State and constitutive averaging

For fixed layer (i) of thickness (L_i),

[
ar	heta_i = rac{1}{L_i}int_{z_{i-1}}^{z_i}	heta(z),dz,
qquad
W_i=L_iar	heta_i.
]

The published approximation uses

[
arpsi_i approx psi(ar	heta_i),
qquad
ar K_i approx K(ar	heta_i).
]

He et al. (2022) explicitly identifies these approximations, together with truncation of higher-order Taylor terms at interfaces, as structural assumptions of the method.

These are therefore part of the LARE closure under test, not implementation conveniences that may be tuned away.

## Fixed-layer integrated continuity

For fixed geometry and distributed layer-average sink (ar S_i),

[
L_irac{dar	heta_i}{dt}
=
q_{i-1/2}-q_{i+1/2}-L_iar S_i.
]

Equivalently,

[
rac{dW_i}{dt}
=
q_{i-1/2}-q_{i+1/2}-L_iar S_i.
]

Summing over all layers cancels every internal interface flux exactly:

[
rac{d}{dt}sum_i W_i
=
q_{mathrm{top}}-q_{mathrm{bottom}}
-sum_i L_iar S_i.
]

This telescoping identity is the structural mass-conservation requirement for the clean-sheet RD1 implementation.

## Two-layer Taylor authority

For two adjacent layers with thicknesses (L_1) and (L_2), He et al. (2021) expands (psi(z)) about the interface and integrates the first-order approximation over both layers.

The paper obtains

[
left.rac{partialpsi}{partial z}ight|_I
=
rac{2(arpsi_2-arpsi_1)}
{L_1+L_2}.
]

The interface capillary head itself is

[
psi_I
=
rac{L_2}{L_1+L_2}arpsi_1+
rac{L_1}{L_1+L_2}arpsi_2.
]

The same derivation applied to conductivity gives

[
K_I
=
rac{L_2}{L_1+L_2}ar K_1+
rac{L_1}{L_1+L_2}ar K_2.
]

Therefore

[
q_I
=
K_I
left[
rac{2(arpsi_2-arpsi_1)}
{L_1+L_2}
+1
ight].
]

These correspond to He et al. (2021), Eqs. (17), (18), (23) and (24).

The conductivity average is thickness weighted with the **opposite layer thickness** because it is the first-order interface value reconstructed from two layer averages. It is not an arbitrary arithmetic or harmonic conductivity average.

## Declared multi-layer interpretation

The dissertation states that multi-layer LARE computes interfacial matric gradient and conductivity directly from adjacent layers/control volumes using their layer-integrated capillary pressure, unsaturated conductivity and thickness through first-order Taylor expansion.

The unique local adjacent-layer extension of the published two-layer Taylor operator used in CA1 is therefore:

[
G_{i+1/2}
=
rac{2(arpsi_{i+1}-arpsi_i)}
{L_i+L_{i+1}},
]

[
K_{i+1/2}
=
rac{L_{i+1}ar K_i+L_iar K_{i+1}}
{L_i+L_{i+1}},
]

[
q_{i+1/2}
=
K_{i+1/2}(G_{i+1/2}+1).
]

This extension is not presented as a verbatim recovered 2026 equation. It is a declared interpretation constrained by:

- the exact 2021 Taylor derivation;
- the dissertation statement that the multi-layer method applies the interface calculation directly to adjacent layers using their (psi), (K) and thicknesses;
- recovery of the exact two-layer expression when (N=2);
- local dependence only on adjacent layers, as described by the dissertation.

RD1 must test this interpretation independently. A failure may be classified as either closure failure or authority-interpretation failure until direct 2026 source/code corroboration becomes available.

## Material interfaces

He et al. (2022) tested two-layer profiles with contrasting hydraulic properties and reports that the interface flux is conserved through the derived interfacial matric-potential and conductivity expressions.

For a heterogeneous pair, CA1 therefore evaluates

[
arpsi_i=psi_i(ar	heta_i),
qquad
ar K_i=K_i(ar	heta_i)
]

with the constitutive law belonging to each layer before applying the adjacent-layer Taylor operator.

No averaging of van Genuchten parameter vectors across a material boundary is authorized.

B01 RD1 is homogeneous, so heterogeneous-interface qualification remains a later transfer test.

## Authorized boundary semantics

### Prescribed top flux

A prescribed flux may enter the layer water balance directly as (q_{mathrm{top}}). No additional LARE closure is needed for that imposed boundary quantity.

### Prescribed bottom flux

Likewise, an externally prescribed bottom flux may enter directly as (q_{mathrm{bottom}}).

This is sufficient for the fixed-flux Stage-A histories G01 and G02.

### Free drainage

He et al. (2021), Eq. (32), gives first-order free drainage as

[
q_{mathrm{bottom}}=ar K_Napprox K_N(ar	heta_N).
]

This boundary is authorized for CA1/RD1.

### Water table at the lower boundary

For a saturated water-table boundary He et al. (2021) uses the Taylor approximation at the bottom together with saturated conductivity. This is a specific water-table boundary and is not silently generalized here to arbitrary unsaturated prescribed head.

### General unsaturated prescribed bottom head

**NOT YET AUTHORIZED.**

The accessible sources state that pressure-controlled bottom conditions are supported, but CA1 has not recovered an unambiguous generic multi-layer formula matching the current SWAP mode-5 arbitrary prescribed negative pressure-head laboratory.

Therefore G00, G03, G04 and the head-controlled parts of G05 remain outside the first RD1 execution slice.

A separate `LARE-BC1` authority extraction is required before those histories are used for LARE propagation claims.

### Moving water-table geometry

**NOT YET AUTHORIZED FOR RD1.**

The two-layer publication contains the Leibniz moving-boundary term, but the first clean-sheet multi-layer experiment deliberately keeps layer geometry fixed. Dynamic water-table geometry requires a later explicit authority slice.

## Time integration

The published two-layer method solves the coupled layer-average ODEs using explicit Heun predictor-corrector integration with iterative correction.

The 2026 multi-layer LARE paper and the dissertation describe the same broad coupled-ODE / Heun approach.

CA1 binds the **closure equations** independently of the time integrator. RD1-A and RD1-B therefore test static and one-step closure quantities before long-history time integration.

When RD1-C begins, published Heun semantics are the default LARE integrator. Temporal refinement must be reported separately so closure error is not conflated with time-integration error.

No adaptive or implicit correction may be introduced under the name LARE without separate preregistration.

## Limiting identities

The clean-sheet closure must satisfy these before hydrological comparison.

### Identical adjacent state

If two homogeneous adjacent layers have

[
arpsi_{i+1}=arpsi_i,
qquad
ar K_{i+1}=ar K_i=K,
]

then

[
q_{i+1/2}=K.
]

This is the unit-gradient/gravity drainage identity in the source convention.

### Hydrostatic zero flux

For

[
arpsi_{i+1}-arpsi_i
=
-rac{L_i+L_{i+1}}{2},
]

the reconstructed gradient is (-1), hence

[
q_{i+1/2}=0.
]

### Equal layer thickness

If (L_i=L_{i+1}),

[
K_{i+1/2}=rac{ar K_i+ar K_{i+1}}{2}.
]

### Global conservation

For a closed fixed-layer column with zero sinks and zero external fluxes,

[
rac{d}{dt}sum_i W_i=0
]

independently of the internal interface flux magnitudes.

## Authority limitations

CA1 does not prove that the closure is accurate for D3.

In particular, D3 contains a 140 cm upper layer. He et al. (2022) found accuracy degradation as layer thickness increased, and the 2021 paper explicitly noted reduced performance for deep/thick soil zones.

That limitation is central to RD1, not a reason to alter D3 before testing.

## CA1 disposition

`CLOSE_DECISION = LARE_CLOSURE_AUTHORITY_COMPLETE_WITH_DECLARED_INTERPRETATION`

Authorized immediately:

- fixed-layer storage state;
- homogeneous or explicitly layer-specific constitutive evaluation;
- adjacent-layer Taylor interface operator;
- prescribed top/bottom flux;
- free drainage;
- static identity tests;
- one-step closure audit;
- bounded D3/D4/D2 research implementation.

Held:

- arbitrary unsaturated prescribed-head bottom closure;
- moving-water-table layer geometry;
- Hupsel/application coupling;
- production solver integration.

`PRODUCTION_ROM_AUTHORIZED = FALSE`
