# F-ROM-LARE representation-selection closeout

## Current decision

**STOP_C6A_INTERFACE_VARIABLE_ROUTE_AT_STRUCTURAL_EQUIVALENCE_BOUNDARY**

Current repository authority is the machine-readable
`integration/f-rom/LARE_REPRESENTATION_SELECTION_CLOSEOUT.json`.
This page is the human-readable synthesis through C6A.

No production ROM is selected. Fine Reference Richards remains the scientific reference. No Reference Richards, RossFast or production groundwater-coupling change follows from this workstream.

## What is now established

The representation campaign has separated three issues that were initially entangled.

First, vertical placement matters. C5P showed a causal benefit from moving retained support toward the lower boundary at fixed dimension.

Second, simply adding more ordinary layer states is no longer the active axis once the lower support is held fixed. C5R restored four vertically distributed states above the same B2P5 lower support and obtained essentially the same groundwater response for D8 and D12. The remaining high-resolution discrepancy is therefore much more strongly associated with inter-layer propagation than with missing ordinary state breadth.

Third, the propagation problem has not yet yielded a qualified replacement closure. Several prospectively defined routes have failed before free-running adoption:

- C5T: the zero-parameter DSE2P steady-equivalent interface closure failed its mandatory response-free numerical qualification.
- C5W: the P0 uniform-storage-tendency SCAFP route failed the frozen existence/admissibility contract.
- C5Z: the conservation-derived first-moment state remained numerically well behaved, but its all-layer cubic-theta reconstruction violated the frozen upper constitutive admissibility domain in 14 of 168 cases.
- C6A: explicit algebraic interface head and flux unknowns were shown not to constitute a new physical family by themselves.

## C6A structural-equivalence result

C6A tested the theory behind a structure-preserving coarse Richards formulation with one dynamic integrated storage state per layer and explicit algebraic hydraulic traces and fluxes at the interfaces.

A single shared face flux is sufficient for exact layer-by-layer conservation. The algebraic degree count can also be made square.

The important result is that the count closes only after a local center-to-face hydraulic law has been chosen. The interface variables themselves contain no new transient subgrid information.

For the natural lowest-order choices:

1. linear or frozen-(K) half-cell Darcy relations statically condense to a conventional conservative two-point resistance operator;
2. exact nonlinear steady half-cell relations condense to the DSE2P steady-equivalent closure already closed by C5T;
3. affine within-layer flux implies uniform storage tendency and is therefore the P0 route already closed by C5W.

Allowing a non-affine internal flux reintroduces the unresolved within-layer storage-tendency distribution. That requires either an additional physically justified state or a new subgrid closure principle.

Thus mixed/hybrid variable placement is a useful numerical architecture, but it is not by itself the missing Layer-ROM physics.

## Relation to CoRichards

Same-partition CoRichards remains a numerical comparator-availability result. R3 through R12 did not provide a qualified non-equilibrium dynamic common cohort under the frozen strict authority, whereas the fine R16 control recovered viability.

C6A does not overturn that result. Rewriting coarse Richards in mixed or mixed-hybrid form changes the algebraic formulation and conservation representation, not automatically the reduced physical information content.

## Status of the first moment

C5Z does **not** establish that the centered first water-content moment is a bad physical state.

C5Y's exact projected balance remains valid. What failed was the chosen all-layer cubic-(	heta) hydraulic reconstruction over the frozen synthetic domain. The moment range, polynomial order, constitutive admissibility limits, numerical starts and tolerances were not retuned after exposure.

The first moment may therefore appear in a future physically distinct family only if the new construction is derived independently and does not reopen the rejected C5Z cubic-theta route under modified tuning.

## Current scientific choice boundary

BEMR was mathematically qualified through C6C and supported as a prescribed-head frozen-state mechanism in C6D, but its prescribed-flux extension failed C6E branch-robustness qualification. General free-running BEMR is therefore stopped.

A future read-only derivation may consider, without using exposed response residuals to choose among them:

- a realizability-preserving conservation-derived moment/state closure that is genuinely distinct from the C5Z cubic-theta reconstruction;
- a conserved interface-local or dual-control-volume state with its own balance law, provided it is shown not to be ordinary layer refinement in disguise;
- an independently justified adaptive or moving-partition representation.

A dynamic interface flux cannot simply be declared as a new state. Richards-Darcy supplies no independent flux-inertia evolution equation, so such a route would need separate physical authority.

## C6C BEMR mathematical qualification

C6C qualifies the bounded entropy-moment state-to-profile map mathematically on the complete unchanged 168-case C5Z synthetic B14 domain. All five frozen starts pass for every case, and strict moment realizability, bounded saturation, hydraulic continuity, state recovery and quadrature consistency all close.

This removes the specific C5Z profile-admissibility blocker without reopening the failed cubic-theta route. It does not yet establish hydrological fidelity. The next authorized unit is C6D, an offline frozen-state interface-flux discriminator using directly projected Reference storage and first moments.

## C6D BEMR frozen-state mechanism result

C6D evaluates BEMR offline on 2,304 immutable C5R moving states with storage and centered first moment projected directly from the fine Reference profile. All states pass the frozen C6C numerical and realizability contract.

The prospectively frozen primary mechanism vector improves: pooled RMSE falls from 0.008709 to 0.006075 cm/day, mean-absolute interface/history signed bias from 0.001138 to 0.000190 cm/day, and sign mismatches from 229 to 190. RMSE also improves separately at 150, 155 and 157.5 cm.

The mechanism improvement is not uniform. Maximum absolute error worsens to 0.1842 cm/day at the first R02 observation after a RISE-to-FALL reversal, and 155-cm sign mismatches increase slightly. These exposed tail risks are retained and create a mandatory transition-tail guard for any later fresh blind free-running test.

C6D therefore authorizes only response-free C6E prescribed-flux boundary qualification.

## C6D and C6E BEMR boundary

C6D provided positive but exposed mechanism evidence for BEMR under prescribed-head moving states. On directly projected D12_B2P5 storage and first moments, the preregistered lower-interface flux vector improved relative to CURRENT_LAYER_FACE, while a phase-reversal maximum-error tail risk remained.

C6E then tested the missing prescribed-flux/HOLD boundary entirely response-free. The result is negative. All 126 frozen state/moment targets are realizable and all 630 starts report solver convergence, but five cases fail the required common-branch physical contract. Some starts find a near-exact solution while other frozen starts converge to near-upper-bound residual attractors.

Therefore C6D is not retracted, but general free-running BEMR is not authorized. Choosing only successful starts, adding regularization/continuation or relaxing the frozen domain after C6E would be post-result retuning.

The workstream is again at a scientific choice boundary before any new propagation or state family.

## C6F conservative sublayer-memory result

C6F tested the next apparently natural idea without hydrological response: represent each macro-layer by conserved upper- and lower-half water inventories.

That state has attractive properties. Each inventory is directly bounded, and exact sub-control-volume balances exist. However, with ordinary Darcy fluxes between half-cell representative states, the construction is algebraically identical to splitting every macro-layer into two ordinary finite-volume cells. It is therefore fixed grid refinement, not a new reduced propagation family.

Making the internal midpoint transfer different from ordinary Darcy does not follow from conservation alone and would introduce a new closure. Exact steady transfer returns to the already-closed steady-equivalent class.

C6F therefore closes without a D24 or free-running experiment. The next representation must change information content or state geometry rather than relabel ordinary refinement.

## C6G-C6J structural closeout

C6G shows that a finite interface-local conserved water state under unchanged Richards physics is either an ordinary positive-measure control volume, an overlapping moment with unresolved flux information, or new singular interface physics.

C6H shows that moving partitions can preserve mass exactly but that mesh velocity is a numerical coordinate choice not selected by Richards. Generic moving geometry therefore does not supply an independently physical low-dimensional memory state.

C6I identifies a genuine Richards energy-dissipation structure and a parameter-free S/M variational reduction (FEMO). C6J then prospectively tests its interior affine-suction realization without hydrological response.

All 126 frozen moment targets are realizable, but the frozen numerical realization does not qualify broadly: only 38 state cases pass all-start convergence/interiority/local-Jacobian gates and only four pass the frozen local uniqueness requirement and reach a qualified Onsager metric.

The Richards energy-dissipation theory is retained; the current FEMO numerical route is not. No free-running FEMO is authorized.

The workstream is therefore again at a scientific choice boundary: either define a genuinely new, independently motivated convex/obstacle moment realization before response, or stop searching for a universal low-dimensional replacement and evaluate purpose-dependent sufficiency of the already-qualified representation frontier.

## C6K-C6L purpose-dependent program

After C6J, the program no longer treats a universal very-low-dimensional Richards replacement as the default objective.

C6K synthesizes the existing evidence as purpose-, material-, lower-boundary-, horizon- and placement-dependent. Groundwater-output and profile/state requirements are already demonstrably different, while ET/root uptake, long-horizon balance and scientific extremes remain direct evidence gaps rather than negative results.

C6L binds the next validation order. A fresh B01/B14 free-drainage surface-flux Reference must first pass a high-resolution space-time qualification gate. Only after that may the already-existing R3-R16 ladder and P4/U4/U8 placement controls be compared on surface-driven soil-moisture/profile/drainage views.

ET/root uptake remains a distinct later claim. Replaying a prescribed distributed sink can test hydraulic response to known extraction, but cannot establish that a reduced model predicts stress-dependent uptake or evapotranspiration.

No new closure, partition or application threshold is authorized by C6K-C6L.

## Application and value boundary

Comparator crossing is not application acceptance. C4U remains the purpose-dependent groundwater application-acceptance authority and its external fidelity requirements are still unresolved.

No performance comparison, portable speedup, computational-value claim or production-ROM admission is authorized at this boundary.
