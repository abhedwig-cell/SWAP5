# GC-RZM06E10 preregistration

**Status:** preregistered fixed-`H_c` response falsification  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `2bc1b16f7e4d51e9cbcaa1a6cf16105a57403b9a`

E09 selected an immutable near-interface redistribution pair for which the frozen canonical binary64 reconstruction gives exactly equal `W_profile` and exactly equal `W_root30`, while `|ΔH16| = 0.22296695246544473 cm`.

That E09 reconstruction is the authority for the exact-rung claim. E10 independently reads the persisted node vectors back into Fortran. Because summation order differs, the probe-side sums are not used to redefine exactness. They are only required to agree within `1e-12 cm` as a round-trip consistency check. The origin extractor separately repeats the E09 `math.fsum` reconstruction and requires exact numeric equality before the probe can execute.

Both origins are reseeded at canonical `t0=0`. The response forcing is unchanged from E04, E06 and E08:

- fixed `H_c = -1.8979370901690651 m`;
- bottom elevation `-1.6 m`;
- mapped bottom pressure head `-29.793709016906497 cm`;
- `dt = 3435974 / 2^32 day`;
- zero top flux;
- no qssdi or qdra;
- strict Reference sample only;
- no retry, fallback, automatic temporal subdivision or commit.

The primary response remains whole-window `bottom_outward_exchange_native`, with unchanged support threshold `|ΔE| > 1e-18 cm`.

Each origin is run in both A/B orders with a fresh committed origin and backend. Same-origin results must be bit-identical, all candidates are discarded, mass accounting must be complete with `|residual| <= 1e-12 cm`, and complete O0/O2 output must be byte-identical.

A positive result supports that, within the represented binary64 C01 state and this frozen finite response window, `H_c + W_profile + W_root30` are not sufficient to determine a unique next interface exchange. It is not a continuum theorem, does not identify H16 as the unique or minimal omitted coordinate, and does not admit a production coupling change.
