# MC-NUT01 bounded B1.11 reproductive and death process

Status: proposed implementation after source assessment PR1259 and independent
balance review. Baseline canonical71551d19d7f9a5e973d2deff5347049174502cbf.
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
