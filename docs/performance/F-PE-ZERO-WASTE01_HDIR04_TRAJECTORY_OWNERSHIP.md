# F-PE-ZERO-WASTE01 H-DIR04 — consuming trajectory vector ownership

Date: 2026-09-25

Status: `CANDIDATE_PENDING_QUALIFICATION`

Authority parent: `f3c8e1642310f7303802e23f187d1f4981e39539`.

## Measured waste

For every available accepted directional step the current trajectory path materializes two outgoing N-vectors, copies them into pending vectors, copies pending vectors into current trajectory state, then immediately deallocates pending.

Shared-CI component measurements:

| N | pending alloc+copy+dealloc | second two-vector copy | four move_alloc transfers |
|---:|---:|---:|---:|
| 60 | 31.40 ns | 13.39 ns | 1.93 ns |
| 200 | 73.82 ns | 35.89 ns | 1.86 ns |
| 1000 | 243.76 ns | 184.60 ns | 1.87 ns |

## Candidate

The existing copy-stage API is retained unchanged.

A new consuming stage is used only by the serialized backend. It applies the same token, duration, availability, allocation, shape and finiteness checks. Only after all checks pass are the result h/theta arrays moved into pending ownership.

At accepted-step commit, pending h/theta ownership is moved into current trajectory state. Pending state is then cleared exactly as before.

Incoming request vectors and final trajectory publication are deliberately unchanged in this tranche.

## Safety contract

- malformed or stale results fail before ownership transfer;
- generic copy-stage still leaves result arrays allocated;
- consuming stage leaves result arrays unallocated only after successful validation and transfer;
- rejected/discarded pending state remains fail-closed;
- trajectory values, provenance, counters and accepted backsolve semantics remain identical;
- no physics, mass, transaction acceptance or tangent equation changes.

## Qualification

- direct O0/O2 contract test for copy and consuming APIs;
- exact physical/provenance FKT22 gates through current CI;
- isolated directional paired runtime against exact parent with baseline sensitivity/service/backend frozen;
- broad paired runtime and HDIR03A preservation.
