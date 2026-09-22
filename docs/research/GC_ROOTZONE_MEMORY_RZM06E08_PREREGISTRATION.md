# GC-RZM06E08 preregistration

**Status:** preregistered fixed-`H_c` response falsification  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `91d00f62a1150a8310296ba0ee877b9c1842cfa4`

E07 prospectively constructed a direction-twin pair using equal and opposite deep matrix source/sink forcing. The selected pair has reconstructed equal total profile water, `|ΔW_root30| = 5.560298887985482e-10 cm`, and `|ΔH16| = 0.01425320747482317 cm`.

E08 contains no qssdi or qdra forcing. Those terms are only provenance of how the immutable E07 origins were constructed. Both profiles are reseeded independently at canonical `t0=0` and receive the same forcing-free fixed-interface experiment.

Before response access E08 requires:

- `|ΔW_profile| <= 1e-9 cm`;
- `|ΔW_root30| <= 1e-9 cm`;
- `|ΔH16| >= 0.01 cm`.

The fixed response probe is unchanged from E04 and E06: `H_c=-1.8979370901690651 m`, bottom elevation `-1.6 m`, mapped bottom pressure head `-29.793709016906497 cm`, `dt=3435974/2^32 day`, zero top flux, strict Reference sample, no fallback, no automatic temporal subdivision and no commit. The response threshold remains `|ΔE|>1e-18 cm`.

Both origins are probed in both execution orders with fresh committed origins and fresh backends. Same-origin output must be bit-identical. All candidates are discarded and committed state must remain unchanged.

A positive result supports non-unique fixed-interface response at the frozen `1e-9 cm` aggregate-storage resolution. It remains resolution-bounded because root30 storage is not mathematically identical, and it does not establish H16 as a unique or minimal missing state coordinate.
