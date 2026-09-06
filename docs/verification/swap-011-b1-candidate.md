# SWAP-011 B1 candidate

SWAP-011 is the first legacy correction being prepared for the corrected SWAP 4.3.1 reference line.

## Defect

For implicit Richards solving (`SWKIMPL=1`), B0 uses a standard Mualem-van Genuchten conductivity derivative in `dhconduc` for hydraulic models whose actual implemented `K(h)` relation differs. This makes the Newton Jacobian inconsistent with the residual for affected hydraulic models. Model 4 is the standard MvG case and is already consistent.

## Qualification state

The audit line progressed through correctness-reference and optimized implementations and reached:

```text
FIX_TESTED
READY_PATCH_UPSTREAM
```

Recorded E5/E6/E7 evidence includes strict and broad full-run gates, exact Newton-route comparisons, byte-identical output subsets, round-off-scale residual output differences in the remaining paired cases, and a faster optimized production path than the deliberately expensive numerical-reference derivative.

The detailed evidence and provenance requirements are stored under:

```text
reference/swap-4.3.1/patches/SWAP-011/
```

## Why it is not yet in B1

The exact final E7 patch artifact is not currently available in the integrated repository. B1 admission requires the exact qualified patch bytes and verified B0 preimages. Rewriting an equivalent patch from the algorithm description would destroy the provenance chain.

Therefore:

```text
technical correction: qualified
B1 candidate dossier: present
exact patch payload: pending
B1 manifest: unchanged
```

Once the original final patch is recovered and verified, the remaining admission sequence is mechanical: store the patch, verify its preimages against B0, reproduce/attach the qualification gate, update the difference ledger, add the ordered patch ID to the B1 manifest, and freeze the next B1 snapshot.
