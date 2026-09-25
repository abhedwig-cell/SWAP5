# F-AHL49 — production-shaped direct-retention extraction and application qualification

Date: 2026-09-25

Status: `PREREGISTERED_PRODUCTION_SHAPED_EXTRACTION`

Parent authority: F-AHL48 closed shared immutable ownership, resolution 128 intervals per decade.

## Question

Can the F-AHL48 shared direct-retention architecture be extracted into production modules and wired into the current serialized Reference application without reintroducing per-trial authority lookup, changing default behavior, or broadening the qualified physics envelope?

## Frozen architecture

Representation:

- 128 intervals per decade over |h| = 1..1e6 cm;
- direct decade selection and direct interval arithmetic;
- cubic Hermite theta representation;
- C is the exact derivative of the same interpolant;
- full hydraulics and K remain analytical;
- analytical fallback outside the represented domain.

Ownership:

- one immutable theta/C table per exact homogeneous hydraulic authority;
- exact-key acquire/build occurs during parameter preprocessing;
- persistent physical parameters store the acquired integer representation slot;
- solve-time provider bind receives that slot directly and performs no key lookup;
- application bootstrap freezes the pool before execution starts.

## Initial admitted candidate envelope

Opt-in only, default OFF.

Required for direct-retention routing:

- default B1.10 MvG authority;
- hydraulically homogeneous active profile;
- prescribed-head bottom mode 5;
- explicit conductivity, SWKIMPL = 0;
- no tabulated hydraulics;
- no hysteresis;
- no KSATEXM composition in this first extraction.

Explicitly excluded pending separate qualification:

- prescribed qbot;
- layered/heterogeneous hydraulic authorities;
- SWKIMPL=1;
- KSATEXM composition;
- default-on behavior;
- replacement of analytical K;
- practical/approximate tolerance changes.

## Gates

1. Production provider extraction reproduces F-AHL48 direct theta/C demand values.
2. Same-authority setup builds once and stores/reuses one slot.
3. Trial-time bind performs no exact-key search/build.
4. Default-off Reference route is unchanged.
5. Unsupported opt-in compositions fail closed or retain explicitly qualified analytical fallback.
6. B01/B12/O05/O14 × wet/mid/dry prescribed-head matrix retains identical nonlinear iteration and backtracking counts.
7. Current-postimage paired timing remains materially positive.
8. Production application initialization at N=1/100/1000/10000 reports setup/build cost separately.
9. Large-N table memory scales with unique authorities, not columns.
10. No canonical admission until all production-shaped gates pass.

## Concurrency and application-owner boundary

Supported candidate lifecycle:

`single application owner -> serial setup/build -> freeze -> immutable reads -> owner close`

F-AHL48 qualified concurrent frozen reads. F-AHL49 does not admit concurrent pool mutation.

The first production-shaped extraction also admits at most **one active direct-retention production application owner at a time**. A second opt-in application initialization while the first owner is alive must fail closed. Closing the first owner releases and resets the representation pool so a later owner can initialize safely.

This singleton-owner boundary is deliberate for the first extraction. Multi-application shared ownership is a separate future qualification and must not be inferred from the frozen-read result.

## Decision boundary

This workunit may create a production-shaped opt-in candidate.

It must not enable the feature by default or claim canonical admission merely from source extraction.
