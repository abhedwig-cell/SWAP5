# F-ROM-LARE BC2-C4E closeout

## Scope

C4E is a bounded, teacher-forced endpoint counterfactual. It removes one exact C3 additive local-error family at a time. Counterfactual states are not propagated. No closure is fitted or changed.

Authority is workflow run 35460239887 at execution head 80a95f35c278e0985764f7cf730066d5ac4c73a2, using tests/rom/analyze_lare_bc2_c4e_local_qi_causal.py. The aggregate artifact is 10589773291, digest sha256:d0fd81d19585372565e08765c5cf95e281bb9fbd2fc76d4123170f883f63d485. The exact result SHA-256 is 06069d4b43405c81ff05c821f5e601e17ac57fc034947e5ef7ec5d524079d290.

## Formal decision

QI_LOCAL_CAUSAL_DIAGNOSTIC_BLOCKED

All four cases and both internal time-step routes completed, the additive and physical-ledger hard gates remained below 1e-10, and primary/cross removal rankings were route-consistent. The causal comparison is nevertheless blocked because not every preregistered single-family counterfactual remains inside the same qualified physical domain.

## What the bounded cases show

At 5 cm under WT_RISE, all controls are admissible. REMOVE_QI is uniquely best in both routes and lowers pooled local shape error to about 0.297 of BASE, a reduction of about 70.3%.

At 5 cm under WT_FALL, REMOVE_QI is admissible and lowers pooled local shape error to about 0.598 of BASE, a reduction of about 40.2%. REMOVE_GEOMETRY_GI is outside the qualified domain for one interval in each route. The preregistered unique-best causal comparison is therefore not valid for this case.

At 2.5 cm under WT_RISE, REMOVE_QI itself is admissible for all 512 intervals, but pooled local shape error increases to about 3.85 times BASE in both routes. REMOVE_QH is outside the qualified domain for 428 intervals. This is direct bounded evidence that exact QI-contribution removal is not resolution-independent in its effect.

At 2.5 cm under WT_FALL, REMOVE_QI is outside the qualified physical domain for 499 of 512 intervals in both routes. The QI metric over the remaining subset must not be read as a full-history response result.

## Scientific reconciliation

The earlier C3/C4D result remains valid: QI is rank-1 across the frozen monotone phase-integrated signed-bias decomposition and strong signed cancellation explains the cycle-level rank shift. C4E asks a different question: whether removing that contribution yields a physically admissible and consistently better endpoint state.

It does not do so uniformly. In this bounded laboratory, QI attribution is representation- and history-dependent. A rank-1 error contribution is therefore not sufficient evidence for a transferable corrective closure.

This also sharpens the state-versus-closure distinction established by P2C and DYN0A. Sufficient retained state information does not imply that a chosen low-order propagation closure, or a local error-family correction derived from it, is adequate at every representation width.

## Boundary of the claim

C4E does not adjudicate GW-R, GW-D, AG-WB, EVT or SCI-P application acceptance. It does not test groundwater feedback, free-running corrected LARE, computational speed or production deployment. C4B remains authoritative evidence that direct oracle-flux substitution may leave the qualified domain.

No QI correction, direction switch, extra memory state or production ROM is authorized.

## Next scientific boundary

A new closure hypothesis now requires a separate preregistration that first explains the width-dependent change in QI effect and the counterfactual-admissibility failures. Choosing that mechanism is a scientific decision, not an automatic continuation from C4E.
