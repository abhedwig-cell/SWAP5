# ADR-0003: Worker-owned scratch

**Status:** Accepted  
**Date:** 2026-09-04  
**Affected invariants:** 3, 4, 5, 6, 16, 27

## Context

A large MultiSWAP execution may contain hundreds of thousands of logical columns. Storing Newton vectors, Jacobians and other solver intermediates permanently per column would multiply memory use by the number of columns even though only a limited number of columns are solved concurrently.

Temporary numerical data also has a different lifetime and meaning from physical state.

## Decision

Persistent column state contains only data required to continue the physical model.

Temporary solver data belongs to an execution worker or compute job. Scratch storage can be allocated once per worker and reused for successive columns with compatible execution templates.

Optional physical modules allocate persistent state only when active.

## Consequences

Positive consequences:

- memory scales with active workers rather than logical column count for heavy solver scratch;
- scratch allocation can be reused;
- physical rollback becomes smaller and clearer;
- the storage backend can use pools, structures of arrays or batches.

Costs and constraints:

- solver calls must receive or acquire explicit scratch;
- hidden aliases from persistent state into scratch are not allowed;
- concurrent execution requires clear worker ownership.

## Verification implications

Scratch reuse must not make results depend on which column was executed previously by a worker. Tests should poison or randomize scratch where practical to detect accidental reliance on stale values.
