# F-AHL49 — immutable direct-retention ownership and bind qualification

Date: 2026-09-25

Status: `PREREGISTERED_OWNERSHIP_SCREEN`

Parent: F-AHL48, resolution frozen at 64 intervals per decade.

## Question

Can the qualified direct-retention representation be shared per exact hydraulic authority without reintroducing hot-path registry overhead or per-column table duplication?

## Architecture under test

- exact-key lookup occurs only during provider bind;
- table construction occurs only on a genuine key miss;
- one immutable theta/C table is owned per unique homogeneous hydraulic authority;
- a bound provider stores direct pointers to the immutable theta/C arrays;
- candidate evaluation uses only those direct pointers plus direct decade/index arithmetic;
- no cache search, hashing, registry method call or table copy occurs inside `evaluate_demand()`.

Resolution is fixed at 64 intervals per decade.

## Key authority

For this screen an authority key is exact bitwise identity of the initialized first-node 42-coefficient hydraulic authority plus the KSATEXM extension flag.

Homogeneous profiles only. Layered profiles remain unsupported and must fail closed.

## Gates

1. First bind of authority A builds exactly one table.
2. Second and later binds of authority A are hits and do not build or duplicate table storage.
3. Authority B creates exactly one additional table.
4. Providers bound to the same authority point to the same immutable theta/C storage.
5. Provider demand values are bit-identical regardless of first-build or cache-hit bind.
6. Hot-path timing of shared immutable provider is not materially worse than F-AHL47 provider-local direct indexing.
7. Table build/bind timing is reported separately from solve-time demand.
8. No production routing change.

## Concurrency boundary

The owner is mutable during serial bind/build and immutable for already-built entries. No parallel mutation/thread-safety claim is made. Any future parallel worker admission requires a separate qualification.
