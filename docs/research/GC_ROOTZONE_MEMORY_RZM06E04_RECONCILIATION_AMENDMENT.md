# GC-RZM06E04 interpretation amendment

**Status:** pre-execution reconciliation amendment  
**Date:** 2026-09-22  
**Production changes:** none  
**Frozen experiment changed:** no

The E04 pair has exactly equal reconstructed total profile water, but upper-30-cm water is matched within the preregistered `1e-4 cm` tolerance rather than exactly equal. This matters for the scientific wording.

All experimental choices remain frozen: the E03E pair, common-time reseed, state gates, fixed `H_c`, timestep, zero top flux, strict Reference semantics, response threshold, execution orders and transaction-safety controls.

If E04 finds a response difference, the supported conclusion is therefore resolution-bounded:

> At the frozen aggregate resolution `|ΔW_profile| <= 1e-4 cm` and `|ΔW_root30| <= 1e-4 cm`, `H_c` plus those aggregate storage coordinates do not determine a unique next whole-window interface exchange for the selected carrier and window.

That result would not by itself prove that exact-valued `H_c + W_profile + W_root30` are mathematically insufficient, nor that H16 is the unique or minimal omitted state coordinate. It also has no production-admission implication.
