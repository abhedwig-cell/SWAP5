# F-HYDROFIT02 P-LPRIOR01 Phase-A descriptor availability result

Run: `36430547899`, head `1173562b1988f186167f4e2bb55a147567b64a92`.

## Audit integrity

The first attempted audit in run `36429654653` was invalid. Duplicate investigated intervals sharing the same BRO id and depth pair were collapsed by the audit key, producing `target mismatch rows=121 targets=28`. In addition, the shell pipe masked the non-zero Python exit status. No scientific inference is retained from that failed attempt.

The audit was corrected to preserve duplicate interval multiplicity and the workflow now uses `set -o pipefail` for this step. The confirming run completed successfully with:

- 9 BRO objects;
- 31/31 frozen hydrophysical intervals matched;
- no audit failure.

## Leakage-free measurement descriptors

All preregistered directly observed/geometry descriptors have 31/31 coverage:

- interval begin depth, end depth and thickness;
- observation count;
- observed h minimum, maximum and span;
- observed theta minimum, maximum and span;
- observed positive-K log10 minimum, maximum and span.

The observed designs are not uniform. Observation count ranges from 17 to 321. h-span ranges from 354 to 15849 cm H2O. This means measurement-design descriptors may carry information and must not be assumed interchangeable across intervals.

## Metadata inventory

The broad object-level XML inventory shows potentially useful non-hydraulic descriptors are present, including:

- `dryBulkDensity`: 9/9 objects;
- `organicMatterContent`: 9/9;
- `clayContent`: 7/9;
- `textureClass`: 7/9;
- several soil classification and horizon descriptors.

However this inventory is only an availability screen. It aggregates scalar leaves over a whole BRO object and therefore does not yet prove that a value can be assigned unambiguously to the target investigated interval.

Several fully populated fields are also explicitly unsuitable as predictors because they are hydraulic source-fit outputs or are too close to the target modelling process, including `modelledSaturatedHydraulicConductivity`, `residualVolumetricWaterContent`, and other stored fitted hydraulic characteristics.

## Phase-A conclusion

There is enough leakage-free raw measurement information to continue P-LPRIOR01, and promising soil/sample metadata exists. Phase B must not start yet.

The next required step is an interval-scoped provenance audit that maps candidate soil/sample descriptors to each of the 31 target intervals, records missingness and ambiguity, and excludes all source-fit hydraulic quantities before any predictive relation with lambda is inspected.
