# GC-RZM06E08 result

**Status:** qualified research evidence, support at joint `1e-9 cm` aggregate-storage resolution  
**Date:** 2026-09-22  
**Production changes:** none  
**Workflow:** run 35749131548, job 106818345605  
**Executed head:** `1055d4c42064ba6614e321d35aa855f37d036ed8`

E08 reconstructed the immutable E07 direction-twin pair at canonical time and applied the unchanged forcing-free fixed-`H_c` Reference probe.

The pre-response state checks were:

- `|ΔW_profile| = 7.105427357601002e-15 cm`;
- `|ΔW_root30| = 5.560281124417088e-10 cm`;
- `|ΔH16| = 0.01425320747482317 cm`.

Both origins therefore pass the frozen `1e-9 cm` aggregate-storage gates and the `0.01 cm` H16 separation gate.

The fixed-interface response was:

- A whole-window bottom exchange: `0.00313351139418927 cm`;
- B whole-window bottom exchange: `0.003144890124183064 cm`;
- `|ΔE| = 1.1378729993793968e-05 cm`;
- response threshold: `1e-18 cm`;
- mass residual A = B = `0 cm`.

The result is order-independent and O0/O2 output is byte-identical. The E08 response forcing contains no `qssdi` or `qdra`; those terms only describe the E07 origin-construction history.

The admitted conclusion is therefore:

`SUPPORTED_INTERFACE_MEMORY_AT_1E9_STORAGE_RESOLUTION`.

For this selected 16-node C01 carrier and window, fixed `H_c`, total profile water and upper-30-cm water do not uniquely determine the next interface exchange at the frozen `1e-9 cm` aggregate-storage resolution.

This remains resolution-bounded. The root30 storages are not mathematically identical, so E08 does not establish exact-valued global insufficiency. It also does not establish H16 as the unique or minimal missing coordinate.

The next useful step is no longer another tolerance chase. E07 already has no qualifying pair at `1e-10 cm` or exact equality. The next research unit should identify which local or depth-weighted hydraulic coordinate carries the residual response information and then test whether conditioning on that coordinate collapses the observed non-uniqueness.
