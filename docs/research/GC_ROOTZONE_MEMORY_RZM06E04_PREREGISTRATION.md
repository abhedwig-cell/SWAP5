# GC-RZM06E04 preregistration

**Status:** preregistered fixed-`H_c` response falsification  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `dc08a9699e2257299aad4dc1b91fbd3d78aa9f8e`

E03E selected one immutable response-blind pair that matches both total profile water and upper-30-cm water while retaining a material difference at the node adjacent to the groundwater interface.

The selected origins are fixed:

- A: E01 / CLOSED / step 1;
- B: E03 / DRY_RECOVER / RECOVER / step 19.

Before any response quantity is evaluated, E04 reconstructs both profiles at canonical `t0=0`, using the common-time reseed authority qualified in GC-RZM06D02R1. It then rechecks:

- `|ΔW_profile| <= 1e-4 cm`;
- `|ΔW_root30| <= 1e-4 cm`;
- `|ΔH16| >= 0.01 cm`.

The expected persisted values are `ΔW_profile=0`, `|ΔW_root30|=4.3428876926654425e-05 cm`, and `|ΔH16|=0.0738671093353922 cm`.

Both origins then receive exactly the same forcing-free fixed-interface experiment used by E02:

- `H_c = -1.8979370901690651 m`;
- bottom elevation `-1.6 m`;
- mapped bottom pressure head `-29.793709016906497 cm`;
- `dt = 3435974 / 2^32 day`;
- zero top flux;
- strict Reference sample, one physical advance, no fallback, no automatic temporal subdivision and no commit.

The primary response is whole-window `bottom_outward_exchange_native`. The unchanged support threshold is `|ΔE| > 1e-18 cm`. Terminal bottom flux and solver diagnostics are descriptive only.

Each origin is executed twice, once in each A/B order, with a fresh committed origin and fresh backend. Same-origin output must be bit-identical across order. Every candidate is discarded and the committed origin must remain bit-identical.

A supported result falsifies the sufficiency of `H_c + W_profile + W_root30` for this selected C01 carrier/window. It does not establish that H16 is the unique or minimal missing state variable and does not admit a second MODFLOW hydraulic state or any production coupling change.
