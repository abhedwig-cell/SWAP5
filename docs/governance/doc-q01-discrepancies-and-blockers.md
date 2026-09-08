# DOC-Q01 discrepancies and blockers

| ID | Classification | Affected scope | Evidence | Owner / route | Fail-closed effect |
| --- | --- | --- | --- | --- | --- |
| DOC-Q01-D01 | `outdated documentation` | `docs/verification/reference-baseline.json` | B1 is still described as `repository_bootstrap_pending`, while the canonical F-CI documentation binds B1.10. | VQ/reference governance | Reference registry content cannot exceed `NOT_ASSESSED` until corrected and independently checked. |
| DOC-Q01-D02 | `unresolved discrepancy` | Online visibility versus canonical publication | The Pages workflow deploys `main`; no release/documentation-baseline manifest binds the live site to an admitted scientific baseline. | DOC + release governance | No current page is promoted to `PUBLISHED_CANONICAL` by DOC-Q01. |
| DOC-Q01-D03 | `unresolved discrepancy` | Existing documentation provenance | Most pages do not carry exact source, theory and qualification references in a uniform form. | DOC + owning workstreams | Existing pages default to `NOT_ASSESSED`. |
| DOC-Q01-D04 | `unresolved discrepancy` | Scientific model, applicability, limitations, sensitivity and uncertainty documentation | Inventory finds no complete canonical sets for these areas. | Scientific governance / validation | Status A and AA documentation gates remain open. |
| DOC-Q01-D05 | `intentional historical difference` | Downstream F-KT, F-SI, F-MR, F-MQ and F-VQ documentation | These lines postdate the F-CI canonical baseline and have independent source/qualification provenance. | Respective workstreams + canonical integration | They may be inventoried or cited, but not silently treated as canonical source behaviour. |

These entries do not replace the existing theory-code discrepancy register. Model-level discrepancies continue there; DOC-Q01 records documentation-governance consequences and routes substantive issues to the responsible owner.
