# F-PE-ZERO-WASTE01 H22A — trusted immutable prepared-parameter binding

Date: 2026-09-25

Status: `CANDIDATE_PENDING_QUALIFICATION`

## Authority and motivation

Production bootstrap owns `parameters(:)` privately. The array is populated once during bootstrap initialization, thereafter exposed only through read-only participant bindings, and released at close.

On the current exact prepared-hydraulics path, every interval still performs an O(24*N) equality scan between raw `cofgen` and the prepared 42-row MvG representation before copying prepared hydraulics into backend-owned storage.

Shared-runner observation for N=60:

- full MvG preprocessing: about 5.14 microseconds/call;
- exact prepared/raw compatibility scan: about 1.09 microseconds/call;
- prepared copy with reused capacity: about 0.99 microseconds/call;
- geometry copy: about 0.058 microseconds/call.

The timings are not portable claims. The repeated scan is exact work whose necessity depends on whether the caller can prove parameter immutability.

## H22A contract

Generic callers remain untrusted by default.

An owner may explicitly assert trusted prepared parameters only when it guarantees that the parameter object and its raw hydraulic dependencies are immutable for the relevant owner lifetime.

The current production bootstrap satisfies that contract:

- owner storage is private;
- values are copied from typed config once during `initialize`;
- prepared MvG state is created once;
- no mutation method exists after initialization;
- groundwater registry keeps only `intent(in)` parameter associations;
- storage is released only during close/discard.

## Candidate behavior

Trusted mode still checks:

- prepared representation is available;
- raw and prepared matrices are allocated;
- active node counts agree;
- raw matrix has at least 24 rows;
- prepared matrix is exactly 42 rows by N;
- KSATEXM extension flags agree.

Trusted mode skips only the full raw/prepared equality scan.

The prepared 42-row representation is still copied into backend-owned storage. H22A introduces no pointer aliasing and no borrowed prepared-state lifetime.

Untrusted mode retains the exact current compatibility scan. If raw parameters changed after preparation, it falls back to fresh preprocessing exactly as before.

Trust is passed explicitly through:

- production standalone serialized MultiSWAP dispatch;
- groundwater participant registry and participant trial path.

The backend resets trust on every trial and enables it only immediately around the kernel trial call.

## Gates

1. FKT22 trusted versus untrusted route produces bit-identical physical state and mass.
2. FKT22 stale prepared cache plus mutated raw coefficients on the untrusted route matches a freshly prepared mutation.
3. PPA-WU01 production bootstrap PASS.
4. F-GC49D production application context PASS.
5. Existing generic callers require no new argument and remain untrusted.
6. Existing poison, capture, PROFILE01 and paired runtime gates remain authoritative.
7. No physics, tolerance, transaction, accepted-state or provider-formula change.

## Boundary

H22A removes only compatibility scanning under an explicit owner immutability contract.

Avoiding the prepared-array copy is a separate H22B question and requires stronger lifetime/ownership evidence.
