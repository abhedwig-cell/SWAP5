# Equal-priority partition process candidate

Canonical baseline d13ef5288c4df8f96f675dd6e5df8ef04062367e.
Implements the proportional policy proposed in CONTRACT.md. The new explicit
process entrypoint is not yet called by the daily nitrogen exchange owner.
No state schema or default changes. This is component evidence, not admission.

Inputs are nonnegative constant requests in kg/m2/day, duration and depletion
time in days, and the actual total delivered amount in kg/m2 from the finite
donor core. Outputs are individual delivered and unmet amounts in kg/m2.
The core owns the zero event and aggregate receipt. This routine owns only
the equal-priority split; it does not infer crop or organic pool semantics.

Before the zero event every request is met. After that event, remaining
delivery is proportional to requests. With one nonzero request, preserve
the total directly. All-zero requests accept only zero delivery. Reject
negative/nonfinite inputs, invalid times, impossible delivery before the
zero event, aggregate over-delivery and arithmetic overflow. Output arrays
are zero and status is nonzero on rejection. Relative roundoff allowance
is64 machine epsilons, not an added nitrogen supply.

Fresh O0/O2 native tests call this source together with the real production
finite-donor core. Independent ODE/event and individual/totals assertions
cover108 depletion cases per optimization. A separate native contract covers
56 valid cases and9 negative cases at each optimization, including large/small
scales, zero/single requests, tau=0/tau=dt, overflow and NaN. All pass.
Compile+native+ODE execution is a small local test; full FCI/highest low-air
and RossFast are not selected for this unactivated process candidate.

Remaining admission work: explicit opt-in daily interface, separate top/crop
receipts throughout NH4 and NO3 demand/supply selection, current actual crop
composition, mass/restart/rejected-state proof and owner reconciliation.
Organic immobilisation and its organic pools remain outside this contract.
No current whole NUT preservation/admission is claimed for this branch.
