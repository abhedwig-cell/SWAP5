# F-ROMV MDE S2D local-table discovery adjudication

**Decision:** **LOCAL_TABLE_DISCOVERY_PROMISING_FOR_NEW_UNEXPOSED_VALIDATION**

This is a development gate, not application acceptance and not production ROM authority.

The Stage-1 global bilinear closure failed because a formally in-domain held-out state could trigger a physically impossible transition. S2D deliberately changes the closure hypothesis rather than tuning that failed model. It uses an exact-forcing, one-nearest-neighbour transition table and tests it only by leave-one-discovery-history-out replay on D01-D08. H01-H04 and B14 remain excluded because they have already been exposed elsewhere or belong to a different transfer question.

All four frozen candidate states, C2, C4, C8 and C9_G8, pass the structural integrity screen. No replay publishes nonfinite state, no reconstructed water content leaves the B01 physical interval, and the conservative storage update preserves the explicit water ledger.

All four also beat the preregistered forcing-only mean baseline on pooled recursive total-storage and cumulative-bottom-exchange RMSE. The baseline RMSE is about 0.0343 cm, whereas C2 is about 0.00873 cm. The baseline also produces 95 wrong terminal bottom-flux signs in 504 evaluated intervals; C2 produces none.

The preregistered dimension rule therefore selects **C2, dimension 2**, before any new validation histories are generated.

C2 consists of total storage plus one shape contrast between the upper and lower 80-cm water-content means. It should not be interpreted as proof that the B01 dynamics are intrinsically two-dimensional. It establishes only that, within this discovery experiment and with a local transition table, two coordinates contain enough information to improve substantially on a forcing-only model without violating physical integrity.

The positive discovery result is not uniformly strong. In D03 the final cumulative bottom-exchange error is about 0.0203 cm against roughly 0.0395 cm actual evaluated exchange. In D04 the final error is about 0.0537 cm against roughly 0.328 cm actual exchange. These are exactly the kinds of discrepancies that a purpose-dependent acceptance envelope must judge. They cannot be declared acceptable from discovery evidence.

Conversely, event information is better retained in this particular discovery replay than the balance errors alone might suggest. The frozen bottom-flux reversal steps are reproduced for all eight leave-one-history-out folds, and no flux-sign error occurs. This is encouraging, but it is not sufficient evidence for event-sensitive application use because the folds are built from the same discovery design family.

The scientific interpretation is therefore narrow:

> A simple local/tabulated dynamic closure is sufficiently stable and informative on the existing B01 discovery family to justify one genuinely new blind-validation experiment.

The following claims remain prohibited:

- no production ROM;
- no B01 application acceptance;
- no cross-material transfer;
- no claim that two state variables are universally sufficient;
- no performance advantage yet;
- no use of H01-H04 as blind validation for this successor;
- no threshold tuning from exposed data.

The next step is to freeze C2 and its lookup rule, preregister new forcing histories on the current canonical Reference research route, generate those histories only after the design is frozen, and then test hydrological fidelity by application lens. One validation history must deliberately contain unseen combined forcing tuples so fail-closed fallback is tested rather than inferred.

Only after that blind gate should C2 be compared on computational cost with current RossFast, coarse Richards and a simple physical-reduction comparator.
