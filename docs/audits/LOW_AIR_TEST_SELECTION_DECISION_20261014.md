# Decision: highest low-air stress is outside routine production admission

Decision owner: user / SWAP5 programme lead. Explicitly agreed on 14 October
2026, 14:52 Europe/Amsterdam, after reviewing the completed modular migration
pilot and the cost of the long qualifications. Canonical baseline:
`5f8933c900013bb597f7ce44e1305619c3f17cfd`.

## Binding decision

The long highest low-air qualification is retired as a **standard migration,
production admission and routine preservation gate**. A generic request to test,
a changed shared runtime dependency, or an older record calling this stress run
mandatory does not by itself select it. Apply this decision when reconciling older
owner clauses; it supersedes the earlier default minimum-boundary policy.

The programme does not currently accept that an extreme, long, fine-reference
trajectory adds necessary coverage for every new production component. That is a
selection decision, not a scientific proof that extreme conditions can never
expose an additional defect. No previously executed result is invalidated.

Keep the following required coverage:

| Subject | Required approach |
| --- | --- |
| Oxygen stress, uptake, drainage, thermal interaction and water balance | Fast physical tests with independent scientific oracles in the changed scope |
| Acceptance, rejection, retry, rollback, restart and invalid/extreme inputs | Small discriminating numerical/state/interface and physical integration tests |
| Very long trajectories, retry explosions and very fine reference loops | Separate explicitly selected numerical stress research |

A long highest low-air run is exceptional. Before selecting it, record a concrete
numerical research question or an essential identified risk, the unique failure
it can reveal, why existing fast tests leave that risk uncovered, why a smaller
discriminating test is insufficient, and expected compile/native/whole costs.
Module imports or an unknown dependency fingerprint alone do not establish that
unique scientific need. Unknown dependencies still require reconciliation and
relevant fast tests.

## Admission and honest status

Preserve physical oracles, numerical acceptance budgets, hard mass checks,
transactional ownership, fail-closed error handling and restart/coupling contracts.
No immutable reference, tolerance or production physics is changed by this decision.
An omitted stress run is recorded as `NOT_RUN_POLICY` or `NOT_SELECTED`, with this
selection authority. It must never be reported as a stress PASS, inherited
qualification, complete historical highest coverage or measured 10x speedup.

If an older guard still mechanically requires the long run, reconcile its owning
requirements to this decision and retained focused coverage. Do not falsify its
receipt, weaken an assertion, or launch the stress run solely to satisfy the old
administrative condition. An actual essential coverage gap remains an admission
condition until covered by an appropriate test. Prefer constructing a short
counterexample over repeating a long trajectory.

## Operational adoption

This commit records the policy in the execution protocol and agent entry point.
Production, testdrivers, CI triggers, preservation commands and evidence validators
are unchanged. Before invoking a compound runner, inspect whether it would start
this long stress route and select an appropriate governed route. The policy is not
a claim that existing automation has already been reconfigured.

Follow-up is a bounded coverage/owner reconciliation: identify any uniquely
covered failure and retain a small discriminating replacement where required;
reconcile obsolete highest-gate guards/triggers through their owner. No broad
solver audit, new full stress matrix or repeated qualification is selected by
this documentation decision. Other preservation tests require their own impact
and cost justification; the measured 30.8-minute full F-CI batch is not the same
test as the highest low-air trajectory.
