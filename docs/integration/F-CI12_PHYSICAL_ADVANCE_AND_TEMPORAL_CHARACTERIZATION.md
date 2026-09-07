# F-CI12 — Physical Transaction Advance Binding and Temporal Difference Characterization

## Scope

F-CI12 binds the qualified F-CI11 generic `[t0,t1]` interval and unrounded trial-mass seams into an executable B1.10 transaction-model subtype. It does not change a physical formula, constitutive relation, Jacobian expression, numerical solver policy, mass tolerance, calendar event rule or legacy input format.

The historical F-CI09 `b1_10_transaction_model_t` remains unchanged and fail-closed. F-CI12 adds `b1_10_reference_model_t` as an explicit forward extension so the earlier qualification remains reproducible.

## Physical advance binding

`mod_b1_10_physical_interval_executor` executes only the already qualified canonical adapter path:

1. reset worker-local attempt diagnostics/control;
2. begin an unrounded `b1_10_trial_mass_t` accumulator;
3. begin a generic `b1_10_interval_seam_t(t0,t1)`;
4. call legacy `SWAP` task 22 to prepare the physical interval;
5. call legacy `SWAP` task 2 with the same worker, mass accumulator and interval object.

No path, file name, parser or output unit is introduced into the transaction model. Legacy I/O remains outside this interval execution path.

`b1_10_reference_model_t%advance` restores the supplied trial state into the legacy backend before every run. A normal completed trial captures its post-state into that trial object and returns the exact unrounded `mass_in`/`mass_out`. A non-completed test-double trial restores the supplied start state and returns `solver_ok=.false.` without mutating the trial state.

## Qualified-profile storage

F-CI12 exposes the F-CI10/F-CI11 storage contract through `storage()`. It remains fail-closed outside the qualified profile class: snow or macropore storage, or any other incomplete storage composition, is rejected rather than approximated.

## Temporal difference characterization

F-CI12 deliberately does **not** invent a scalar temporal-error norm or tolerance. Instead it materializes raw, unit-explicit water-state differences for full versus two-half trajectories: head, water content, previous-step head/content, ponding, groundwater level, `volact`, `ldwet`, `spev` and `saev`.

Head and water-content differences remain separate quantities; they are not silently mixed into one dimensionless number. Allocation mismatches in optional thermal, solute, irrigation, crop or WOFOST continuation state are detected. When optional process state is present, `process_scope_complete` remains false until those process-specific temporal measures are explicitly designed and qualified.

This preserves the F-CI11 observation that full and two-half states may legitimately differ while making those differences inspectable.

## Newly explicit blocker: recoverable solver status

The current legacy `SWAP` entrypoint provides a usable **normal-return/completed-interval** signal but no qualified recoverable solver-failure status that can always be converted into transaction `reject -> retry` instead of a fatal legacy stop. F-CI12 therefore records:

- normal-return status: available;
- recoverable solver-failure status: not admitted.

This is now an independent blocker in addition to the missing scalar temporal-error policy.

## Reference execution remains fail-closed

`reference_execution_admitted()` remains false. `temporal_error()` stops explicitly with `scalar temporal error policy not admitted`. F-CI12 does not call or admit `execute_reference_interval` for B1.10.

Admission requires at minimum:

- a recoverable physical solver-failure contract;
- complete temporal characterization for every active persistent process state used by the qualified profile;
- an explicit, reference-policy-owned scalar comparison/tolerance (or a justified redesign of the generic transaction acceptance interface);
- source-bound end-to-end qualification of the resulting reference route.

## Qualification strategy

The F-CI12 gate pins the exact F-CI11/F-CI09/F-CI10 dependencies and compiles the new production adapter sources at `-O0` and `-O2` against a deterministic testdouble for the legacy backend. The testdouble verifies successful generic advance, unrounded mass closure, worker diagnostics, failed-trial state isolation, temporal characterization, incomplete-storage rejection and scalar-temporal-policy rejection.

The existing F-CI11 Hupsel evidence remains the physical evidence for the underlying generic interval/mass seam. F-CI12 does not relabel the deterministic adapter test as a new Hupsel end-to-end qualification.

## Architecture invariant check

F-CI12 advances invariants 2, 3, 5, 7, 8, 9, 13, 23, 25, 26 and 29. It also protects invariant 13 by refusing incomplete storage accounting and protects invariant 23 by not turning a temporal diagnostic into a numerical acceptance policy without qualification.
