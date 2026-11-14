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
