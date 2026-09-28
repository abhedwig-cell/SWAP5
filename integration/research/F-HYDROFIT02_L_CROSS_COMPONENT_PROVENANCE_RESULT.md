# F-HYDROFIT02 P-LPRIOR02 cross-component provenance result

Corrected authority run: `36443606773`, head `24d5414dc343e9a4bdf92bd9a46b58727724dfb5`.

The first pass had treated soilLayer composition descriptors as missing because the implementation recognized only `beginDepth/endDepth`. A separate semantics audit established that all 44 soilLayer records use `upperBoundary/lowerBoundary`. The parser was corrected without changing the preregistered overlap classes or priorities.

Across the frozen 31 hydrophysical intervals:
- horizonCode: 31 ASSIGNED;
- dryBulkDensity: 21 ASSIGNED, 10 AMBIGUOUS;
- organicMatterContent: 21 ASSIGNED, 10 AMBIGUOUS;
- clayContent: 19 ASSIGNED, 12 MISSING;
- sandContent: 10 ASSIGNED, 21 MISSING;
- siltContent: 2 ASSIGNED, 29 MISSING.

Thus soil-composition metadata cannot support a universal first conditional prior on this 31-interval corpus without substantial missing-data policy. No imputation is introduced here.

The universally available leakage-free candidate basis remains:
- target interval geometry;
- direct raw theta(h)/K(h) measurement summaries;
- horizonCode.

Bulk density and organic matter may be investigated later as secondary partial-coverage strata, but their 10 ambiguous cases are not silently averaged or imputed.

No lambda predictive relationship was inspected in P-LPRIOR02.
