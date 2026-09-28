# F-HYDROFIT02 P-LPRIOR01 interval-provenance audit result

Run: `36433565330`, head `b5e34415e0ca816b88b5aa461032c7c4ee2a629f`.

The exact-interval provenance audit matched all 31 frozen hydrophysical intervals.

Directly inside the target `InvestigatedInterval`:
- `horizonCode`: 31/31, unambiguous;
- `dryBulkDensity`: 31/31, but multiple distinct values in 10/31 intervals;
- `organicMatterContent`, `clayContent`, `sandContent`, `siltContent`, `textureClass`, soil-name/class fields and several other candidate descriptors: 0/31.

This falsifies the assumption that object-level availability implies direct hydrophysical-interval provenance. The object-wide Phase-A inventory showed several such fields, but they occur elsewhere in the BHR-P XML structure.

No lambda relationship has been inspected.

Next step: reconstruct explicit cross-component provenance, using structural identifiers and/or depth overlap only where the BRO representation supports that relation. Do not copy object-level values into target intervals. Resolve the 10/31 multi-valued dry-bulk-density cases before using bulk density as a scalar predictor.
