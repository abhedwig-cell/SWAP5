# PPA-WU05-A24 preregistration — RFM/Richards transactional split binding

Date: 2026-10-01
Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS
Baseline: integration/f-ci-canonical@0bf4bc0aec1d1f5d157ba6b4a88f0117c854bf6b

## Purpose
Bind accepted-state RFM internal matrix transfers to the existing Richards source/sink ABI without changing that ABI or mutating accepted state.

## Numerical composition
A24 is an explicit first-order operator split for the bounded RFM route:

1. derive RFM activation/hydraulics/fates from accepted state;
2. freeze endpoint + MB wall-to-matrix transfers for the trial interval;
3. convert each transfer depth to a node volumetric source rate using the owning node thickness and dt;
4. wrap the existing source_sink_provider_t;
5. Richards solves the candidate with A16 matrix surface share plus the additional frozen RFM node sources;
6. reject/discard publishes nothing; retry recomputes from the same accepted origin.

This is not claimed as a monolithic nonlinear RFM/Richards solve.

## Source provider contract
The wrapper must:
- preserve every base source and sink exactly;
- add only caller-supplied nonnegative RFM node source rates;
- own no root/drainage semantics;
- be deterministic and state-read-only;
- fail closed on shape/nonfinite/negative RFM sources.

## Mass mapping
For node i with thickness dz_i and interval dt:

    rfm_source_rate_i [1/day] = transfer_depth_i / (dz_i * dt)

so:

    sum_i(rfm_source_rate_i * dz_i * dt)
      = IC endpoint-to-matrix + MB wall-to-matrix.

## Qualification gates
- executable wrapper oracle preserving base source/sink;
- exact integrated RFM source recovery;
- zero-RFM identity;
- deterministic replay;
- invalid source fails closed at bind;
- then a real B1.10/Richards fixture using the wrapper.

The A20 live runtime guard is not removed in A24.
