# MC-NUT01 bounded B1.11 reproductive and death process

Status: qualified bounded implementation and affected O0/O2 physical science;
34 fail-closed controls, both actual owner entrypoints and strict docs pass.
Canonical admission pending. Source assessment PR1259 and independent balance
review remain the authority for selecting these literal source laws. Baseline canonical71551d19d7f9a5e973d2deff5347049174502cbf.
Owning recovery: `integration/audits/MC_NUT_SOL_STATUS.json`.

Implement literal B1.11 demand354..370 and update197..255 from the immutable
wofostnut.f90 SHA071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2.
Exactly one day is selected, matching the existing daily crop/Soil-N owner.
The new option is explicit and mutually exclusive with the unchanged vegetative
PR1253 request. WOFOST81 stays default. Retain the sole existing committed organ
N and cumulative uptake/fixation/loss ledgers, soil inventory and pending material.
A private prepared process value is tentative scratch, not a new mass owner.

DVSNLT, DVSNT, NFIXF and FNTRT are explicit immutable source-policy fields.
Existing configured maximum organ concentrations, residual concentrations and
TCNT remain their sole parameter authority. No growth demand or direct storage
uptake is added. Storage demand is divided by TCNT once, independent of the
vegetative uptake gate. Root donor uses the literal max of the FNTRT share and
actual residual surplus. Death uses configured residual concentration times
actual organ death dry matter. Preserve source evaluation/partition order.

Input domain: finite nonnegative organ DM<=1e8kg/ha, organ/cumulative N<=1e9kg/ha,
concentrations/fractions<=1, DVS and source stage thresholds in[0,2], RELTR in[0,1],
TCNT in[1e-6,1e3]days; organ death cannot exceed its before-step DM. All bounds
precede arithmetic and IEEE comparisons. Use the existing2048epsilon crop-N
balance authority; no new tolerance or source correction.

Separate prepublication checks must forbid three structural failures: positive
unallocated uptake in the source <=1e-5 vegetative-demand band; positive storage
credit with no donor partition at total translocatable N<=1e-5; and any negative
living-organ value before literal max(0,x). Check uptake and translocation
allocation independently, so opposite errors cannot cancel in a net residual.
Reject unsupported inputs atomically; do not clip donors or invent extra N.
Maintain complete crop N and existing whole soil+crop/pending balances.

Use existing daily trial/commit, soil actual supply, and accepted clock/revision.
Selected policy is appended as an explicit tagged configuration suffix; absent
policy must leave default and1253 native vectors and bytes exact. Reuse existing
opaque/native readers, configuration identity and no-overwrite rejection, with
no second codec or sidecar. Actual death N can pass to the existing full-return
pending-material route; this does not admit the historical partial-leaf return
fraction, harvest mapping or complete historical crop growth/activation.

Select small real process O0/O2 with immutable literal oracle, source gates and
cutoffs, multi-organ donors, limited/exhausted supply, simultaneous death,
independent allocation guards and strict preclipping nonnegativity. Then select
real daily crop/Soil-N, native/opaque fresh-process identity, rejection/retry/replay,
configuration mismatch, affected actual Richards and existing default/1253
programs. Record compile/link/native costs. Reuse build products only within an
identity-controlled execution. No full FCI, unrelated Richards/RossFast or highest
low-air qualification is selected solely for source imports or new valid inputs.
No full historical capability/count promotion follows from this bounded option.


## Executable bounded evidence

The persisted execution4117743b606f86b890fb997b238e97e04add2b65 passes the small
real two-provider process and the actual crop/Soil-N binding. The small corpus
accepts2083 and refuses23 cases per optimization. Independent review da6f5657
adds logarithmic organ/TCNT and prior-loss probes; it does not extend runtime
admission by itself. The existing aggregate loss ledger keeps its representation;
comparison with historical separate-organ accumulated losses uses the existing
2048epsilon budget authority.

The affected physical build runs72 literal daily cases per optimization, actual
Full Richards/material/source N and delayed full-return pending incorporation,
rejected trials, duplicate clocks and continuous/opaque/native fresh-process
continuation. All four selected policy values, absent policy and the separate1253
profile are refused when inconsistent with native identity. The default and1253
native endpoints/restarts remain byte-identical to the admitted1253 capsule.
Existing18 default crop decoder negatives remain executed. The active storage
threshold in the coupled fixture is explicit DVSNT=.4 at initial DVS=.5; the daily
matrix also tests DVS1.2 with consistent post-anthesis continuation. This qualifies
selected process/coupling contracts, not a complete historical crop trajectory.

Measured one full affected build:222.325s providers,47.003s driver compilation,
4.487s linking and190.721s native execution (464.535s total). The small direct day
feedback closure costs31.317s; no unrelated solver or full FCI run is selected.
Source-bound raw events, immutable literal blocks, rejected development fixtures,
complete original-body insertion projections and bytes are retained in the
owning `reproductive_process_20261016` science capsule. PR1260 is the bounded
production admission candidate; exact canonical merge identity is recorded in
that owner after admission.
