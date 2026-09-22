# ROM-PURPOSE P0 read-only synthesis and purpose/state-support matrix

## Scope

ROM-PURPOSE asks which vertical information must be retained for a declared hydrological purpose. It does not search for one universal minimum layer count and does not alter production physics or an admitted solver.

The current canonical authority is `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`. Historical Layer-ROM and LARE branches are evidence only and are not merged into this line.

## Evidence synthesis

The historical Layer-ROM closeout separates minimum state information from minimum useful propagated dimension. In its bounded B01 library, L3 separates retained states, but L3 is not broadly adequate under the tested propagated closures. L4, L6 and R8 form a practical research frontier, with lower-zone localization repeatedly more useful than a single global first moment.

The later LARE work strengthens the placement conclusion. Dynamic groundwater experiments show that lower-boundary response can be sensitive to local lower-zone resolution and that equal state count does not make a uniform partition equivalent to a lower-zone-focused one. C6N2 shows the complementary surface result: under surface forcing, U8 strongly improves over lower-zone-focused R8, and a top-aware four-state partition can improve relevant upper-zone views.

Closure evidence must remain separate. C6D showed that an added conservation-derived first moment can improve a frozen-state interface-flux mechanism. C6E then failed the prescribed-flux branch-robustness contract and C6J failed broad numerical realization of FEMO. These outcomes do not imply that more layers are always required. They show that, once placement is adequate, propagation/reconstruction can itself remain the limiting mechanism.

C6P is not used to select P1 representations. It only protects the boundary that root uptake is a separate feedback problem.

## Purpose versus state-support matrix

| Purpose | Primary response components | Prospectively required vertical information | First placement test | Closure question | Application authority |
| --- | --- | --- | --- | --- | --- |
| GW-LB: lower-boundary / groundwater exchange | cumulative bottom exchange, interval flux, sign, reversal timing, storage memory, signed bias | explicit support adjacent to the lower boundary plus progressively coarser interior storage | G4 versus U4 at equal dimension | if G4 placement is supported but Layer-ROM remains weak while same-partition coarse Richards does not, classify a closure/propagation deficit | not bound |
| SURF-P: surface / soil-moisture profile | 0-20 cm storage, 0-40 cm storage, 0-80 cm storage, mapped 10-cm moisture profile, event/extremum timing | explicit support coincident with the declared 0-20, 0-40 and 0-80 cm purpose regions | S4 versus U4 at equal dimension | if S4 placement is supported but same-partition coarse Richards is materially stronger, classify a closure/propagation deficit | not bound |
| ROOT feedback | stress-relevant pressure/state distribution and uptake response | unresolved in this workstream; C6P shows storage plus one global geometric moment is not exact | excluded from P1 | separate ROM-ROOT authority required | not bound |
| PROFILE research | detailed vertical state and internal fluxes | substantially denser local support expected; no minimum claimed here | diagnostic only | may erase useful reduction | not bound |

## P1 equal-dimension discriminator

P1 freezes three four-state partitions before any new response:

- `S4 = [0, 20, 40, 80, 160] cm`
- `G4 = [0, 80, 120, 140, 160] cm`
- `U4 = [0, 40, 80, 120, 160] cm`

S4 is derived directly from the declared surface purpose supports. G4 is the vertical mirror of that hierarchy, so the discriminator changes location while holding dimension and support-scale hierarchy fixed. U4 is the uniform equal-dimension control.

No boundary was chosen from a minimum in a historical candidate-error curve.

## Interpretation logic

Placement support is componentwise. There is no weighted score and no overall RMSE verdict.

For SURF-P, S4 is compared with U4 and G4 on surface storage, upper-zone storage, mapped profile and timing diagnostics. For GW-LB, G4 is compared with U4 and S4 on cumulative and instantaneous lower-boundary exchange, sign/reversal behaviour, storage and drift.

A purpose-aligned partition being better than U4 is evidence about placement only. It does not prove application sufficiency.

A poor Layer-ROM result after purpose-aligned placement is not automatically evidence for more states. P1 therefore preregisters same-partition coarse Richards as a diagnostic comparator. If same-partition coarse Richards preserves the purpose response while Layer-ROM does not, the deficit is assigned to propagation/closure rather than to placement or scalar dimension.

If both Layer-ROM and same-partition coarse Richards fail the same purpose view, P1 cannot identify closure as the sole deficit. The outcome remains compatible with insufficient four-state information, insufficient numerical spatial support, or both.

## P1 decision target

The desired output is not a best representation. P1 will populate, separately for GW-LB and SURF-P:

`PURPOSE -> REQUIRED VERTICAL INFORMATION -> MINIMUM TESTED PLACEMENT -> CLOSURE CLASS -> REMAINING FIDELITY LIMIT -> APPLICATION AUTHORITY STATUS`.

No production-ROM or performance conclusion is authorized.
