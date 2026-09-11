# F-DOC01 ownership and maintenance schema

Architecture ownership and organisational Status A/AA ownership are related but not identical. F-DOC01 defines the schema and does not invent people.

## Required roles

- `scientific_owner`
- `software_owner`
- `release_authority`
- `maintenance_owner`
- `external_dependency_owner`
- `user_support_owner`
- `next_in_line_or_successor`
- `documentation_owner`
- `quality_audit_contact`

A role may be assigned to an organisational unit instead of a named individual when that is the maintained authority. Unknown assignments are `GAP`, not placeholder names.

## Maintenance record

Each maintained capability/model record includes ownership, support scope, update/review cadence, funding/continuity status where required, critical dependencies, succession coverage, release responsibility, documentation authority, qualification authority and escalation path.

## Separation from runtime ownership

Runtime ownership such as `committed state belongs to column` or `scratch belongs to worker` is a software contract at T9. Organisational ownership such as scientific maintainer belongs to this management schema. The two must not be conflated.

## AA readiness

The schema has slots for future-use/development vision, continuity threats/opportunities, periodic management review, dependency obligations/liabilities and external-use agreement authority. Empty slots remain explicit AA gaps until supported by organisational evidence.
