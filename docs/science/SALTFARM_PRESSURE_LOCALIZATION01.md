# SaltFarm pressure platform localization

Scope: numerical localization under the admitted named no-macro daily policy,
not scientific equivalence or a new pressure acceptance limit. The unchanged
full1461 trajectories from run43422771039 are reused. No application or kernel
source is changed. Frozen RC1 and original failed scientific criteria remain.

## Distinguishing question and prior evidence

The matched Windows/Ubuntu daily records have a maximum pressure difference of
0.0018243055500306582 cm on day1009 (2014-10-05), deepest zero-based slot194.
The maximum over the entire preceding1008 days is only2.2737367544323206e-13 cm.
The day1009 endpoint is874.767643025579 versus874.769467331129 cm; the preceding
endpoint is874.9993226024974 cm on both platforms. Subsequent pressure differences
decrease, with the final1461 endpoint again at rounding scale. Neither platform
records a day-level budget retry on day1009. Thus this is an isolated discontinuous
branch event, unlike the previously resolved Hupsel interday amplification.
These values describe observations;1e-12 is a localization cut, not an acceptance
criterion. The full records, hashes and selected window are in OFFLINE.json.

The original SaltFarm input retains SWBOTB3, DTMAX0.04, DTMIN1e-6,
NUMBIT_CRIT3 and all original convergence settings. The read-only observation
adds writes around original convergence, strict mass decision and accepted-step
recording; CSV writes expose original head/theta/iteration histograms. No
numerical feedback or physical expression is changed. The original per-OS
compiler-identical provider and objects are reused from run43422771039; only the
two observed files are compiled and linked to a private executable. The supported
BUILD and restart identities are not replaced, and no foreign restart is loaded.

Exactly one paired native-prefix probe is selected: cold start through1009,
trace only1009, then assert that all1009 daily heads/stocks/flows/uptake are exact
against the saved result for that same platform. Each native invocation is capped
at60 seconds. A full1461 rerun or broad reference campaign is not selected.
The local GNU16.2 observer already preserves its own complete1009-day prefix
exactly; native8.335s and unchanged water/solute guards pass. This is a private
observer validation, not a new supported build qualification.

```text
python -B tools/solute/trace_hupsel_pressure.py --project saltfarm --output PROOF
  --reference QUALIFIED/provider --bundle QUALIFIED/saltfarm-O2-candidate-build
  --full QUALIFIED/saltfarm-O2-candidate-full --first-trace 1009 --last 1009
```

Pass the command on one line. Reuse is allowed only when the observer's compiler hash and floating-point
profile match the recorded provider. Hosted selection43550642328 uses the exact
carrier8ea0a4ee4555fedb1d6ced7acf40ecfa0aafff4e; the registered carrier workflow
is excluded from the clean development branch. Results are owned by
`integration/f-ci/saltfarm-pressure-localization01`.


## Completed paired observation and decision

[Run43550642328](https://github.com/abhedwig-cell/SWAP5/actions/runs/43550642328)
completed SUCCESS on both platforms. Native Windows/Ubuntu costs were3.986s and
3.371s; compiler setup, separately, dominated Windows wall time. All1009 daily
heads/stocks/flows/uptake were exactly preserved against each original saved
platform trajectory. Full original native frames, traces, private generated
sources, executable and commands are in the digest-verified raw artifacts.

The first discrete split occurs at original day1009 time41916.119, minute171.36.
Original Richards convergence at iteration2 is the same on both sides. The strict
mass decision, however, compares accumulated residual plus step residual against
`1e-10*(t1900-budget_start+dt)`. The transmitted trace values and binary-computed
threshold are in COMPARISON.json. Windows is just outside this limit while Ubuntu
is just inside, a difference at roughly1e-15 cm. Consequently Ubuntu marks
`mass_polish_at=2`; Windows first marks it at3. The existing extra original Newton
iteration yields accepted iteration counts3 versus4. Original NUMBIT_CRIT3 then
doubles the following Ubuntu step to0.034d while Windows retains0.017d. This is
the first causal control-path divergence; subsequent differences in head are
therefore not evidence of different physical formulae. The observed pressures
and existing guards are not reclassified as a scientific PASS.

**Disposition:** rounding-sensitive strict-mass polishing with adaptive-step
feedback. No incorrect comparison, state leakage, balancing flux or ignored
tolerance has been demonstrated. No production patch is selected in this packet.
In particular, inserting an arbitrary extra iteration, rounding the guard or
loosening the gate would merely tune this example. The real question for any
future repair is whether original physical-convergence iterations and auxiliary
strict-mass polishing should own distinct controller counts. That changes a
numerical-policy contract and requires explicit source-level justification and
qualification; it cannot be silently presented as preserving actual NUMBIT
feedback. Current actual-count behavior, input, physics, rejections, all limits
and broader scientific limitations remain intact.

Next bounded objective: inspect that original-count versus guard-polish ownership
and decide on the numerical policy before any additional model experiment.
A second similar trace or a repeated full trajectory is not selected.

The subsequent [bounded physical-growth policy](PHYSICAL_ITERATION_POLICY01.md) implements and qualifies the explicit SaltFarm successor; the original localization and failed universal-policy attempt remain preserved.
