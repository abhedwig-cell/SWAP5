# F-MIG431-01 functional closure program

Date: 2026-10-01

## Purpose

F-MIG431-01 is the central accounting and routing work unit for functional migration from SWAP 4.3.1 to SWAP5. It does not own production physics.

The closure question is not whether every legacy Fortran file has been rewritten. The question is whether every scientifically or functionally relevant legacy capability has an explicit SWAP5 disposition and evidence trail.

The machine-readable authority for this program is:

`integration/control/F_MIG431_FUNCTIONAL_CLOSURE.json`

## Baseline

Initial canonical preimage:

`integration/f-ci-canonical@8bb835a065248aad06b18a3b563234b20033ba0d`

The D3c legacy migration inventory already censused all 63 supplied SWAP 4.3.1 `.f90` files. Those historical maps are used as inventory locators only. Current implementation/admission claims are reconciled against current canonical Status-A, post-Status-A and capability-specific evidence.

## Closure criterion

Functional closure requires:

1. every identified legacy capability is classified;
2. every capability has exactly one disposition: preserve, migrate, replace, retire, or investigate;
3. every open capability has one owning workstream;
4. shared semantics have one canonical owner;
5. all completed capabilities are supported by qualification/admission evidence appropriate to their claimed envelope;
6. no capability remains `UNCLASSIFIED`.

A file can contribute to several capabilities. File-level coverage is therefore necessary for source archaeology but insufficient for functional closure.

## Parallel development rule

The controlling rule is:

`parallel where ownership is disjoint; serial where semantics are shared`

Capability work branches start from a pinned canonical commit. They do not branch from or merge other active capability branches.

A specialized workstream may research, implement, test and qualify within its declared owned surface. It may not silently widen a shared interface or ownership contract.

If a capability needs a shared semantic change, that change is split into a bounded prerequisite work unit, admitted centrally, and only then consumed by dependent workstreams.

## Shared surfaces

Treat at least these as integration-controlled:

- committed/candidate state;
- transaction executor;
- Richards solver interface;
- hydraulic constitutive interface;
- top and bottom boundary contracts;
- root-water sink ownership;
- mass ledger;
- timestep policy;
- restart schema;
- FMR ABI;
- external coupling ownership.

## Initial routing

Existing active work is inherited rather than restarted:

- macropore migration remains with the PPA-WU05-A successor chain;
- oxygen migration remains with the PPA-WU05-C successor chain.

The next independent legacy families visible from current authority are frost hydraulics and compensated root uptake. Salinity is held behind a typed solute owner. SWKIMPL=1 dynamic root-sink reevaluation is held behind a separate nonlinear solver/sensitivity authority.

Surface/atmosphere/irrigation/runon, tillage/management and WOFOST soil/nutrient functionality require census before a production work branch is opened.

## Execution economy

Use local builds, source extraction and numerical experiments for development whenever possible. GitHub Actions is reserved for gates where durable remote evidence matters, such as qualification, canonical admission, moving-current preservation or release evidence.

## Recovery

Work unit: `F-MIG431-01`

Branch: `regie/f-mig431-01-functional-closure`

Initial checkpoint: registry commit following this document's predecessor commit.

Next safe action: expand the 63-file source inventory to an option/subroutine-level functional census and reconcile those capabilities against current canonical evidence.

No production or reference source mutation is authorized by this work unit.
