# F-DOC01 scientific ID policy

Scientific IDs are semantic identities, not page or file locations. IDs are never reused after retirement and normally survive wording, file-layout and implementation refactors.

## Prefixes

- `SW5-PHEN-####` physical phenomenon / T0
- `SW5-TH-####` scientific theory / T1
- `SW5-CONCEPT-####` conceptual model / T2
- `SW5-EQ-####` formal equation or equation system / T3
- `SW5-CLOSURE-####` constitutive or empirical closure / T3/T4
- `SW5-BC-####` boundary/initial condition / T3/T4
- `SW5-FORM-####` SWAP-specific or computational continuous formulation / T4/T5
- `SW5-DISC-####` discretisation / T6
- `SW5-NUM-####` numerical method / T7
- `SW5-ALG-####` algorithm / T8
- `SW5-CONTRACT-####` software contract / T9
- `SW5-IMPL-####` production implementation mapping / T10
- `SW5-VRF-####` verification case/evidence binding / T11
- `SW5-VAL-####` validation evidence binding / T12
- `SW5-QUAL-####` qualification/applicability binding / T13
- `SW5-REL-####` release/source authority / T14
- `SW5-PARAM-####` parameter definition
- `SW5-DATA-####` data/input provenance object
- `SW5-FFP-####` fitness-for-purpose/application-class object
- `SW5-DISCERP-####` theory/documentation/code/evidence discrepancy

Four digits are allocation labels, not ordering or version numbers.

## Identity and versioning

Each record contains `id`, `record_version`, `status`, `title`, `authority`, `introduced_in`, optional `superseded_by`, and provenance. Scientific meaning changes require either a new record version or, when identity changes materially, a new ID plus an explicit `SUPERSEDES` relation.

Implementation mappings are version-sensitive. The stable `SW5-IMPL-*` identity may point to different exact code regions by release, but every mapping instance must pin source commit/tree and symbol/region.

## Allocation rules

1. allocate only when the object has a defined scope and owner;
2. never encode file names, line numbers, branch numbers or workunit numbers into the stable ID;
3. do not create duplicate IDs for the same scientific object merely for different publication products;
4. record aliases for established legacy symbols/names rather than changing stable IDs;
5. retire, never delete, an ID that has entered released evidence;
6. references in evidence remain immutable to the version they qualified.

## Validation

CI rejects duplicate IDs, invalid prefixes, unknown edge endpoints and reused retired IDs. Human-readable documents may use section anchors, but only stable IDs serve as cross-document scientific keys.
