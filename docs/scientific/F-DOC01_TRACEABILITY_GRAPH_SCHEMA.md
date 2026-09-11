# F-DOC01 traceability graph schema

The graph registry is intentionally small and tool-neutral. YAML is the authoring format; JSON Schema supplies structural validation. Graph analytics are derived products.

## Node fields

Required: `id`, `kind`, `tier`, `title`, `status`, `authority`, `record_version`.

Optional/conditional fields include `scope`, `equation`, `symbols`, `units`, `assumptions`, `sources`, `repository_path`, `symbol`, `source_commit`, `source_tree`, `test_ids`, `qualification_authority`, `applicability`, `nonclaims`, `introduced_in`, `superseded_by`, and `notes`.

Node status vocabulary:

`DRAFT`, `PROVISIONAL`, `ACTIVE`, `GAP`, `HISTORICAL_REFERENCE`, `SUPERSEDED`, `RETIRED`.

A T10 production implementation node additionally requires an exact repository path, symbol or significant region, and exact source authority. `reference/fortran/**` is only legal with `HISTORICAL_REFERENCE`, never as `production: true`.

## Edge fields

Required: `from`, `to`, `relationship`, `status`.

Optional: `authority`, `version`, `source_commit`, `rationale`, `scope`, `evidence_locator`.

Edge status: `ASSERTED`, `VERIFIED`, `PROVISIONAL`, `GAP`, `SUPERSEDED`.

## Registry-level metadata

Every graph file records schema version, workunit/source authority, registry scope, denominator definition for any completeness metric and generated-at source commit. Metrics are never stored as unexplained percentages.

## Gap detection

The minimum automated queries are:

1. production T10 nodes without a reverse path to T1;
2. T3 equations without T6/T8/T10 mappings where implementation is claimed;
3. T10 nodes without T11 verification;
4. qualified T13 nodes without exact qualification authority;
5. T14 nodes without a source commit/tree;
6. theory/equation nodes without provenance;
7. edges to unknown IDs;
8. implementation paths that do not exist at the pinned source authority;
9. Status A requirement mappings with no external criterion authority;
10. capability audits marked ready while mandatory graph gaps remain.

## Completeness metrics

Metrics must name numerator and denominator, for example:

`implementation_reverse_trace_coverage = count(production_scientific_T10_with_path_to_T1) / count(all_production_scientific_T10)`.

A denominator may be `UNDEFINED` while the production capability inventory is incomplete. F-DOC01 therefore does not invent counts such as `126 routines` or percentages such as `93% Status A`.
