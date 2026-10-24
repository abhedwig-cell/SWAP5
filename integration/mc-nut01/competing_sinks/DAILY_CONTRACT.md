# Juvenile daily opt-in proportional partition candidate

The explicit forcing field proportional_constant_sinks defaults to false.
It requires signed-top mode, active juvenile crop and nonnegative net mineral
production. Nonjuvenile demand/supply selection and organic immobilisation are
outside this first daily domain and reject when the option is requested.

The finite-donor core receives mineralisation/nitrification as positive sources
and the sum of gross constant crop and top requests as its sink. Netting crop
demand against mineralisation before partitioning would incorrectly change the
sharing proportions. Concentration-dependent root uptake and reactions retain
their original integrated equations. NH4 is evaluated first, with its actual
uptake subtracted from the crop request passed to NO3. Actual top receipts and
unmet top amounts remain separate from crop uptake. The external ledger uses
actual top extraction, not the original prescribed request after depletion.

Current native O0/O2 evidence:1152 paired-form daily opt-in cases, independent
DOP853 concentration/zero-event and individual receipt checks, strict whole-N
balance;1344 incumbent signed/default executions byte exact per optimization;
five unsupported-domain rejection cases per optimization. Expected local cost
under30 seconds. Source and assertion bodies of incumbent drivers unchanged;
the generated wrapper activates the new forcing field explicitly.

Component and research capsules retain their earlier qualification scopes.
DAILY_STATUS.json and DAILY_EVIDENCE.tar.xz.b64 own this daily evidence.
This is not an actual Richards/crop runtime or restart qualification. Pending:
ordered compile closures including the new module, runtime option propagation,
actual coupled crop/restart/rejected-state tests, all owning preservation gates
and exact canonical merge validation. PR1422 stays draft. Production defaults
are unchanged; no complete NUT admission or preservation is claimed.
