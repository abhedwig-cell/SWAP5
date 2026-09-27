# Weekly irrigation counter ownership

Status: proposed implementation contract, not implemented or runtime-qualified.
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
