# PPA-WU05-A18 result — solver-stable perched authority and active inner exchange

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_PERCHED_AUTHORITY_AND_ACTIVE_INNER_RESEARCH_RESULT`

Canonical reconciliation:
`integration/f-ci-canonical@03708d387f452e82044cffbff681da8252d3e717`.

Research branch:
`research/ppa-wu05-a18-perched-authority-fixture@5434665c34cff570066ccd2d76e10a092f7979d7`.

## Decision

`QUALIFIED_SOLVER_STABLE_PERCHED_AUTHORITY_FIXTURE`

and

`QUALIFIED_ACTIVE_PERCHED_INNER_EXCHANGE_REQUIRES_SOURCE_REDUCTION_STATE_MACHINE_FOR_PRODUCTION`.

## G1 — exact runtime recovery

PASS.

Exact SWAP 4.3.1 was rebuilt locally from the supplied source archive. Bundled TTUTIL was
rebuilt from source with gfortran because the distributed static library depends on Intel
runtime symbols.

The official Andelst macropore case runs normally.

## G2 — shipped-case census

PASS with negative result.

The unmodified Andelst case has no distinct perched body. Its apparent perched indices
coincide with the ordinary groundwater carrier.

This negative finding prevents false qualification from `NPeGwl > 0` alone.

## G3 — source-backed perched variant

PASS.

A distinct perched state was generated dynamically by exact 4.3.1 Reference Richards from
the official Andelst soil/profile under source-native irrigation forcing, with macropore
exchange disabled during preconditioning.

The perched body persists over multiple accepted intervals.

An accepted 05:59 snapshot was captured with:

- perched top node 1;
- perched bottom node 29;
- main groundwater node 56;
- perched level approximately +0.6303 cm;
- ordinary groundwater approximately -79.57 cm.

## G4 — independent SWAP5 Reference baseline

PASS.

Run `36859002384`:

- exact snapshot translated to 112-node SWAP5 fixture;
- Reference Richards converged;
- 3 nonlinear iterations;
- 0 retries;
- mass residual approximately `-1.85e-10 cm`;
- perched topology retained;
- O0/O2 identical.

This is the first independently qualified solver-stable perched Reference fixture in the
current macropore modernization line.

## G5 — A17 inner callback replay

Research-level PASS with an explicit source dependency.

At unreduced exchange `FrReduQ=1`, the inner solve requests retry.

The exact next B1.11 reduction level, `FrReduQ=0.1`, converges.

Run `36860834649` proves:

- active inner-Richards macropore path;
- nonzero perched matrix-to-macropore exchange;
- final exchange `-0.25748894374328285 cm/d`;
- macropore storage gain `5.149778874865657e-4 cm`;
- internal exchange residual exactly 0;
- macropore balance residual exactly 0;
- O0/O2 identity.

## New production dependency

A17 currently expects the caller/configuration to provide a fixed `flow_reduction`.

Exact 4.3.1 owns a bounded retry state machine:

`IDecMpRat = 0..3`

with:

`FrReduQ = [1, 0.1, 0.01, 0.001]`.

A18 proves that this is not incidental legacy machinery. The source-backed perched case
requires the first reduction level to converge.

Production admission must therefore not hardcode `0.1`.

The source retry ladder must be represented explicitly as numerical/trial policy:

- recomputable per trial;
- no committed physical-state mutation on rejected attempts;
- reset/recovery semantics source-mapped;
- restart semantics explicit;
- default outer A8-A10 path unchanged.

## Production admission

A18 is not itself a production-admission candidate.

It closes the hydraulic-authority blocker and identifies the final missing production
mechanism for active perched execution.

## Governance namespace collision

During A18, canonical moved from `ebea5880...` to `03708d38...`.

That canonical delta admitted a parallel RFM workunit using the identifier
`PPA-WU05-A11` and the same generic A11 documentation/status paths previously used by
this pre-canonical perched research line.

The RFM canonical authority wins.

Therefore the historical perched A11-A18 documents on this research ancestry must **not**
be merged wholesale into canonical.

Future perched workunits use a distinct `PPA-WU05-PERCH*` namespace, and any eventual
admission branch must be reconstructed from current canonical with only the required
code/evidence carried forward.

## Next safe step

Open:

`PPA-WU05-PERCH19 — source-faithful FrReduQ retry ladder`.

Its target is an explicit trial-local numerical state machine implementing the exact
factor ladder while preserving:

- rejected-trial isolation;
- accepted seven-field state ownership;
- restart;
- A8-A10 default route;
- A16/A17 inner callback behavior.

After PERCH19 qualifies on the A18 source-backed perched fixture, reopen production
admission.
