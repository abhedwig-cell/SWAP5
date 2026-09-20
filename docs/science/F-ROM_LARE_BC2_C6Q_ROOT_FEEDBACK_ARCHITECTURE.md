# F-ROM-LARE BC2-C6Q minimal root-feedback validation architecture

## Decision

For the next purpose experiment, select the **minimum existing-state root-feedback approximation**:

[
ar\theta_i=S_i/d_i,
qquad
ar h_i=h(ar\theta_i),
]

[
Q_{mathrm{root},i}
=
T_p,Delta F_i,alpha(ar h_i).
]

This is selected for prospective falsification, not because C6P showed it to be exact.

## Why this candidate

It adds no root-specific dynamic state.

The root fraction (Delta F_i) is aggregated exactly over the retained layer. The representative pressure head comes directly from the existing retained water storage and the unchanged retention relation. The Feddes law itself is unchanged.

There are no fitted coefficients or C6P-derived corrections.

C6P already included this formula as a frozen diagnostic before seeing the ambiguity result. C6P then proved that it is not generally exact.

That is acceptable for the present research question: a reduced model may be useful without reproducing every fine-state functional exactly.

## Matching Reference semantics

The current SWAP5 root process evaluates uptake from the committed hydraulic pressure-head state.

The resulting fine root-sink vector is then prescribed during the Richards trial.

The reduced experiment must use the same sequencing:

1. evaluate root stress from the committed retained state;
2. construct a layer sink;
3. hold that sink fixed during the hydraulic trial;
4. commit or reject the hydraulic trial under the existing numerical authority.

Reference and reduced routes must see the same potential transpiration, root distribution and Feddes parameters.

## Reference before candidate

A root-active trajectory introduces a new feedback loop. It therefore needs its own high-resolution Reference authority.

The first mechanism panel will keep top and bottom hydraulic fluxes at their initial gravity-equilibrium values. Root extraction is then the only net drying driver.

The first Reference panel uses B01 and B14, an 80-cm root depth and frozen synthetic root-demand configurations. It is a mechanism test, not crop calibration.

The three-level C6N0/C6N1 space-time uncertainty framework is reused.

No reduced response may be generated until that Reference closes.

## Later candidate set

If the Reference qualifies, the reduced comparison should use only existing representations:

- U4;
- U8;
- R8;
- R16.

U4/U8 are retained because C6N2 showed their relevance to surface-driven state fidelity. R8 is the same-dimension lower-zone contrast. R16 remains the no-spatial-reduction LARE control.

No new partition or root-specific state is authorized.

## Claims

A successful experiment would provide comparator-relative evidence about the minimum existing-state Feddes approximation.

It would not by itself establish an agronomic, drought-monitoring or ET application tolerance, and it would not authorize a production ROM or performance claim.
