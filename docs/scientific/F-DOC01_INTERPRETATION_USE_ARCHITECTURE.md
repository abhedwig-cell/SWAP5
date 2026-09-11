# F-DOC01 interpretation and use architecture

User-facing documentation is generated from the same scientific records as technical documentation, but presents different views.

## Required interpretation content

For each release/application class the user must be able to determine:

- what an output physically represents, including sign/unit/time and spatial support;
- intended and unsupported uses;
- assumptions and simplifications that materially affect interpretation;
- active/inactive physical processes;
- parameter/input provenance relevant to the result;
- numerical policy used, including relaxed/fallback modes where applicable;
- diagnostics and water-balance meaning;
- validation and uncertainty coverage;
- known limitations/nonclaims;
- exact release/source authority.

## Publication views

The repository source can generate an online technical manual, theory manual, numerical-methods report, developer/API documentation, V&V report, Status A/AA dossier, user manual and release qualification report. These are views, not independent truth stores.

## Troubleshooting and diagnostics

Troubleshooting must distinguish invalid input, unsupported application, physical option mismatch, nonconvergence/retry/fallback, coupling residual issues and mass-balance failure. Numerical fallback cannot be hidden as normal execution. MultiSWAP interpretation must preserve per-column/per-interval execution-class diagnostics where qualification requires it.

## I/O boundary

User manuals may document legacy `.swp` adapters and preparation workflows in detail. They must not imply that file semantics are kernel contracts. Kernel quantities are referenced by stable scientific/contract IDs.
