# DOC-Q01 Status A to Status AA documentation gap baseline

This is a documentation-readiness assessment, not a claim that SWAP5 has reached Status A or Status AA. `PARTIAL` means relevant material exists but completeness, provenance or reconciliation is insufficient.

| Area | Status A baseline | Status AA baseline | Evidence observed | Gap / required action | Owner |
| --- | --- | --- | --- | --- | --- |
| Conceptual model | `GAP` | `GAP` | Architecture overview and invariants exist. | No reconciled scientific conceptual-model set. | Scientific governance |
| Formal model | `GAP` | `GAP` | Fragmentary equations and contracts occur in technical pages. | No complete, version-bound formal model description. | Scientific governance |
| Technical implementation | `PARTIAL` | `GAP` | Architecture, ADR and F-CI records exist. | Assess every page against exact canonical and downstream source commits. | DOC + source owners |
| Parameters and variables | `GAP` | `GAP` | Isolated schemas and legacy inputs exist. | No canonical parameter/variable dictionary with units, domains and provenance. | Model/API owners |
| Inputs and outputs | `PARTIAL` | `GAP` | Legacy baseline and result contracts cover parts. | User-level, version-bound I/O reference is incomplete. | I/O + DOC |
| Data provenance | `PARTIAL` | `GAP` | B0/B1 and qualification provenance records exist. | Documentation-wide provenance has not been assessed. | DOC + VQ |
| Testing | `PARTIAL` | `GAP` | Extensive VQ and integration records exist. | Registry entries are not systematically bound to tests. | DOC + VQ |
| Validation | `GAP` | `GAP` | Verification evidence is not equivalent to scientific validation. | Define validation domains, observations, metrics and acceptance. | Scientific validation |
| Sensitivity analysis | `GAP` | `GAP` | No canonical coverage established in DOC-Q01 inventory. | Establish methods, parameter scope and evidence. | Scientific validation |
| Uncertainty analysis | `GAP` | `GAP` | Performance uncertainty is documented only for measurement experiments. | Model-input, structural and predictive uncertainty remain undocumented. | Scientific validation |
| Applicability | `GAP` | `GAP` | Scattered scope statements exist. | Consolidated, evidence-bound applicability statement absent. | Scientific governance |
| Limitations | `GAP` | `GAP` | Local limitations occur in technical records. | Canonical limitation register absent. | Scientific governance |
| Version control | `PARTIAL` | `PARTIAL` | Documentation-as-code and Git history exist. | Immutable release documentation sets are not implemented. | DOC + release management |
| Governance and responsibilities | `PARTIAL` | `PARTIAL` | Workstream and quality governance pages exist. | Named review authority and release documentation owner are not yet fixed. | Programme governance |
| Dependencies | `GAP` | `GAP` | Build dependencies are pinned only coarsely. | Runtime and scientific dependency documentation is incomplete. | Build + component owners |
| User documentation | `GAP` | `GAP` | Landing page and legacy baseline exist. | No complete SWAP5 installation, configuration and operation guide. | DOC + release management |
| Release history | `PARTIAL` | `GAP` | Git and development records provide history. | No canonical release notes tied to immutable documentation sets. | Release management |
| Peer-review readiness | `GAP` | `GAP` | Evidence is distributed across technical records. | No frozen review package or claim-to-evidence matrix. | Scientific governance + VQ |

Status A first requires closing the high-level conceptual, formal, parameter, validation, applicability and limitation gaps and converting relevant `NOT_ASSESSED` registry entries into evidence-bound statuses. Status AA additionally requires a mature validation and uncertainty body, immutable release documentation, full traceability and a peer-review-ready package. DOC-Q01 does not assign completion percentages because the denominator and acceptance contract are not yet qualified.
