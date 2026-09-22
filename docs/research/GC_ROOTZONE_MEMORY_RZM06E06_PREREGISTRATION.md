# GC-RZM06E06 preregistration

**Status:** preregistered fixed-`H_c` response falsification  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `c25258bd0df363c29be693cf5c01b512f4630a27`

E05 selected one immutable state pair at a joint `1e-6 cm` storage-matching resolution. The pair has exact total-profile-water equality, `|ΔW_root30| = 5.002116250096833e-07 cm`, and `|ΔH16| = 0.01317294388797663 cm`.

E06 keeps the E04 response experiment unchanged and tightens only the two aggregate storage gates to `1e-6 cm`.

Both origins are reconstructed at canonical `t0=0` under the GC-RZM06D02R1 common-time authority. Before any response is inspected, E06 requires:

- `|ΔW_profile| <= 1e-6 cm`;
- `|ΔW_root30| <= 1e-6 cm`;
- `|ΔH16| >= 0.01 cm`.

The response experiment remains:

- fixed `H_c = -1.8979370901690651 m`;
- bottom elevation `-1.6 m`;
- mapped pressure head `-29.793709016906497 cm`;
- `dt = 3435974 / 2^32 day`;
- zero top flux;
- strict Reference sample;
- no fallback, no automatic temporal subdivision and no commit;
- primary response: whole-window `bottom_outward_exchange_native`;
- support threshold: `|ΔE| > 1e-18 cm`.

Each origin is probed twice in opposite A/B execution orders with a fresh backend and fresh committed origin. Same-origin results must be bit-identical. Candidates are discarded after observation and committed state must remain unchanged.

A positive result supports non-uniqueness at the frozen `1e-6 cm` aggregate-storage resolution. It remains a resolution-bounded statement because `W_root30` is not mathematically identical. It does not identify H16 as the unique omitted state coordinate and has no production-admission implication.
