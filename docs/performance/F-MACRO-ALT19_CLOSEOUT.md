# F-MACRO-ALT19 — GFZ payload acquisition closeout

Date: 2026-10-01

Status: `CLOSED_WITH_DATA_TRANSPORT_BLOCKER / SCIENCE_CONTINUES_FROM_PUBLISHED_NUMERICAL_EVIDENCE`

## Acquisition attempt

A final targeted acquisition attempt was made for:

```text
10.5880/GFZ.4.4.2024.001
```

The public GFZ services expose:

- dataset metadata;
- data description;
- exact file inventory;
- publication-level references.

The archive is documented as a zipped folder named:

```text
2024-001_Hartmann-et-al_Data
```

but no individual-file/archive payload route accessible through the current execution environment could be materialized.

The inferred direct ZIP/file URLs are not exposed as accessible resources in the available web/download path.

## Decision

Do not spend further research cycles reverse-engineering the transport layer.

This is formally closed as:

```text
GFZ_PAYLOAD_ACCESS = TOOLING/TRANSPORT BLOCKER
GFZ_DATASET_SCIENTIFIC_SUITABILITY = CONFIRMED
GFZ_SCHEMA/PARSER = READY
```

The research line proceeds using numerical data published in the open HESS article and appendix until the raw archive can be materialized through another route.
