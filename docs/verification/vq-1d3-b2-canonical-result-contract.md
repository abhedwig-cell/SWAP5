# VQ-1d3 canonical B2 reference-result contract

**Workstream:** VQ  
**Slice:** VQ-1d3  
**Current corrected-reference oracle:** `B1.10`  
**Production code changed:** no

VQ-1d3 defines the output half of the admitted B2 seam. A READY implementation must provide `SWAP5-B2-reference-result-v1` on the same exact commit as the VQ-1d2 seam.

Adapters normalize each accepted interval to `SWAP5-B2-reference-result-record-v1`. This VQ record is a comparison surface, not a prescribed Fortran type, ABI or production serialization.

The record contains the exact requested `[t0,t1]`, the accepted committed endpoint state at `t1`, stable physical result identifiers, unrounded values, transaction history, diagnostics and implementation provenance.

Mass accounting embeds the common VQ record and is recomputed independently:

```text
delta_storage = end_total - start_total
net_external  = sum(signed external boundary terms)
residual      = delta_storage - net_external
```

`mass_tolerance_applied = false` remains explicit until an actual production B2 result and a qualified tolerance exist. Rounded `.BAL`/`.BLC` output cannot satisfy this gate.

For an accepted interval the transaction record requires exactly one commit; retries/rollbacks and accepted trial identity must agree, and rejected-trial totals may not leak into committed results.

The current B2 production entrypoint, seam and result contract are absent, so B1.10 -> B2 numerical comparison remains blocked. No synthetic result is accepted as production evidence.

This slice directly protects invariants 3, 7, 8, 9, 13, 23, 25, 26, 29 and 30 and prepares later reference/normal/relaxed/fallback qualification on one mass/result identity.
