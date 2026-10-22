# MC-NUT01 explicit native output startup

Status: locally qualified bounded explicit native startup; canonical admission pending.
Baseline: `288ba1473c478b9a2a637f0b12d624fbcc63ca4a`.
Owner: existing HIST-COMPLETE `extended_output_component_20261021/native_startup_successor_20261022`.

The native SNM parser can return a trailing optional `extended_output` request.
Only callers capturing that request may accept `.TRUE.`. Existing calls omit
it and retain rejection of `.TRUE.` and acceptance of `.FALSE.` or omission.
The logical token remains strict, case insensitive and duplicate protected.
A request is published only after the entire input and each startup layer
succeeds. It is application configuration, never a physical parameter/state ID.
Modern bracketed exports do not gain a native flag.

The new explicit `initialize_historical_crop_soil_output_owner` adapter requires
TRUE and stages source-bound crop/soil initialization, diagnostic initialization
and empty report history before publishing any caller state. Rejected input,
unsupported crop, disabled output and already initialized destinations leave
caller authority unchanged. The caller supplies accepted water as for the
existing source startup; this routine does not initialize hydrology or write
files. The admitted output-day API then stages the actual model day and writes
the joint generation before publishing caller memory. Restart uses that existing
generation, never this fresh-start API. Report scheduling remains explicit.

This does not enable TRUE in a general/default historical dispatcher. Heat,
harvest/rotation output, negative active-crop/immobilisation allocation and
snow/persistent-surface N remain outside the claim. No physics, mass tolerance,
restart schema, RossFast or aquifer scope changes. Invariants2,3,7,13,23,26,29
are preserved by the explicit adapter and staged publication boundary.

Selection: fresh local O0/O2 native parser controls, old native fixtures and
original output arithmetic; actual native TRUE/FALSE two-day physical equivalence,
combined fresh-process restart and invalid fresh-start atomicity. Existing
physical drivers keep their assertions; no full730-day or unrelated F-CI replay.
Measured closure and raw successes/failures must be retained before qualification.

## Local result

GNU13.3 O0/O2 passes26 request cases and38 incumbent native input cases per
optimization. Three compiled mutations are rejected: missing enabled route,
missing default TRUE gate and missing invalid-request reset. An initial control
attempt changed a lower-level request assignment; the outer transaction still
blocked the leak. That surviving mutant is retained as a failed test-design
attempt, not a claimed production failure or successful corruption control.

The actual native source starts FALSE and TRUE with byte-identical physical
states. Two real Richards/crop/N days cross1900/1901, with an accumulated first
day and a second-day report. TRUE/FALSE physical endpoints, complete generation
and CSV match O0/O2 and independent-process continuation. All original default
physical assertions remain and endpoints match the previously admitted PR1358
ordinary proof exactly. The hard water and whole-N assertions are unchanged.
The complete two-optimization build/native closure took219.12s. Raw compiler,
link/native streams, generated inputs, report histories, endpoints and failures
are in the source-bound1927-member evidence capsule.

At exact baseline288ba1473 the incumbent daily-MET production owner and39
corruption controls pass. The separate pond research validator already fails
on its stale `app/solute_column/main.f90` hash at that same baseline. Its source
is unchanged and that unrelated research campaign is not selected or relabelled
PASS. Original numerical evidence and previous owning assertions remain intact;
the new gate validates the bounded changed input/startup seam and inherits the
recorded exact-baseline production result. No new process, solver policy,
highest-low-air or hosted numerical campaign is selected.
