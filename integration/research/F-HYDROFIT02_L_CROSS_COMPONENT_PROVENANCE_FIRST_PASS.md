# F-HYDROFIT02 P-LPRIOR02 first execution note

Run `36438947650` completed successfully and matched all 31 target intervals.

Current matcher result:
- horizonCode: 31 ASSIGNED;
- dryBulkDensity: 21 ASSIGNED, 10 AMBIGUOUS;
- organicMatterContent: 21 ASSIGNED, 10 AMBIGUOUS;
- clayContent, sandContent, siltContent: 31 MISSING.

The soil-composition MISSING result is not yet interpreted scientifically. The preceding structural audit proved those values exist under `soilLayer` with depth-bearing ancestry. The current implementation only recognizes `beginDepth/endDepth` as a source interval and therefore may not implement the actual `soilLayer` boundary representation.

This is an implementation-semantics issue, not a reason to alter the preregistered overlap classes or priority. Inspect the exact soilLayer boundary fields, then rerun the same frozen rule.
