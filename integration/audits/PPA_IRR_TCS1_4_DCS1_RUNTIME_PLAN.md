# TCS1-4/DCS1 bootstrap integration

Status: next implementation phase; no runtime qualification yet.
Owning preregistration and evidence: `PPA_IRR_TCS1_4_DCS1_PREREGISTRATION.json`
and `PPA_IRR_TCS1_4_DCS1_STATUS.json`.

## Entry contract

Retain observations presence and array-size checks for TCS1-4. For DCS1,
require an explicitly supplied profile array of matching column count. Dispatch
to `evaluate_tcs1_4_dcs1_source` with the hydraulic view and event from the
existing committed snapshot. Do not silently enable profile-free DCS1.

For this route only, defer individual profile-field validation to the source
helper: inactive eligible selection requires valid geometry; pending or idle
intervals do not require populated unused fields. Preserve the current TCS7/8
profile validation contract and all DCS2 routes. Keep configuration tables
subject to their existing scheduled-process validation.

## Integration fixtures

Extend the existing TCS prefix/restart fixture with four explicit DCS1 cases.
Use one-cell root depth to prescribe the existing staggered gift amounts from
the known initial hydraulic water content, without altering numerical policy.
Give contradictory request deficits to prove checked profile derivation is used.
Scale TCS4 threshold to the small root-zone amount, preserving its mm-to-cm law.

Verify invalid/missing selection profiles reject before execution with both
columns unchanged. Verify accepted prefix mass, event persistence and decoded
fresh-owner restart; pending continuation uses empty profile objects and an
invalid unused observation table. Compare original/restored hydraulics exactly.
Repeat the existing internally progressed hydraulic rejection fixture for all
four DCS1 cases and inspect committed water, time, revision and event state.

Run clean IrrigationSource O0/O2 transcript identity, hydraulic-copy and guards,
plus documentation gates. Keep claims limited to these supplied-profile,
water-only, single-node SSDI fixtures. No canonical admission, general geometry
derivation or automatic daily stress accumulation is implied.
