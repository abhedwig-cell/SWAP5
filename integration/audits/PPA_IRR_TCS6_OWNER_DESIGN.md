# Weekly irrigation counter ownership

Status: branch-local implementation contract; staged evidence is recorded in the status JSON.
Baseline: `f8e22d1fd`; process evidence is in `PPA_IRR_TCS6_COMPOSITION_STATUS.json`.

## State and invocation

Store weekly counter and last-consumed daily invocation identity in the existing
`ppa_irrigation_event_state_t`, alongside (not inside a second owner of) its
irrigation event and hydraulic/history state. An inactive gift must retain these
weekly fields. Clone and decoded restart must preserve them. Defaults must keep
all existing nonweekly fixtures valid and unchanged.

Use explicit caller-supplied monotonic daily ordinal and an explicit daily
selection flag. Do not infer dates from fractional solver time. First activation
starts from source dayfix 366. A consumed ordinal cannot increment again;
backward ordinals fail closed. Define gap handling explicitly before coding:
the caller must submit consecutive daily invocations; do not invent skipped-day
deficits or silently advance multiple days. Crop-rotation reset is a separate
explicit input/contract, not inferred from DVS.

Source daily ordering is reviewed in `PPA_IRR_TCS6_DAILY_SOURCE_REVIEW.md`.
The first route is standalone day-start, TCSFIX disabled. An accepted explicit
daily invocation consumes its ordinal even when ineligible, but only eligible
selector invocation changes dayfix. Pending continuation does not reselect.
Duplicate ordinal suppresses a second selector/counter transition; backward or
skipped ordinals reject. These ordinal rules are explicit restricted SWAP5
ingestion semantics, not a legacy stored field.

## Transaction boundary

Detached daily composition is now tested at `f911acba3` in
`mod_ppa_irr_tcs6_daily`; this is a proposal producer, not runtime publication.
Dependency inspection found 80 runner/tool references to the shared irrigation
process source. Adding a new backend module dependency requires a deliberate
compile-list update/preservation pass; do not silently leave existing runners
unable to compile. The metadata type and validators now live in the already
shared irrigation process module. `build_irrigation_event_candidate` constructs
a fresh event carrier from a temporal physical state; callers must pass its
optional weekly metadata explicitly or receive disabled defaults. The backend
trial transfer implemented at `ac947c243` retains metadata in candidate clones
and requires an explicit proposal for enabled weekly carriers.

Current bootstrap `run_prepared_irrigation` accepts selected event proposals
and an optional selection mask, but has no weekly management proposal channel.
Add an explicit typed proposal channel only after validating the source daily
gate. It must carry both proposed counter and invocation identity, including on
days where no gift is selected. A false selection mask must not discard a valid
no-gift counter transition. Do not encode counter changes as artificial gifts.

The backend must place management proposals in the same candidate carrier that
the existing runtime commits or discards. No writes to the exported snapshot or
application-owned committed array during preparation. A rejected hydraulic
trial retains counter, ordinal, event, water, history and revision. Per-column
mixed publication remains explicit; a batch-level counter is forbidden.

## Required gates

The bootstrap prepared-irrigation entry now takes an optional trailing
`weekly_proposals(:)` array. Shape and metadata validity are checked before any
column executes. Enabled entries forward their proposal regardless of the gift
selection mask. Valid disabled defaults mean absence for that column, permitting
mixed weekly/nonweekly batches; they cannot disable an already enabled owner,
because the backend requires a proposal for that owner. Transition validity is
still checked against each committed column, with existing mixed publication
semantics. This channel does not yet construct proposals from daily input.

### Backend proposal validation contract

The optional backend management proposal must pass `valid_weekly_transition`
against the committed weekly metadata before hydraulic execution. Both states
must be valid and enabled. An unchanged identity permits only an unchanged
counter. A first or consecutive ordinal permits the unchanged counter (ineligible
day) or exactly one source counter increment/reset. Backward/gapped ordinals,
implicit activation, disabling and crop resets reject. Ordered subtraction
avoids integer overflow at the maximum ordinal. This guard checks structural
publication validity, not scientific eligibility or deficit selection; those
remain the daily process producer's responsibility. The backend now accepts
the explicit optional `weekly_proposal` only for an enabled weekly carrier;
omission still rejects enabled carriers. Pending events cannot change dayfix.
The model copies the proposal at the initial trial boundary into its candidate,
including fresh retry clones, and clears its call-local proposal flag afterward.
Only the existing candidate commit publishes it. Bootstrap wiring remains pending.

The resolved irrigation-column runtime adds an optional trailing
`weekly_proposal`, forwarded unchanged through `execute_resolved_column` to the
backend. Absence remains absence for existing callers. The shared checkpoint,
commit/discard and accounting body remains authoritative; no parallel commit
path is introduced. Qualification compares explicit backend commit against this
runtime path and repeats the longer failed trial before a shorter successful
retry. Bootstrap array forwarding is a subsequent stage.

The first no-gift hydraulic fixture at duration 1/1024 day failed completion;
this numerical case remains open and is not evidence against no-gift transaction
semantics. A separate bounded 1/65536-day fixture is used to investigate accepted
metadata publication without changing any numerical acceptance criteria. Its
result must not be generalized to the longer interval or full-day execution.

- Seven accepted no-gift days reset the counter, including decoded midweek restart.
- Duplicate daily invocation does not increment twice; backward/gapped input
  is rejected under the final explicit contract.
- Startup 366, strict deficit threshold, daily selection and source crop gate agree.
- Split retries and rejected internally progressed hydraulics preserve all
  committed management fields and replay identically after restart.
- Successful no-gift hydraulic intervals publish management exactly once.
- Existing TCS1-4/TCS7-8 source, runtime, restart and mass fixtures remain passing.

Before expanding the carrier, qualify its factory/clone/matches-candidate and
decoded restart validation in isolation. Then wire backend proposals, then
bootstrap daily input. Each stage requires persisted evidence and O0/O2 gates.
