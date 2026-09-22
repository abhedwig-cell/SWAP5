# GC-RZM06E07 preregistration

**Status:** preregistered response-blind state construction  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `0127e46ceee2bb35d6eb739d67b26c3e101c9169`

E05 and E06 reached the resolution boundary of the current immutable state library. E06 still supports a different fixed-interface response at a joint storage resolution of `1e-6 cm`, but E05 contains no H16-separated pair at `1e-7 cm` or tighter.

E07 therefore adds a genuinely new state-construction axis rather than searching the same library again.

The 16 x 10 cm B01 strict Reference carrier starts from the same fresh `Se=0.85` state. Every interval retains equal equilibrium top and bottom flux, `q_top=q_bottom=q_eq=-K0`. The new perturbation is entirely internal and below 30 cm.

HeadCalc's existing matrix terms are used with their native balance semantics:

- `qssdi` is the prescribed matrix source;
- `qdra` is the prescribed matrix sink.

Only nodes 6 and 16 are used. Every interval has one positive source and one equally large positive sink, so the prescribed internal forcing is net zero. Two exact opposite directions are tested:

- UPSHIFT: source at node 6, sink at node 16;
- DOWNSHIFT: source at node 16, sink at node 6.

The transfer-rate fractions of the fresh-state `K0` are frozen at

`1/64, 1/32, 1/16, 1/8, 1/4, 1/2`.

Each direction is run for exactly `1, 2, 4, 8` strict intervals. Only complete families enter selection. No fallback, retry, temporal subdivision, tolerance change, direct state mutation or post-hoc extension is allowed.

Selection is response-blind and compares only direction twins with identical rate fraction and step count. The joint storage ladder is:

`1e-6, 1e-7, 1e-8, 1e-9, 1e-10, 1e-12 cm`,

plus an exact numeric-equality rung. A twin pair qualifies at a rung only when both `W_profile` and `W_root30` satisfy that rung and `|ΔH16| >= 0.01 cm`.

The tightest qualifying rung is selected. Any selected pair is persisted with all 16 H/theta values before a later fixed-`H_c` response experiment is preregistered.

E07 is a research state-construction experiment. It does not turn qssdi/qdra into a production coupling design and does not introduce a second MODFLOW state.
