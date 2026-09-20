# F-ROM-LARE BC2-C6N2 surface/profile representation closeout

## Decision

C6N2 finds **no numerically unresolved reduced surface/profile frontier** relative to the qualified C6N1 Reference uncertainty.

That is not an application-failure statement.

The scientifically stronger result is a placement result: the vertical distribution of retained states that works best for a groundwater/lower-boundary purpose does **not** transfer to a surface-driven soil-state purpose.

## Authority

Twenty frozen candidate combinations were executed successfully on B01/B14 using only the predeclared existing representations. The final classification reused those immutable candidate artifacts and the C6N1 R2048_T32 Reference.

Primary candidate run: `35537872450`.

Aggregation-only authority: `35538003359`.

Exact result SHA-256:

`4d83163fba56b1556ffa558b37be45a2626b86c24aef7182bd294e2c9e9bf944`.

All qualified candidates preserve the water ledger; the maximum absolute ledger residual is about (1.83\times10^{-12}) cm.

## Numerical-equivalence result

For both B01 and B14, none of R3-R12 lies at or below the metric-specific C6N1 numerical uncertainty on any of:

- 0-20 cm storage;
- 0-40 cm storage;
- 0-80 cm storage;
- mapped 10-cm water-content profile.

Even R16 remains numerically resolved from R2048_T32 on all four views.

This means the candidate-to-Reference difference is larger than the estimated Reference discretization uncertainty. It does **not** mean R16 or any reduced representation is hydrologically unacceptable. No application tolerance has been applied.

## Purpose-dependent placement

The same-dimension comparisons are much more informative for representation selection.

For B01, U8 reduces RMSE relative to lower-zone R8 by factors of approximately:

- 11.7 for 0-20 cm storage;
- 14.6 for 0-40 cm storage;
- 9.7 for 0-80 cm storage;
- 2.0 for the mapped profile.

For B14 the corresponding factors are approximately:

- 10.7;
- 23.3;
- 160.7;
- 1.6.

So the lower-zone placement that repeatedly helped groundwater-output fidelity is a poor transfer assumption for surface-driven soil-state fidelity.

At four states, B14 provides the same signal in another form: P4_TOP_LOWER is much closer than R4 for the 0-20 and 0-40 cm views. U4 and P4 then trade advantages across deeper/profile views, so no single four-state placement dominates every purpose metric.

For B01, R3, R4 and P4_TOP_LOWER leave the frozen qualified domain on U03 through a theta-endpoint failure; U4 remains qualified. That is reported as admissibility evidence, not converted into a new partition choice.

## Scientific consequence

The current evidence now supports a stronger formulation of the Layer-ROM question:

> The relevant quantity is not the minimum number of layers in isolation, but the minimum allocation of vertical information required by a specific hydrological purpose.

Groundwater-driven objectives favor information near the lower boundary. Surface-driven soil-state objectives require information distributed through the upper and full profile.

This is exactly the type of purpose dependence C6K was intended to test.

## What C6N2 does not establish

C6N2 does not provide an independently justified soil-moisture application tolerance. Therefore it cannot label any resolved candidate difference acceptable or unacceptable for operational drought, agronomy or remote-sensing applications.

Bottom flux is prescribed and is outside the fidelity claim.

There is also no root-water-uptake feedback in this workload, so no ET or drought-response claim follows.

## Next authority

C6O may now reconcile root-extraction physics and the reduced-state source contract.

The first task is to derive exact conservative aggregation for a prescribed distributed root sink. Only after that may the workstream examine whether stress-dependent uptake can be predicted from the retained state, and what additional within-layer information that feedback requires.

No new partition, closure, performance test or production-ROM implementation is authorized by C6N2.
