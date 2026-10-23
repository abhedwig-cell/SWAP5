# Bounded joint water/FCT acceptance

The isolated research wrapper now withholds the real water candidate until the
complete FCT chemical batch passes. It reconstructs carrier faces directly from
the real backend's accepted substeps. Failure discards the candidate; no low-order
or valid chemical prefix is published. Production code and defaults are exact.

Fresh checked O0/O2 execution on canonical drainage backend `c459429a`:

- 24 cases, 2,292 accepted primary-path substeps, 96 committed windows.
- 480 rejected trials: 96 late unsupported-decay requests after valid chemical
  prefixes, 96 incomplete water trials, and 288 schedule/clock/carrier rejections.
- All 96 valid retries exactly match independently run reference transactions.
- 48 continued windows exactly match the public opaque kernel persistence restore
  plus chemical value checkpoint; physical fields, derivative history, clock,
  lineage, revision, chemical stores and per-window ledgers are compared.
- Full stdout is byte-identical between O0/O2. Maximum independently checked
  mass residual is `1.3639099005475878e-14 mg/cm2`; positivity, local equilibrium
  and concentration bounds pass.
- Current composed scientific owner and 36 source/raw controls pass. The new
  source-bound capsule passes eight additional adversarial controls.

The real source closure is 172 providers; current compilation/execution took
88.312 seconds. The pre-drainage 24-case proof is retained and all endpoint
records are exactly reproduced on the new shared backend. Scanner startup,
compiler-path setup failure and missing explicit driver imports are retained as
failed development rounds, not successful scientific executions.

This establishes bounded in-process joint rejection/acceptance and in-memory
continuation, not a crash-consistent two-state publish protocol, disk encoding,
fresh-process native restart, general coupled PDE accuracy, dispersion/decay,
sink composition or production activation. The 96 unsupported-decay rejections
are fail-closed tests, not qualifications of decay physics. Native/disk/process
integration remains the next dependency before any production activation.

`CONTRACT.md`, `MEASUREMENTS.json`, `CURRENT_RECONCILIATION.json` and
`EVIDENCE_INDEX.json` own scope, results, current-source delta and raw inventory.
Run `python integration/mc-sol01/fct_joint_acceptance/verify.py --self-test`.
Actual canonical admission is a separate receipt; qualification alone is not
admission and does not promote the master SOL capability.
