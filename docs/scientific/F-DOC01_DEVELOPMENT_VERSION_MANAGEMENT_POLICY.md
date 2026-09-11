# F-DOC01 development and version-management policy

Scientific documentation changes with the model and is part of release governance.

## Required development objects

- development roadmap with scientific and technical gaps;
- known limitations and technical debt;
- version/release history;
- release acceptance criteria;
- migration/deprecation notes;
- change rationale and affected scientific IDs;
- planned sensitivity/uncertainty/validation updates.

## Scientific change chain

Every significant scientific change records:

`old theory/implementation → discrepancy or decision → new theory/formulation → new implementation mapping → verification/validation impact → qualification → release authority`.

A refactor that claims no scientific change records the preserved contract/equation IDs and the verification that supports that claim.

## Version binding

Documentation records distinguish stable identity from release mapping. Evidence remains pinned to the exact source it qualified. Moving-current documentation may say what is current, but it may not rewrite historical qualification scope.

## Release gate

A release-impacting scientific change cannot close with documentation saying `TBD` for a changed equation, parameter meaning, implementation mapping or evidence authority. If the evidence is intentionally deferred, the capability/release scope must expose the nonclaim.

## External criteria

A change in the WUR Status A/AA framework is treated as a versioned external dependency. Criterion migration and evidence impact are assessed before new compliance/readiness language is used.
