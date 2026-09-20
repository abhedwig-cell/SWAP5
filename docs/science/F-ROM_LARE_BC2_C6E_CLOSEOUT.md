# F-ROM-LARE BC2-C6E prescribed-flux boundary qualification closeout

## Decision

**BEMR prescribed-flux boundary extension is not qualified. Free-running BEMR is not authorized.**

C6E is entirely response-free. It does not execute a reduced hydrological trajectory and does not change Reference Richards, RossFast or production groundwater coupling.

## Frozen test

C6E used the already-qualified D12_B2P5 BEMR representation with integrated storage and centered first water-content moment in all 12 retained layers.

The state domain remained the unchanged D12 subset of the C5Z/C6C synthetic B14 domain: seven mean-saturation profiles and six moment patterns. Three equal top/bottom positive-downward HOLD fluxes were fixed prospectively from the frozen B14 conductivity at effective saturations 0.60, 0.75 and 0.90. No C6D response, residual or observed flux was used to choose those values.

That gives 126 state/boundary cases and five frozen starts per case, or 630 solves.

## Result

The authoritative exact-sharded run is GitHub Actions run `35525617524` at execution head `3a72c980...`.

The following gates pass for the complete domain:

- strict state/moment realizability: 126/126;
- reported nonlinear convergence: 126/126;
- bounded effective saturation: 126/126;
- no-response firewall: pass.

The complete prescribed-flux family nevertheless fails the preregistered mathematical contract:

- unique numerical branch: 121/126;
- hydraulic continuity and external boundary residuals: 121/126;
- independent storage/moment recovery: 121/126;
- 96/192-point quadrature consistency: 125/126.

The largest observed top-flux residual is about 0.306 cm/d. Finite Jacobian condition numbers have median approximately 3895 and maximum approximately (1.48\times10^{11}); two solves have non-finite condition estimates.

## Nature of the failure

This is not a simple proof that no solution exists.

In each of the five failed state/boundary cases, at least some of the frozen starts find a near-exact, physically admissible common solution. One or two other preregistered starts instead converge to a near-upper-bound attractor with (S_e\) approaching 0.995 and large boundary and/or state residuals.

The five failing cases are:

1. `UNIFORM_060 | BOTTOM_HEAVY_ALL | HOLD_Q_SE090`;
2. `UNIFORM_060 | ALTERNATING | HOLD_Q_SE090`;
3. `TOP_DRY_BOTTOM_WET | BOTTOM_HEAVY_ALL | HOLD_Q_SE075`;
4. `TOP_DRY_BOTTOM_WET | BOTTOM_HEAVY_ALL | HOLD_Q_SE090`;
5. `TOP_DRY_BOTTOM_WET | ALTERNATING | HOLD_Q_SE090`.

Therefore BEMR under prescribed flux lacks the prospectively required branch robustness. A free-running implementation would need an additional branch-selection, continuation, stability or regularization principle.

No such principle belongs to the frozen BEMR authority.

## Relation to C6D

C6D is not retracted.

On immutable prescribed-head moving states, directly projected storage and first moment plus BEMR improved the preregistered primary interface-flux vector relative to CURRENT_LAYER_FACE. C6D also preserved an important phase-reversal tail risk.

C6E establishes a different boundary: the same algebraic family is not robust enough under the prospectively tested prescribed-flux/HOLD extension to authorize a general free-running model.

This means the evidence now separates three statements:

- the centered first moment is a meaningful conservation-derived state;
- the bounded entropy-dual map is mathematically admissible and can improve prescribed-head frozen-state propagation;
- the complete BEMR algebraic boundary problem is not yet a robust general dynamic closure.

## No post-result repair

C6E does not authorize selecting only the starts that found the good branch, changing starts, adding coefficient regularization, using continuation, relaxing the saturation interval, changing the dual polynomial order, narrowing the moment domain, changing the HOLD flux anchors or loosening residual gates.

Any future branch-selection principle must be independently derived from physical or mathematical authority before it sees these C6E outcomes. It cannot be introduced as a repair fitted to the five failures.

## Next boundary

No fresh blind BEMR free-running test is authorized.

The workstream returns to a scientific choice boundary. Future read-only work may examine a genuinely conserved interface-local state, an independently justified adaptive/moving partition, or a new realizability-preserving moment closure. A BEMR branch-selection extension is admissible for theory review only if it is derived independently from a physical variational or stability principle.

No application acceptance, performance, speed or production-ROM conclusion follows from C6E.
