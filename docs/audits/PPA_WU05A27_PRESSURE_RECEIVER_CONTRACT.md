# PPA-WU05-A27 pressure-aware receiver seam contract

Date: 2026-10-02. Status: PREREGISTERED_RESEARCH_ONLY.

## Decision boundary

This experiment selects the auxiliary-shape ownership option from `PPA_WU05A27_MIXED_WALL_STATE_DESIGN.md` for continued A27 research. Full Reference Richards remains the sole owner of matrix water storage. A future lateral wall profile may retain shape/history, but it owns no additional matrix water volume and may not be added to the unchanged Richards storage ledger.

Saturated pressure is separate authority. The accepted Reference pressure head is used directly for signed saturated exchange. No inverse theta-to-pressure construction is used at saturation and no numerical capacity floor is treated as physical storage.

This is not a change to the admitted A26 RFM runtime. In particular, the production RFM nonnegative matrix-source contract is not widened here.

## Prospective seam experiment

Use the actual Reference Richards solver, actual default MvG provider and actual `mod_ppa_wu05a6_saturated_exchange_rate` on a ten-node column. A finite receiver owns only its own water storage. Its water level and hydrostatic macropore head are derived from accepted receiver storage. At each accepted-state-frozen step:

1. derive current receiver water level and moving wetted contact;
2. evaluate signed pressure exchange against accepted Reference matrix heads;
3. map positive macro-to-matrix exchange once to the Reference source and negative matrix-to-macro exchange once to the Reference sink;
4. solve a Reference trial without mutating accepted matrix or receiver state;
5. apply the exact opposite signed amount to the receiver candidate;
6. publish both candidates only on acceptance.

The forcing contains an initially low receiver, a fill pulse, a drain pulse and a rewet pulse so that contact appears, expands, contracts/disappears and reappears. No atmospheric top input is consumed by this receiver seam.

## Gates

Run dt = 0.01, 0.005 and 0.0025 day over the same 0.30 day scenario.

Required:
- at least one positive macro-to-matrix step and at least one reverse matrix-to-macro step at every refinement;
- at least three contact-index changes;
- source/sink rate equals the signed exchange primitive to 1e-12 cm/day;
- receiver amount is exactly opposite to matrix exchange to 1e-12 cm per step;
- Reference integrated mass residual <= 1e-8 cm;
- combined matrix plus receiver ledger <= 1e-7 cm;
- a deliberately replayed trial from identical accepted state reproduces candidate pressure, water content and receiver amount within 1e-12;
- accepted state remains unchanged before publication;
- finest two refinements differ by <= 1e-3 cm in final receiver storage and <= 5e-3 cm in final matrix storage.

A failure is retained. Do not tune conductance or pulse targets after seeing a failed gate.

## Nonclaims

This seam does not qualify the previous 128-cell lateral moisture profile, drying closure, production parameter mapping, full A/B/C equivalence or a speedup. It does not make the research seam production RFM. A later auxiliary profile must preserve this single-storage ownership and pressure authority, then separately qualify profile resolution and execution policy.
