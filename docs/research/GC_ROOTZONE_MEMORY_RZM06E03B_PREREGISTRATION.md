# GC-RZM06E03B preregistration

**Status:** preregistered diagnostic research experiment  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `511b6f9fcf40702786ecb84bc5b253998db214aa`

E03B follows the qualified E03 NO_MATCH. E03 showed that simultaneous equal top and bottom throughflow brings upper-30-cm storage and the whole-profile first moment back toward baseline on almost the same state-space trajectory. E03B therefore changes the construction, not the thresholds.

The C01 16 x 10 cm B01 strict Reference carrier is retained. Every family starts from the same fresh `Se=0.85` origin and uses `dt = 3435974 / 2^32 day`. Let `q_eq=-K0`, with `K0` reconstructed from the fresh B01 seed.

After ten closed redistribution intervals, E03B separates the two boundary transfers in time. A top phase uses `q_top=q_eq, q_bottom=0`; a bottom phase uses `q_top=0, q_bottom=q_eq`. For each `n in {8,9,10,11,12}`, both TOP_THEN_BOTTOM and BOTTOM_THEN_TOP are run for exactly `n` intervals per phase. Thus every completed family has exactly equal integrated top and bottom boundary transfer even though their timing differs. BASE_EQ remains a one-interval simultaneous-throughflow control.

Only fully completed strict families enter the candidate set. A failure terminates that family and must preserve its latest committed origin. No retry, fallback, tolerance change, direct state mutation or post-hoc extension is allowed.

Pair selection is response-blind and uses only committed node `H/theta`. For every distinct-history candidate pair:

- `|ΔW_profile| <= 1e-4 cm`;
- `|ΔW_root30| <= 1e-4 cm`;
- `|ΔM1| >= 1e-2 cm`.

The ranking is largest `|ΔM1|`, then smallest root30 mismatch, then smallest total-water mismatch. No bottom exchange, terminal flux, tangent or predictor quantity may be emitted to or parsed by the selector.

A selected pair must be persisted before any response test. Only then may E04 be preregistered for common-time reconstruction and an identical forcing-free fixed-`H_c` response probe. A NO_MATCH closes E03B without altering the frozen grid, fluxes, timestep or thresholds.
