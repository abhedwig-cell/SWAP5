# Workstream execution and recovery protocol

## Purpose

Long-running development, verification and qualification work must remain recoverable when a tool, test runner, chat session or execution environment stops unexpectedly. Git is the durable system of record. Chat reasoning, an uncommitted worktree and transient tool state are not recovery points.

The governing rule is:

```text
persist early, test second
```

This protocol applies to all SWAP5 workstreams and work units, including F-CI and F-MQ.

## Required state model

A work unit must distinguish these states explicitly:

- **implemented**: the intended change exists in a working tree or generated artifact;
- **persisted**: the recoverable postimage and its status metadata are committed to Git;
- **tested**: the declared focused checks have completed successfully against that persisted postimage;
- **qualified**: all gates required for admission of the work unit have completed successfully and their evidence is versioned;
- **blocked**: the next required action cannot currently be completed and the dependency is recorded.

These states are not interchangeable. In particular, a checkpoint commit is not evidence that a change is tested or qualified.

## Mandatory checkpoint before timeout-sensitive work

Before starting a timeout-sensitive or otherwise expensive operation, the preceding useful work must already be recoverable from Git.

Examples include:

- full or broad compilation runs;
- regression suites;
- long SWAP reference runs;
- MultiSWAP scale, concurrency or isolation tests;
- performance benchmarks;
- large repository-wide analyses or transformations;
- any operation whose interruption would otherwise require reconstructing non-trivial work.

A checkpoint must contain, directly or through versioned work-unit metadata:

```text
WORKSTREAM
WORK UNIT
BASELINE
CHECKPOINT COMMIT
FILES / ARTIFACTS PERSISTED
IMPLEMENTATION STATUS
TEST STATUS
QUALIFICATION STATUS
NEXT EXPENSIVE ACTION
RECOVERY POINT
DEPENDENCIES / BLOCKERS
```

The checkpoint commit may be temporary in the eventual history. It must nevertheless be complete enough to resume safely.

## Lightweight checks before a checkpoint

Short structural checks may run before the checkpoint when they are cheap and reduce the risk of persisting a trivially broken postimage. Examples are syntax checks, schema validation or a small focused unit test.

They do not replace the checkpoint. Long or broad gates run only after the useful postimage has been persisted.

## Checkpointing is not a stop condition

A checkpoint is a **recovery boundary**, not a default execution endpoint. Persisting a meaningful state does not require a new user instruction before work continues.

The operational rule is:

```text
persist frequently, stop rarely
```

After a checkpoint has been persisted, continue automatically with the next permitted phase while execution remains healthy and the next action is authorized and safe. A normal uninterrupted run may therefore cross several phases, for example:

```text
RECONCILE -> checkpoint -> IMPLEMENT -> checkpoint -> focused tests -> checkpoint -> QUALIFY -> CLOSE
```

Do not deliberately fragment work into one-tool-call or one-file steps merely to create more checkpoints. Reading a file, locating a symbol, running one trivial command, or completing another transient action is not by itself a useful stopping boundary.

Prefer checkpoints at **meaningful state boundaries**, such as:

- authority and relevant live state are sufficiently reconciled to resume implementation without reconstructing prior analysis;
- one atomic implementation decision has been persisted;
- a coherent focused test group has completed and its evidence is durable;
- a qualification, admission or blocking decision has been reached and recorded.

Stop after a checkpoint only when at least one of the following applies:

- a real scientific, architectural, governance or dependency blocker has been reached;
- the next action is not authorized by the current work-unit scope;
- all applicable execution and repository-access alternatives have been tried or ruled out, and a concrete external tool/environment blocker prevents safe continuation;
- the remaining runtime appears insufficient to start the next expensive operation safely;
- the user explicitly requested a stop or review boundary.

When runtime exhaustion appears plausible, prefer an early durable checkpoint and concrete recovery handoff over starting another long or fragile tool chain. This is a runtime-safety decision, not a reason to make the scientific work unit artificially smaller.

## Remote persistence

When work is being performed in a local or disposable environment, a local commit alone is not the strongest recovery boundary. Before a costly operation, the checkpoint should also be pushed to the workstream branch unless there is a documented reason not to do so.

For work performed directly through the GitHub repository interface, a successful repository commit already provides remote persistence.

## Work-unit status record

Material work units should maintain a versioned status record close to their other integration or qualification artifacts. Existing workstreams may keep their current naming convention, for example:

```text
integration/f-ci/F-CI07_STATUS.json
integration/f-mq/F-MQ01_STATUS.json
```

Where a workstream already has a deterministic `<WORK_UNIT>_STATUS.json` convention, keep using it. Do not create a separate repository-wide agent index merely to make discovery easier; that would become a second, easily stale source of project state.

The exact serialization may differ, but the record must make the recovery boundary unambiguous. At minimum it must state:

```text
work_unit
baseline
checkpoint_commit
implemented
persisted
tested
qualified
next_action
recovery_point
blockers
```

For new or materially updated status records, also persist bounded retrieval hints when they are known:

```text
last_reconciled_head
last_reconciled_upstream
relevant_paths
authority_paths
test_paths
evidence_paths
dependency_surface
```

These fields are navigation and recovery metadata, not replacement authority. They point to the owning source, contract, tests and evidence. The `dependency_surface` should be conservative enough to identify which later changes can invalidate reuse of prior reconciliation or evidence. If that surface is uncertain, widen the reconciliation rather than claiming unchanged dependencies.

Historical status records do not need to be retrofitted solely for this protocol. Add or improve retrieval hints when a work unit is next materially touched.

A status record must not claim `tested` or `qualified` before the corresponding gate has actually completed.

## Connector-efficient repository retrieval

Repository access through remote connectors is not equivalent to working in a persistent local clone. Repeated broad search and repository reconstruction can consume most of an execution window. Use a bounded retrieval strategy that preserves authority while minimizing unnecessary calls.

The governing retrieval rule is:

```text
status first -> exact ref -> relevant delta -> bounded files -> search only if needed
```

Apply it as follows:

1. Resolve the target branch once and pin the exact HEAD SHA for the current phase. Read material files against that exact ref rather than mixing moving branch reads.
2. If the work-unit status path is known, read it directly first. If it is not known, inspect the exact owning integration/workstream directory tree before attempting repository-wide discovery.
3. Use `relevant_paths`, `authority_paths`, `test_paths`, `evidence_paths` and `dependency_surface` from the status record when available. Fetch those paths directly at the pinned SHA.
4. On resume, compare the last persisted/reconciled commit with the current branch HEAD before reconstructing anything. If the work unit also depends on a moving canonical/upstream branch, compare the last reconciled upstream commit with its current HEAD.
5. If the resulting delta does not intersect the recorded dependency surface, preserve already-valid authority reconstruction and immutable evidence. Re-run only the incomplete action or the checks whose declared dependency surface changed.
6. If the delta intersects the dependency surface, inspect the intersecting paths and their owning contracts/tests first. Do not automatically repeat unrelated repository reconnaissance.
7. Prefer exact-ref file reads and small directory-tree traversal over a recursive full-repository tree. Escalate only when the bounded locations are genuinely insufficient.
8. Treat code-search results as **locators, not branch authority**, unless the search mechanism is explicitly scoped to the exact target ref. A path or symbol found through a default-branch index must be re-read at the pinned target SHA before it supports an implementation or qualification claim.
9. Persist newly discovered stable retrieval paths in the next meaningful work-unit status checkpoint so a later runtime does not have to rediscover them.

This strategy is an optimization of repository access, not a relaxation of scientific or architectural reconciliation. If a bounded delta cannot establish that relevant dependencies are unchanged, conservatively widen the read and reconciliation scope rather than assuming equivalence.

## Recovery after interruption

After a timeout, aborted tool call, lost runner or interrupted chat, resume from repository state rather than reconstructing from memory.

Recovery order:

1. Re-read the current workstream branch and exact HEAD commit and pin it for the recovery phase.
2. Read the latest work-unit status record and recovery point directly when its path is known; otherwise inspect the exact owning workstream directory to locate it.
3. Confirm that the referenced checkpoint postimage exists in Git.
4. Compare the checkpoint or last-reconciled commit with current HEAD, and compare the last-reconciled upstream/canonical commit when that dependency is relevant.
5. Intersect those deltas with the recorded dependency surface and retrieval paths.
6. Preserve already-persisted source, authority reconstruction and evidence when the relevant dependency surface is unchanged.
7. Re-read only changed/intersecting dependencies and re-run only the action that was incomplete or whose result was not durably recorded.
8. Do not repeat broad source reconstruction or redesign merely because the previous execution session disappeared.
9. If repository state and chat history disagree, repository state wins.

A normal recovery statement should be concrete, for example:

```text
Work unit: F-CI07
Recovery commit: <sha>
Persisted: yes
Relevant delta since checkpoint: none
Focused tests: passed
Qualification gate: incomplete
Next action: rerun qualification gate from the persisted postimage
```

## Commit discipline

Checkpoint commits should use a recognizable message, for example:

```text
checkpoint(F-CI07): persist trial capsule before regression
checkpoint(F-MQ01): persist deterministic harness before scale gate
```

Final qualification commits remain separate when useful. Checkpoint commits may later be squashed or reorganized during canonical integration, provided the qualified lineage remains reconstructible.

## Shared-semantics merge contract

The recovery protocol does not authorize a workstream to widen shared semantics merely because its local implementation is persisted and tested.

The project-wide rule is:

```text
parallel where ownership is disjoint
serial where semantics are shared
```

When a work unit can affect shared state ownership, transaction semantics, application ownership, exchange/coupling contracts, numerical policy, mass ownership or common solver/runtime interfaces, its status/handoff record should identify:

```text
owned surface
read-only authorities
interfaces allowed to change
interfaces held fixed
dependency surface
required qualification
cross-workstream consequences
canonical admission owner
```

If implementation discovers a required shared-contract change outside that boundary, persist the finding and return it to the shared integration authority instead of silently broadening local scope.

See [Quality governance after Status A](quality-governance-a-aa.md) and the current PROJECT-CONTROL registry for the controlling governance and routing rules.

## Relation to architecture invariants

This is a development and qualification execution protocol. It does not change SWAP physics, numerical policy, transactional semantics, runtime semantics or the Core Architecture Invariants.

The architecture invariants define what the system must mean. This protocol defines how development work is persisted and recovered safely while reaching that system.

## Minimum rule for every new work unit

No material work unit is allowed to depend on a long-running gate while its only useful postimage exists in transient chat state or an uncommitted worktree.

Before such a gate starts, answer all three questions with a concrete repository reference:

1. What exact postimage is safe?
2. At what Git commit can work resume?
3. What is the single next incomplete action?

If those answers are not yet available, create the checkpoint first.

## Autonomous recovery and local-first work

Choose work order by dependencies, risk and likelihood of qualified closure. Continue after intermediate compiler failures, commits and focused tests where time and safe execution permit. Larger architecture changes are allowed when source-backed, documented and tested against existing invariants and preservation requirements.

Prefer available local Git, Python, gfortran and focused O0/O2 tests for iteration. Use GitHub Actions sparingly for necessary persisted integrated qualification, reusing valid exact-postimage evidence. A local DNS failure does not imply the connected GitHub repository tools are unavailable. A missing checkout does not imply missing source. Independently use supported exact-ref GitHub file, tree and blob retrieval and consult the source locations in `reference/swap-4.3.1/README.md`. Do not ask for historical archives until the documented repository paths, recovered sources and manifests have been checked.

If a required execution route fails, attempt alternative supported routes and continue independent work. A blocker report must identify the specific failed method, actual error, alternatives attempted and precise remaining dependency. Do not claim a local run occurred without evidence. Report meaningful closures and irreducible blockers rather than every intermediate step. Platform execution limits remain real; preserve a recovery point when they prevent continued work.


## Byte-verified local test recovery

When local Git or DNS fails, use the connected GitHub repository interface to retrieve exact-ref files. Reading content through a connector does not by itself place files into the local execution environment.

For a bounded local test:

1. Pin the target commit and fetch the existing source files, test drivers and runner from that exact ref.
2. Transfer files to a local tree. Preserve CRLF, trailing whitespace and raw bytes where required.
3. Verify Git blob identity and any available SHA-256 manifest before calling the reconstruction byte-exact.
4. Run the existing repository test at O0 and O2 with its prescribed compiler flags. Keep additional diagnostic smoke tests separate from official evidence.
5. Broaden to provider and runtime dependencies only after recording the focused gate outcome.

Distinguish readable source, byte-verified local source, focused tests, integrated preservation, qualification and canonical admission. A successful focused test never substitutes for a required integrated gate. When code changes, check the tested commit and relevant dependency surface before carrying evidence forward.

## GitHub Actions scheduling hygiene

Check existing queued, running and completed qualification for the exact PR head before starting another run. A draft PR may trigger workflows automatically. Do not create duplicate runs just to check runner availability.

When reducing workload, inspect pull_request and push path filters, shared dependencies, workflow_dispatch, concurrency and owning admission requirements. Narrow unrelated triggers only where the declared dependency surface remains covered. Do not weaken numerical thresholds or remove mandatory preservation. Document an unverified queue improvement as expected rather than measured.


## Autonomous long-session execution standard (2026-10-08)

This section makes the demonstrated SWAP5 ordinary-chat workflow recoverable for **every future workstream and chat**. It supplements, and never overrides, the scientific authority, Status-A, workstream ownership, architecture invariants or admission gates above.

1. **Take responsibility for a substantial bounded unit.** The user may delegate ordering and defensible architectural decisions. Continue independently across multiple diagnostics, source comparisons, repairs, local tests, persisted commits, qualification, PR reconciliation and admission when authority and gates permit. Do not stop at each compiler warning or require repeated “go” messages. Report meaningful milestones, not trivial microsteps; never claim progress that has not happened.
2. **Always rediscover the live repository.** Read `AGENTS.md`, this protocol, knowledge map, current Status-A, canonical integration HEAD, relevant source identity, status/recovery records and open/draft PRs. Pin the exact base and test head. Repository and current tool results outrank chat memory. Treat separately **implemented, persisted, tested, qualified, preserved, canonically admitted**. An earlier draft or a passing old-head run is not admission.
3. **Use available access routes resiliently.** Prefer local shell, Python and gfortran O0/O2 for bounded testing and call GitHub only for persisted changes and necessary integrated gates. If local git/DNS fails, continue via the working GitHub connector/API and reconstruct the exact necessary blobs locally where feasible; do not conclude that a source file is missing merely because one access route failed. Discover the actual tool capabilities before declaring an access blocker.
4. **Work in larger, dependency-aware units.** Compare historical B1.11/4.3.1 source identity to current production execution and exact Git blobs before implementing. Reconcile overlaps and owners. Do not replay an old crop owner, root uptake, transport, solver, state, forcing or restart module over a newer admitted one. Separate truly missing semantics from component-only evidence, historic open entries and already admitted capabilities.
5. **Persist first, then verify.** Keep branch/commit, changed files, source authority, work-unit stage, failing invariant, exact test commands/evidence, outstanding dependencies and next action durably in the owning work-unit record, audit or PR. Use focused fixes; avoid accumulating speculative changes. Never weaken mass conservation, missing-contribution fail-closed status, trial/accept/retry rollback, restart, state ownership, or hydraulic preservation to make a gate pass.
6. **Let existing automatic GitHub Actions finish.** Avoid duplicate manual dispatch. When qualification is running and the user asks to continue/wait, **actively poll the existing run(s)** periodically (roughly 20–30 seconds when the execution environment permits) until terminal status, inspecting individual job failures and repairing real causes. Do this **within the live turn** only: never promise background monitoring after the reply, and never confuse an in-progress job with a pass. Continue to admission/reconciliation after a successful result instead of waiting for another user message. Give concise progress updates during unusually long runs.
7. **Attribute red checks precisely.** Record the exact SHA and workflow/job/test outcomes. Differentiate an owner science gate, F-CI moving preservation, governance-only path restrictions, unrelated solver/performance/reference workflows, and stale check statuses. A globally “unstable” PR is not automatically failed science, but unrelated red checks cannot be silently dismissed or weakened. Preserve owning workstream authority.
8. **Finish the full cycle when justified.** After exact-head science O0/O2 and F-CI preservation pass and PR overlaps are reconciled, verify live canonical HEAD, base, mergeability and expected PR SHA. Admit only the bounded qualified scope via a safe merge, verify canonical HEAD and production blobs, close or annotate superseded draft PRs, and update the canonical/master coverage authority. Keep nonqualified science and broader source envelopes explicitly open.
9. **Do not overclaim.** A standalone selector or checkpoint-value replay does **not** establish complete physical crop rotation, F-KT integration, harvest/sowing/germination or persisted restart. A historical master count does not prove that many production implementations are missing. State limitations and evidence at the level actually tested.
10. **Carry work into new chats.** The next chat should start from repository canonical HEAD and the current ownership/status ledger, not re-derive this conversation. If a PR remains in progress, give its exact URL, branch/head, run IDs, error, qualified/pending scope, owner interfaces and the next decisive action. A user should not have to repeat the operational rules or manage recurring DNS, source-finding and run-status incidents.

**Practical continuation loop:** reconcile → choose maximal safe dependency-ordered scope → persist implementation/evidence → run local O0/O2 → observe *existing* integrated runs through completion → diagnose and repair (without weakening guards) → requalify exact head → reconcile ownership/checks → merge if admitted → update coverage and remaining queue → continue.


## Local contract feedback before integrated qualification

For new physical functionality, identify an executable production-driver seam,
explicit inputs and committed/candidate/workspace ownership, the actual ordered
compile/link closure, and independent oracles where available. Explain unavoidable
large closures in the existing work-unit evidence. Run local function/module and
state/interface tests during development; run targeted physical composition when
the route becomes executable and earlier where shared semantics require it.
All current owner, Full Richards, restart, mass, coupling and F-CI gates remain
mandatory at their existing qualification/admission boundaries.

Identical artifacts may be shared inside a controlled qualification execution
only with verified source/provider/flags/compiler/environment/module identities,
separate O0/O2 directories and fresh execution of every required scientific driver.
The opt-in modular feedback experiment does not replace a default gate. Persistent
cache or evidence inheritance requires its separately qualified full dependency
and terminal-evidence binding. Unknown closure means RUN, never inherited PASS.
See [the tested modularity investigation](../audits/MODULAR_TESTABILITY_20261013.md).

## Test selection and cost discipline (2026-10-13)

This is the default execution policy for future SWAP5 workstreams. Evidence:
[modular testability](../audits/MODULAR_TESTABILITY_20261013.md) and
[measured session costs](../audits/MODULAR_TESTABILITY_SESSION_COST_20261013.md),
admitted via PR #1219 at `0181a829eb5f17267541d6b57d7e65140db7bd5a`.
These rules govern when an agent invokes existing runners. They do not remove
scientific assertions, change numerical tolerances, or silently alter owner gates.
The 15 October enforcement below applies these rules to the existing entrypoints.

### Select before running

In the existing work-unit record or PR, before an expensive execution, state:

- changed contract and conservative dependency surface, including state ownership,
  callers, external procedures, initialization, fixtures and runtime inputs;
- immediate local tests and targeted composition tests;
- required stable-candidate/admission gates and the exact owning clause;
- reused evidence with complete unchanged input/dependency/toolchain binding;
- expected duration, known cost breakdown and UNKNOWN values, plus the actual
  candidate/source identity. Explain each expensive selection, not every command.

Use the existing four-level change matrix in the modularity audit. During editing,
run level 1 production function/module contracts and relevant level 2 state/interface
checks. Run level 3 physical composition when the involved processes are ready,
earlier when shared-state semantics require it. Run level 4 broad preservation at
the required stable-candidate/admission boundary. A checkpoint, a new docs commit
or a new branch head alone does not require a new full F-CI run.

### Expensive tests are explicitly selected

A test measured or expected to exceed **five minutes** is operationally expensive.
This is a selection threshold, not a scientific tolerance, timeout or speed claim.
Keep such tests outside the routine local feedback sequence. Unknown cost calls
for the smallest useful existing driver or bounded diagnostic observation first;
do not automatically launch a full stress matrix to discover its duration.

The executing agent can select an expensive test autonomously when a named changed
scientific dependency or an owning qualification/admission requirement justifies
it. Record the reason and expected cost before starting; user confirmation is not
required for this routine selection. A highest low-air stress test is not implied
by a generic request to run tests, a docs-only edit, or an unrelated process change.
For the long highest low-air route, apply the later
[14 October selection decision](../audits/LOW_AIR_TEST_SELECTION_DECISION_20261014.md):
it is retired as a standard production admission/preservation gate. An older
mandatory label or changed dependency alone does not select that stress run.

Do not add expensive stress matrices to blanket PR/push feedback jobs. Changing an
existing mandatory runner or CI trigger requires reconciling its owning authority
and proving retained required coverage. This policy is not evidence that those
existing triggers have already been reconfigured. Do not automatically start a
second full qualification while a relevant run is already active or valid terminal
evidence has the same proven dependency surface.

An observation stopped at a budget is CENSORED, with completed science/exit UNKNOWN.
A timed-out qualification is incomplete or failed. Neither counts as PASS. Do not
shorten forcing, reduce cases, loosen tolerances or omit required O0/O2 controls
merely to meet the operational cost threshold.

### Build once where identities permit; execute every required driver

Use existing strict dependency selection and shared-build facilities first. A small
`use ..., only:` list or a short driver does not prove a small build or numeric task.
Measure the actual compile/link closure and justify large accepted-state closures.
Prefer reducing unnecessary local closures, then object/module reuse within one
controlled execution, before expanding persistent caches. Isolate O0/O2, flags,
compiler/environment and module directories; link each scientific driver separately
and execute all selected assertions. Reusing compilation does not inherit test PASS.

### Measure without double counting

For new benchmark or expensive controller work, retain command, candidate identity,
compiler/flags, input/oracle/dependency identities, raw outputs, exit and terminal
status. Record compile time and request counts, link time, native execution,
validation, total wall time and cold/warm reuse where the runner supports them.
Separate physics from driver assertions/output only when actually instrumented.
Use controller timing for Python/evidence/GitHub operations when useful; mark
unmeasured categories UNKNOWN. Poll waits overlapping active computations are not
additional test duration. Do not sum a parent controller with its child events or
count a retained event prefix twice. Alternating repeated same-candidate comparisons
support a scoped performance claim; a single sequence under concurrent work does not.

### Reuse evidence and consolidate work

Inheritance needs terminal PASS and proven unchanged source, caller/state contracts,
driver, oracle, physical input, flags, compiler/runtime, relevant environment and
build selection. An import graph alone is insufficient. Unknown dependency identity
means no inheritance. A docs/evidence-only successor with a fully identical scientific
execution surface needs the applicable docs/evidence checks, not fresh numerics solely
because its commit SHA differs. Configurations or manifests read by a runner are inputs,
not automatically descriptive documentation.

Reconcile relevant live canonical delta and existing queued/running/completed results
before rebuilding or reconstructing repository evidence. Use immutable historical
archives already present. Keep the actively used toolchain/dependencies recoverable
within the workstream workspace; another disposable workspace is not durable authority.
Persist coherent implementation, measurement and closeout batches. Avoid administrative
commit sequences that produce no new executable feedback or recoverable phase boundary.

Review a costly test's unique failure detection, overlapping cases and realistic
scope before proposing removal or a shorter replacement. Only an evidence-backed
owning-authority change can retire a mandatory gate. A smaller test can prove its
contract; correct full-model integration remains a separate claim. Full Richards,
mass, transactions, restart, independent oracles and coupling contracts retain their
accepted scientific authority.


### Apply the modular route (2026-10-14)

The normal **local feedback** entrypoint is now:

```bash
python tests/modularity/run_modular_tests.py --list
python tests/modularity/run_modular_tests.py --output /tmp/swap5-local-new
# Select the actual changed contract, rather than a blanket scientific suite:
python tests/modularity/run_modular_tests.py --case drainage --output /tmp/swap5-drain-new
python tests/modularity/run_modular_tests.py --case root_oxygen --case root_contract --output /tmp/swap5-root-new
python tests/modularity/run_modular_tests.py --case assimilation --output /tmp/swap5-assim-new
```

Use a fresh output path. The default runs Boesten, empirical root oxygen plus
root ownership/error contracts, Hooghoudt equivalent-depth preparation, and the
existing WOFOST81 assimilation oracle. Each provider closure has one to three
production files. Accepted heat remains explicit `--case accepted_heat`, because
its accepted-state provider closure still has 154 files. `--audit-closures` and
`--audit-build` are explicit investigation options, never the routine default.
The default is a convenient starting set, not a scientific impact selector.

Develop a new historical function in its owning production module with explicit
units, admissible input domain, result/status and committed/candidate ownership.
Reuse the admitted physics; never implement a second production formula in the
test. Add a small real Fortran driver and, when available, an independent historical
oracle to the existing runner. Name its flags, output validation and actual ordered
closure. One to three providers is demonstrated for these seams, not a universal
maximum: justify a larger closure from the real contract and measure it. A private
backend type cannot be replaced with a mock merely to meet a build budget.

During editing, execute the changed level-1 driver and relevant level-2 contracts.
Mutable state, producer/consumer changes, units, accepted/candidate identity or
mass ownership require input nonmutation, invalid/rejected paths and A/B/A or
rollback/restart checks as applicable. Once a candidate is stable, run level-3
composition using the actual Richards/accepted-state route and affected downstream
processes. Shared solver/state/runtime changes require that composition earlier.
Run level-4 owner and full preservation at the existing mandatory admission boundary.
Use the four-level matrix above and the modularity audit; this entrypoint does not
infer physical independence from module imports or choose admission gates.

Verified provider artifacts can be shared between selected drivers only inside
one live Session with identical ordered source/provider prefixes, flags, compiler
and environment, and unchanged object/module bytes. O0/O2 remain isolated; every
selected executable is linked and executed independently. Warm re-execution checks
the full artifact set and executes the science again. It does not inherit PASS.
`--independent-builds` provides the explicit control policy. There is no persistent
cache or cross-host evidence inheritance. For result inheritance, the unchanged
scientific dependency and terminal-evidence requirements above remain binding.

The repeated adoption experiment measures the same new drivers with independent
versus shared provider builds, not two complete admission suites. Its executable
bytes and O0/O2 science outputs must match. Retain compile, link, native-plus-driver,
identity/oracle validation and total timing separately; physics alone is UNKNOWN
unless independently instrumented. See [the adoption results](../audits/MODULAR_DEVELOPMENT_ADOPTION_20261014.md).


### Change-impact selection for already qualified components (2026-10-15)

Previously qualified components are not retested merely because upstream physics, forcing or boundary-condition values change. The test selection must identify a changed scientific contract, a changed component implementation, or a specific failure mode not covered by existing qualification. A change of valid input values within the qualified domain is not itself a contract change. This rule applies to all independently qualified components, including RossFast, not only solvers.

For routine crop, root, meteorology, irrigation, drainage and solute migrations, test the changed production physics and its accepted mass/state effects with focused module and physical integration tests. Do not automatically repeat qualification of independent unchanged downstream components. Check genuine interface semantics, input domain, state ownership, accept/reject/rollback, restart and coupling effects before selecting additional tests. A changed shared source file or module import alone is not proof that a component's scientific contract changed.

When a component implementation or relevant contract actually changes, select the smallest test that can discriminate the resulting risk, and run owning preservation when genuinely required by the applicable authority. If an essential new failure mode outside qualified coverage is identified, record the specific gap and test it. Prior PASS may only be inherited with the protocol's full identity and terminal evidence requirements; otherwise record NOT_SELECTED_IMPACT, not PASS. Never relax numerical tolerances, physical oracles or conservation requirements.

Before executing a compound runner, inspect whether it automatically starts unrelated component suites, including F-ROSS preservation, and reconcile outdated automatic selection through the owning runner authority. Documentation changes alone do not alter CI routing. Use the existing PR/workunit for selection rationale, expected cost and evidence; no new register.

### Highest low-air selection decision (2026-10-14)

The user/programme lead has retired the long highest low-air qualification as a
standard migration, production admission and routine preservation gate.
[The binding decision](../audits/LOW_AIR_TEST_SELECTION_DECISION_20261014.md)
supersedes the previous default owner-required minimum execution boundary.

Require fast independent physical oxygen/uptake/drainage/mass tests and targeted
numerical acceptance/rejection/rollback/restart/extreme-input contracts. Select a
long run only for a concrete numerical research question or essential uncovered
risk: name the unique failure, demonstrate the fast coverage gap, explain why a
small discriminating test cannot cover it, and record expected costs first.
Shared dependency changes and unknown fingerprints require reconciliation, not an
automatic highest stress matrix. No fixed daily/weekly stress frequency is adopted.

Reconcile older owning guards to this selection authority and retained coverage;
do not fabricate PASS or weaken physical assertions. An omitted stress run is
NOT_RUN_POLICY/NOT_SELECTED, not highest qualification or 10x proof. Actual
essential coverage gaps remain admission conditions. Production, immutable
references and tolerances are unchanged. Automation enforcement follows below.

Continue in coherent implementation, feedback, composition, measurement and admission
batches. Persist before expensive execution and move automatically to the next safe
phase. Do not turn a small driver result or a normal checkpoint into a user approval
boundary. State an exact shared-contract blocker and continue independent work.


### Enforced proportional execution (2026-10-15)

These rules are mandatory for every Work session. The four scientific levels and
all existing owner/admission clauses remain authoritative. This adds selection
preflight to existing runners, not a test framework or second evidence registry.

1. Develop with the smallest scientifically relevant real production driver and
   affected state/interface contracts. Use shared verified builds where safe;
   every required scientific program still executes. Routine feedback executes
   each selected O0/O2 driver once; deliberate warm repetitions belong to benchmarks.
2. Before any expected or measured execution over 300 seconds, record changed
   dependency, scientific claim, owner and authority clause, expected seconds and
   potentially valid existing evidence. UNKNOWN evidence never means inherited PASS.
3. A commit, checkpoint, documentary successor or branch advance alone never
   selects full moving F-CI. Run full moving F-CI when the stable candidate's
   scientific admission authority requires it. Imports alone cannot exclude a gate.
4. Highest low-air is NOT_SELECTED_POLICY by the binding 14 October decision.
   An exceptional stress selection requires its unique research question/failure,
   fast coverage gap and why a small discriminating test is insufficient.
5. Inherit only terminal PASS with full relevant source, caller/state, input,
   oracle/test, toolchain/flags and environment identity. The selection preflight
   grants no inheritance and no scientific PASS; existing evidence validators remain.
6. Diagnose an unexpected long execution before restarting an identical one.
   Preserve failed/censored observations. No tolerances, physical assertions,
   historical references or scientific claims may be relaxed to meet a time budget.
7. Before every broad qualification record selection in the existing PR/work-unit.
   Unmapped dependencies conservatively block automatic selection; reconcile owners
   and retain affected physical integration, mass, restart, coupling and admission.

Commands for the next Work session:

```bash
python tests/modularity/run_modular_tests.py --changed-since <pinned-base> --selection-only
python tests/modularity/run_modular_tests.py --case drainage --output /tmp/fresh-drainage
# On reviewed local seams, select and execute directly. Unknown changes block.
python tests/modularity/run_modular_tests.py --changed-since <pinned-base> --output /tmp/fresh-feedback
# For an owner-required stable candidate, first update ITS EXISTING status JSON:
export SWAP5_TEST_SELECTION_RECORD=integration/<owner>/<existing-status>.json
python tests/modularity/run_modular_tests.py --check-selection full_fci
bash tests/fci/run_fci_canonical_p2e05_moving_preservation.sh
```

The existing JSON accepts this additive field; other owner metadata is retained:

```json
{
  "test_selection": {
    "candidate": "<persisted-commit-before-test>",
    "groups": {
      "full_fci": {
        "changed_dependency": "<specific affected contract or stable admission dependency>",
        "scientific_claim": "<claim requiring this complete qualification>",
        "owner": "<existing admission owner>",
        "authority": "<existing repository authority path>#<owning-clause>",
        "expected_seconds": 1850,
        "existing_evidence": "<relevant exact evidence or UNKNOWN and why RUN>",
        "prior_execution": "NONE"
      }
    }
  }
}
```

`prior_execution` is NONE, PASS, FAILED or UNEXPECTED_LONG. For a repeat include
`diagnosis`, explaining why existing PASS cannot be reused or what was learned
from the failed/long run. `candidate` binds the decision to persisted inputs;
only descriptive docs/AGENTS and that same status record may subsequently change.
Other changes require a fresh selection. This intentionally errs toward blocking;
it does not infer safe inheritance from a shortened dependency list. A record can
be committed after its candidate without making the commit SHA self-referential.
Selection estimates must be finite and positive. A reason is checked for presence
and freshness, not automatically certified as scientifically sufficient.

The existing canonical workflow now runs small feedback on automatic source/test
changes, blocks unmapped changes for owner reconciliation, and runs complete moving
F-CI only through explicit dispatch with the selection record. Historical frozen
replays have a separate explicit `replay_historical` decision: they run frozen code
and do not test a changed current candidate. Docs-only pushes do not start numerics.
The frost workflow retains all full owner bodies through a `frost_owner` selection,
with highest low-air separately opted in and preflighted. Its full-owner dispatch
also preflights `full_fci` before any owner compilation. Its automatic route runs
short root, numerical-policy and independent frost/invalid-input contracts. B19's
complete highest matrix is explicit research dispatch, with `highest_low_air` and
`full_fci` decisions. This reconciles obsolete automatic obligations to the 14 October
owner decision, without deleting historical assertions or pretending a short run
establishes complete highest coverage.

`modular_broad` is required for accepted heat, the full bounded low-air physical
feedback fixture, closure audits and benchmarks: these are explicit investigations,
not routine feedback. A necessary full F-CI keeps its complete existing science body.
The focused irrigation allocation option retains its bounded owning route behind
its own `irrigation_allocation` preflight: the historical shared pair still takes
499 to 540 seconds and therefore also needs an expensive-test selection. Existing
resume receipts stay fail-closed on changed runner/tool identity; no new cache or
receipt eligibility is introduced. The LOW02 moving reconciliation is explicit dispatch with `low02_owner` and
`full_fci` preflight. F-CI107 no longer triggers on the outer moving wrapper alone:
its complete RossFast source/test/own-workflow triggers are retained with a
`rossfast_owner` preflight in the existing F-CI107 status (or explicit dispatch
record), because the
wrapper preflight changes none of its scientific recipes. Other capability-specific workflows retain their
own authority and need the same documented cost selection before deliberate execution.

## MC-SOL01 Reference-first and optional RossFast freeze (2026-10-17)

Decision: finish the SWAP4.3.1 migration using the Reference solver as the required hydraulic production route. RossFast remains an optional, frozen alternative only within its previously admitted scope. No MC-SOL01 feature expansion or support for newly introduced gross surface flux / pond solute contracts is required from RossFast during migration.

Selection rule: a change to a shared solver-contract source file is an impact trigger, not proof of a RossFast numerical regression. Identify the exact public-interface delta and its consumers. For unchanged RossFast implementations, existing admitted routes remain protected by focused compilation and behavioral/semantic preservation tests where affected. For new Reference-only diagnostics, record RossFast support as UNSUPPORTED_OPTIONAL for the new capability, not PASS and not ADMITTED. Never dispatch an unsupported RossFast route as though it supplied accepted gross fluxes.

Existing exact-blob F-ROSS22 controls remain unchanged; when their qualified-dependency identity guard fails on a newer shared contract, record FROZEN_OPTIONAL_CONTRACT_DRIFT as a non-admission result for RossFast on that contract. Do not falsify a pass, weaken the guard, or silently merge shared-contract changes under a misleading green check. A separately reviewed admission decision must explicitly document the pinned older RossFast authority, the new Reference-only contract surface, executable evidence for preservation of any affected *old* RossFast path, and the appropriate branch/ruleset requirements before canonical merge.

For MC-SOL01, the work unit still requires actual accepted gross water and solute receipts, historical mixing, water/solute balances, rollback, V2 restart, O0/O2 and its owning preservation gates. A red old RossFast blob-identity check must be attributed separately; it is not grounds to stop developing Reference chemistry. Do not split this work into micro-PRs. Defer broad RossFast compatibility expansion until after the migration, preserving its existing admitted production code and evidence.
