# F-PE-TEMPORAL09 result — production temporal-history service decomposition

Date: 2026-09-28

Status: `CLOSED_WITH_MATERIAL_CONSTITUTIVE_TARGET`

PR:
`#695 — F-PE-TEMPORAL09: qualification evidence`

Workflow run:
`36355382511`

Measured head:
`fc024bae1dc41c46427d59419c4f906ecad77905`

## Result

The temporal-history service is dominated by constitutive reevaluation.

At N=40,000, worker=4:
- temporal service: 0.419104478 s;
- constitutive reevaluation: 0.222603076 s, 53.11%;
- operator assembly: 0.044248006 s, 10.56%;
- additional tridiagonal solve: 0.012277438 s, 2.93%;
- pre-indicator history preparation: 4.16%;
- post-indicator history/publication: 4.35%;
- remaining indicator work: 10.76%.

The same distribution is stable at N=1,000 and N=10,000.

Parent PHYS01 measured the complete temporal service at about 23-24% of backend critical-path time. The constitutive component therefore owns roughly 12% of total backend critical-path time at representative large N.

## Code interpretation

The current temporal indicator performs two full constitutive evaluations:
- base state: water content, conductivity, capacity and dK/dh;
- candidate state: water content, conductivity, capacity and dK/dh.

The certificate actually consumes only:
- base-state conductivity;
- candidate-state water content for consistency validation;
- candidate-state capacity for mass weighting.

The B1.10 default MvG provider already exposes demand-directed constitutive evaluation. The direct-retention provider preserves its specialized water-content and capacity semantics when those quantities are requested separately.

## Decision

Advance a bounded demand-directed constitutive repair.

The repair must request only:
- base conductivity;
- candidate water content;
- candidate capacity.

For direct-retention, candidate water content and capacity must remain separate demand calls so the direct-retention table semantics are preserved. Generic provider fallback remains fail-safe through the existing full-evaluation fallback.

No workspace-state reuse or relaxed certificate semantics is authorized.

No production source change was made by TEMPORAL09 itself.
