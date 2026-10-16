# F-PE-TIMEARCH05 result — retry ownership reconciliation

Date: 2026-09-28

Status: `QUALIFIED_RETRY_OWNERSHIP_HIERARCHY`

Canonical authority:

`integration/f-ci-canonical@c18325bf110032cf323fad08bb7ddb52204b1d76`

Primary evidence:

- Actions run: `36422411937`;
- job: `108928103309`;
- source guard: PASS;
- O0: PASS;
- O2: PASS;
- O0/O2 identity: PASS.

## Executable ownership matrix

### LOCAL_INTERNAL_SUCCESS

- outer transaction attempts: 1;
- outer retries: 0;
- internal retries: 2;
- total work: 16;
- accepted work: 16.

Interpretation:

Local solver recovery can succeed entirely inside one physical trial. It is not an outer transaction retry.

### TERMINAL_SOLVER_ESCALATION

- outer attempts: 2;
- outer retries: 1;
- solver rejections: 1;
- total internal retries: 4;
- accepted internal retries: 1;
- total work: 58;
- accepted work: 16;
- discarded work: 42.

Interpretation:

Legacy/internal recovery and transaction retry are nested.

They are not semantically duplicate:

- internal retry owns recovery within one requested physical interval;
- transaction retry owns failure after the local recovery envelope is exhausted.

However the nesting can create substantial re-execution cost.

### TEMPORAL_REJECTION

- outer attempts: 2;
- outer retries: 1;
- temporal rejections: 1;
- solver rejections: 0;
- internal retries: 2;
- accepted internal retries: 1;
- total work: 32;
- accepted work: 16;
- discarded work: 16.

Interpretation:

Temporal retry is a separate acceptance concern. The physical solve has converged; publication is withheld because temporal acceptance rejects the interval.

## Coupling retry ownership

Source authority confirms whole-window/coupling retry remains above the SWAP numerical trial:

- all participant candidates are discarded before retry;
- retry starts from the same accepted physical origin;
- a fresh smaller coupling window/runtime identity is created;
- this is not represented as a Richards internal retry.

## Qualified hierarchy

The explicit ownership hierarchy is:

1. **TrialExecutor local recovery**
   - local/alternative solver recovery;
   - legacy internal dt reduction while the requested trial remains locally recoverable.

2. **Transaction RetryController**
   - terminal solver rejection;
   - mass rejection;
   - temporal rejection;
   - rollback to committed origin before retry.

3. **Coupling WindowController**
   - whole-window/preflight rejection across participants;
   - discard all candidates;
   - retry the coupled window from the accepted origin.

4. **StepProposalController**
   - updated only after accepted commit;
   - rejected attempts must not alter accepted-step proposal history.

## Architectural consequence

The redesign should not collapse all retries into one undifferentiated retry loop.

Instead it should preserve the semantic layers while making re-execution cost and reason provenance explicit.

A future optimization may reduce duplicated work between layers, but only after preserving these ownership boundaries.

## Decision

Final classification:

`QUALIFIED_RETRY_OWNERSHIP_HIERARCHY`

No production source change in TIMEARCH05.
