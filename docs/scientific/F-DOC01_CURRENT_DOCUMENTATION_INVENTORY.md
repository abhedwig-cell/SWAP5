# F-DOC01 current documentation inventory

Inventory authority: `integration/f-ci-canonical@3c5f5bd3686e1632058b906be21abd73883e30ef`.

This is a structural audit, not a bulk rewrite plan. Classification describes fitness for the new documentation system, not scientific correctness of every statement in an artifact.

| Artifact/group | Current role | F-DOC01 classification | Main gap/action |
|---|---|---|---|
| `mkdocs.yml` | published documentation composition, strict build | REUSABLE_WITH_UPDATE | add scientific documentation section |
| `tools/docs/check_docs.py` | lightweight docs integrity checks | REUSABLE_WITH_UPDATE | add registry/ID/reference validation without building a new framework |
| `docs/architecture/invariants.md` | 30 SWAP core invariants | REUSABLE_AS_IS | link invariant IDs to traceability/audit records |
| `docs/architecture/overview.md` | target architecture overview | REUSABLE_WITH_UPDATE | scientific capabilities need T0-T14 links |
| `docs/architecture/component-map.md` | component boundaries | REUSABLE_WITH_UPDATE | add stable component/capability IDs and theory/evidence links |
| `docs/architecture/data-ownership.md` | ownership categories | REUSABLE_WITH_UPDATE | connect parameters/state/forcing/results/scratch to contracts |
| `docs/architecture/implementation-status.md` | implemented/target distinction | REUSABLE_AS_IS | use as guard against invented T10 mappings |
| `D3a_IMPLEMENTATION_STATUS_MAP.md` | top-level implementation status | REUSABLE_WITH_UPDATE | connect entries to implementation nodes |
| `D3b_COMPONENT_OWNERSHIP_MAP.md` | ownership map | REUSABLE_WITH_UPDATE | map to T9 contract and organisational ownership separately |
| `D3c_LEGACY_TO_TARGET_MIGRATION_MAP.md` | legacy/target lineage | REUSABLE_WITH_UPDATE | add scientific continuity/change/discrepancy classification |
| `D3d_MIGRATION_SLICES_AND_GATES.md` | migration slices | REUSABLE_WITH_UPDATE | connect migration gates to qualification evidence nodes |
| `D3e_M3_GATE_EVIDENCE.md` | migration evidence | HISTORICAL_EVIDENCE_ONLY for later release claims | evidence can be linked, not promoted beyond its qualified scope |
| `docs/decisions/ADR-*` | architecture decisions | REUSABLE_AS_IS | decision nodes can justify T8/T9/T10 relationships, never substitute for theory |
| `docs/development/documentation.md` | docs source-of-truth and terminology | REUSABLE_AS_IS | F-DOC01 extends rather than replaces it |
| `docs/development/publication.md` | docs publication policy | REUSABLE_WITH_UPDATE | publication views should be generated from scientific source of truth |
| `docs/development/workstream-execution-protocol.md` | workunit governance | REUSABLE_WITH_UPDATE | add scientific documentation delta obligations |
| `docs/integration/F-CI*` | canonical admission/governance evidence | REUSABLE_AS_EVIDENCE | remain authoritative for their exact admission/closeout scopes |
| `docs/verification/principles.md` | verification conventions | REUSABLE_WITH_UPDATE | hard-link verification vs validation taxonomy |
| `docs/verification/mass-accounting-contract.md` | water-balance verification contract | REUSABLE_AS_IS | expose as evidence for conservation requirements, not field validation |
| `docs/verification/reference-baseline*` | legacy/reference comparison | REUSABLE_AS_EVIDENCE | explicitly classify as legacy/reference evidence, not physical validation |
| F-VQ/F-MQ qualification artifacts | independent/scoped qualification evidence | REUSABLE_AS_EVIDENCE | referenced by stable evidence locator, no duplicate authority |
| `docs/performance/*` | performance evidence/policy | REUSABLE_WITH_UPDATE | connect numerical policy claims to T7/T13 and keep physics separate |
| `docs/legacy/swap-4.3.1-baseline.md` | legacy baseline | HISTORICAL_EVIDENCE_ONLY | add lineage to external theory/manual sources where scientifically valid |
| `reference/fortran/**` | frozen/reference implementation material | HISTORICAL_EVIDENCE_ONLY | never use as SWAP5 production T10 mapping |
| current source/implementation material | repository is still documentation-led for significant areas | STATUS_A_GAP | exact production mappings may be absent; record gap rather than invent mapping |
| theory/equation registry | none found as integrated system | STATUS_A_GAP | create stable scientific IDs and graph |
| parameter/calibration registry | no complete Status-A-ready registry found | STATUS_A_GAP | establish schema; populate incrementally |
| raw-input provenance registry | no complete kernel-facing lineage registry found | STATUS_A_GAP | establish raw→preprocess→adapter→object→kernel chain |
| validation registry | no complete application-class validation registry found | STATUS_A_GAP | establish evidence classes and explicit unvalidated scope |
| sensitivity/uncertainty registry | evidence exists only in scoped workunits, not a complete model-level architecture | STATUS_A_GAP | create qualitative/quantitative slots and coverage metrics |
| fitness-for-purpose registry | no first-class application-class object found | STATUS_A_GAP | create application-class framework |
| organisational ownership/maintenance dossier | architecture ownership exists, named Status A management ownership incomplete | STATUS_A_GAP | define schema; leave unknown people/roles as gaps |
| Status A/AA criterion matrix | no current formal matrix found | STATUS_A_GAP | create provisional public-baseline matrix plus WR-QA-2024 authority gate |

## Repository-state constraint

The current repository explicitly distinguishes target architecture, reference material and implemented status. F-DOC01 therefore applies the following mapping rule:

- `reference/fortran/**` may support lineage or historical-behaviour nodes;
- architecture documents may support contracts and intended design;
- only actual production implementation admitted to the relevant SWAP5 source authority may satisfy T10;
- a missing T10 mapping is `GAP_NOT_INTEGRATED_PRODUCTION_SOURCE`, not an invitation to point at a legacy routine.

## SWAP 4.3.1 documentation lineage classes

Every legacy theory/manual/report item imported later must receive one of:

- `UNCHANGED_SCIENTIFIC_CONTINUITY`
- `STRUCTURALLY_REIMPLEMENTED`
- `SCIENTIFICALLY_CHANGED`
- `LEGACY_DEFECT_CORRECTED`
- `OBSOLETE`
- `SOURCE_CODE_RECONSTRUCTION_ONLY`
- `UNRESOLVED_LINEAGE`

For each item the registry must preserve original source/provenance, current scientific assessment, SWAP5 relationship and qualification evidence. Known SWAP 4.3.1 defects must never become SWAP5 theory merely because they are observable in frozen code.

## Immediate conclusion

The present documentation is a strong architecture/governance base, but it is not yet a Status-A dossier. The largest structural gaps are scientific theory authority, formal equation-to-implementation mappings, complete parameter/input provenance, validation and uncertainty coverage, fitness-for-purpose objects, and formal organisational evidence. These gaps are expected inputs to incremental follow-on documentation work, not defects to hide inside F-DOC01.
