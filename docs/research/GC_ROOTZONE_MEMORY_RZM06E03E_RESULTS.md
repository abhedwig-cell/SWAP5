# GC-RZM06E03E result

**Status:** qualified response-blind state selection  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration:** `446300e92b135c8dffee833f7f5b85876bb75ca2`  
**Workflow:** run 35746647393, job 106809890643

E03E re-used the immutable E03D state library and screened only pairs satisfying both storage controls. The qualification gate passed, including exact artifact-authority checks and source O0/O2 identity checks.

Of the 59 storage-matched pairs, 14 also satisfy the preregistered interface-state gate `|ΔH16| >= 0.01 cm`.

The selected pair is:

- A: E01 / CLOSED / step 1;
- B: E03 / DRY_RECOVER / RECOVER / step 19.

The pair has:

- `ΔW_profile = 0 cm`;
- `|ΔW_root30| = 4.3428876926654425e-05 cm`;
- `|ΔH16| = 0.0738671093353922 cm`;
- `|Δtheta16| = 0.00020109466583684288`.

The H16 separation is about 7.39 times the frozen `0.01 cm` state-separation requirement. Selection used only immutable provenance and node H/theta. No fixed-Hc response quantity entered selection.

This establishes that the attained strict 16-node state library contains states that are effectively matched in total and upper-30-cm storage while retaining a materially different interface-adjacent pressure head. It does not establish that H16 is a minimal state variable or that H16 alone causes a response difference.

E03E closes as `QUALIFIED_RESPONSE_BLIND_STORAGE_MATCHED_INTERFACE_STATE_PAIR_SELECTED`. The selected full H/theta vectors are persisted in the result JSON before any response probe.
