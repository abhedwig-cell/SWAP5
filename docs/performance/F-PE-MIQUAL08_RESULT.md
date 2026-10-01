# F-PE-MIQUAL08 result — serialized dynamic reference-workload acquisition

Date: 2026-10-01

Status:

`MIQUAL08_NO_EXISTING_DYNAMIC_REFERENCE_IN_MANAGER_ENVELOPE`

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

## Audit result

No existing repository-backed dynamic serialized-reference fixture was found that simultaneously satisfies the frozen MIQUAL06 manager envelope.

The main candidate families fail for distinct, already-documented reasons.

### FKT22 serialized trajectory runtime

Uses accepted-trajectory direction publication.

This is explicitly outside MIQUAL06 manager eligibility.

Its physical fixture is also equilibrium rather than the required dynamic benchmark.

### FMR44R prescribed-qbot serialized runtime

Contains a valid dynamic positive-qbot case, but:

- bottom mode is prescribed flux;
- bottom flux is non-zero;
- the dynamic accepted case uses temporal-history/model-certificate continuation.

Both qbot!=0 and temporal history are outside MIQUAL06.

### FGC real-FMR participant / prescribed-qbot application families

Use groundwater/prescribed-qbot coupling and model-certificate temporal continuation.

These are outside the current manager envelope.

### FMR23 reference ET runtime

Uses reference evapotranspiration/root-process runtime binding.

This is outside the zero-source/sink, no-root-extraction MIQUAL06 scope.

### BOFEK wet/adaptive trajectory fixtures

These contain valuable dynamic qbot=0 physics, including wetting/ponding/runoff in some fixtures, but they are lower-level solver trajectory tests rather than serialized-reference transaction workloads.

The dynamic-top variants are also outside the current explicit-fixed-flux MIQUAL06 runtime envelope.

### Performance workload catalog

No existing workload entry supplies a ready serialized dynamic qbot=0 basic-Richards transaction fixture within the MIQUAL06 envelope.

Several workload families are explicitly marked runtime-/template-/policy-blocked or require additional process semantics.

## Conclusion

The repository currently contains:

- valid serialized equilibrium workloads inside MIQUAL06;
- valid serialized dynamic workloads outside MIQUAL06;
- valid lower-level dynamic qbot=0 solver trajectories;
- but no already-qualified serialized dynamic qbot=0 basic-Richards workload inside MIQUAL06.

Therefore the frozen classification is:

`MIQUAL08_NO_EXISTING_DYNAMIC_REFERENCE_IN_MANAGER_ENVELOPE`.

This is not a manager failure and not a repository defect. It is a gap in benchmark coverage.

## Consequence

Two successors are justified without reopening manager physics:

1. a robust paired equilibrium serialized benchmark using the already valid MIQUAL07 W0 workload;
2. a separately preregistered transaction-compatible dynamic reference derivation from existing lower-level qualified physics.

The first can answer whether the manager gain survives full serialized transaction/runtime overhead. The second is required before any broad dynamic production-speed claim.

## Production boundary

No production change.

`LEGACY_NUMERICS` remains production default.
