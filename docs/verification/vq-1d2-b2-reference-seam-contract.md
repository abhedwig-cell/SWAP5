# VQ-1d2 B2 reference-seam contract

**Workstream:** VQ  
**Slice:** VQ-1d2  
**Current corrected-reference oracle:** `B1.9`  
**Production code changed:** no

VQ-1d2 strengthens B2 admission beyond capability booleans. Any candidate marked `READY_FOR_VQ_B1_TO_B2` must provide a machine-readable `SWAP5-B2-reference-seam-v1` declaration bound to the same exact implementation commit as the candidate.

The declaration identifies the integrated entrypoint path/symbol and the semantic result-contract path. It requires the full-accuracy `reference` numerical policy with `changes_physics = false`.

The verification boundary exposes parameters, committed physical state, forcing, numerical configuration and generic interval `[t0,t1]` separately. No file/path is required by those kernel-facing inputs and no calendar/day boundary is required.

Transaction semantics are explicit:

```text
checkpoint -> trial/retry -> commit or rollback
rejected trial mutates committed state = false
trial endpoint returned explicitly     = true
```

The seam must expose committed endpoint state, canonical physical results, unrounded mass accounting and transaction diagnostics. Hard mass uses `delta_storage_minus_net_external`; rounded reporting is not an acceptance oracle.

Required diagnostics include accepted status, execution class, retry count, solver iterations/cost, fallback use and balance residual.

A valid seam also declares absence of kernel file I/O, kernel path dependence, MODFLOW tile-fraction knowledge and hidden calendar/day assumptions.

The current real B2 candidate remains blocked because no integrated production seam exists. No seam is invented by this verification layer.

This contract operationalizes invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 28, 29 and 30. The next production handoff is an exact TX/HY/RT reference seam satisfying this contract on one pinned commit.
