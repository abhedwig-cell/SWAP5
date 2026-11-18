# Direct soil irrigation age input

**Implemented explicit prototype; qualification and admission pending.** Baseline
is actual canonical e3cb491d15b9d079062285c397cfba552ab0a86d (PR1725/1726).
Both actual source and metadata merge postimages pass the detached registered
owner. The fixed surface/sprinkler current-age policy remains admitted and
unchanged. Functional closure remains PARTIAL, whole science NOT_QUALIFIED.

## Owning interfaces and physical units

Original fixed IRTYPE2 produces qssdi per soil compartment. Its fixed-event
branch does not assign CIRR, and the original age equation has no direct qssdi
age source. Existing young-water SSDI support does not qualify positive input
ages. Actual32original executions on O0/O2 prove these observations: point and
interval inputs both produce2.4cm actual water, zero current CIRR and no profile
response to20day input. The corrected current CIRR plus end-microstep source
adds48cm day, changes positive-age profiles and exactly preserves zero-age
profiles. Nonmutating diagnostics and plain corrected executions agree.
The real four-object composed provider passes O0/O2 source, conservation,
rejection and two-cell temporal refinement checks; errors decrease from
0.0041117 to0.0020226 to0.0010032 as the microstep is halved. These are
component/reference results, not integrated model admission.

The proposed direct age input is qssdi(cm/day)*IRCONC(days)*dtsolu(day), in
cm day per compartment. A dedicated composed provider calls the literal
accepted soil age provider, then adds that direct external age input at the
end of the transport microstep. Incoming age is thus transported beginning
with the next microstep. This is an explicit splitting policy requiring its
own corrected original reference, convergence and conservation evidence;
it is not evidence of complete original profile equivalence.

The existing provider remains unchanged. A separate receipt owns direct input
and the combined residual. Failure returns the committed state. Invalid shape,
nonfinite input, negative flux, invalid age or overflow is refused. No clipping,
pond handoff, artificial production or chemical mass conversion is allowed.

A proposed twelve-value accepted age state retains the eleven existing values
and appends cumulative direct-soil age input. Its soil and combined ledgers
subtract that actual input, while the pond ledger stays literal. Its tolerance
is 8192*epsilon*max(1,actual age inventory,actual age fluxes), with cm day units.
The water and chemical guards stay 1e-10 cm and 1e-10 mg/cm2 respectively.

## Activation and state boundaries

No current selector or codec acquires these semantics. A separate explicit
experimental policy must own selection, build identity, twelve-value protocol,
typed native trailer, original current CIRR correction and complete native
input/cursor validation. Original complete irrigation state owns events; the
new cumulative direct age amount must be transactional and serialized. Existing
saved Ageirr/Agepre/Agedrain parameters remain static and unchanged. Default
routes and all existing surface current-age source layouts must be preserved.

Initial composition targets the already admitted analytical no-macro age/fixed
irrigation scope. Snow, frost, aquifer, detailed weather and other unqualified
process combinations remain excluded until their owners are qualified.

Affected invariants: 3,4,7,13,21,23,30. The new source is candidate-only;
committed state changes only on accepted model steps. The existing age providers
and all old guards stay literal. The new API and state schema require standalone
O0/O2 production-interface drivers, actual original source witnesses, active
rejected-trial/rollback checks, malformed native refusals and exact cold restart
through active gifts before portable/full-period qualification and admission.

The persisted prototype exposes `--age-direct-soil-source`, mutually exclusive
with `--age-irrigation-source`, and defaults off. Six S5DI source codecs append
a24byte paired domain/direct cumulative state after the complete existing
56byte source domain. Twelve-field runtime/ledger activation requires its
actual integrated native/source tests before qualification.
