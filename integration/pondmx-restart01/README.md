# Scheduled pond maximum day restart repair

## Cause and bounded repair

On actual canonical d4ccdc7cb (PR1691), water/chemical hysteresis2 plus scheduled
pond/runon completed1096 days but failed exact native199to201 at both O0/O2.
The original variable variables.pondmx is not merely a time-table input: original
PondRunoff updates it only when called. Original BoundTop subsequently copies
that carried value into h0max. Initializing a new worker resets pondmx to0.2.
The v1 original-top codec preserved all eight MOD_top fields, but omitted this
external mutable dependency. It did not preserve the complete original owner.

A separately bound trace-only donor on aff4997f0 measured actual pondmx at199:
0.197938023450583 warm,0.2 cold. The unseeded199to201 reproduced the auxiliary
failure while physical rows and result.end stayed exact. Seeding only the ACTUAL
observed warm pondmx made BOTH native endpoints exact. No value was inferred
from h0max and no production capsule was rebound. RAW_SUPPORT retains the full
private source/compile/binary identity, traces and counterfactual result.

The existing top owner now has a selected v2 form for experimental SWPONDMX1
with hysteresis or snow. It saves/restores actual pondmx beside its six existing
real values, in the existing staged apply point after original initialization.
The version is2, record size80bytes (v1 is72). Clock, finite/domain, version,
trailer and flag checks precede assignment. New build/bundle metadata declares
original-top-scheduled-pond-history-v2 and its exact generator source. Missing or
foreign metadata and old-source checkpoints refuse; old state is never rebound.

Original physics, call order, model time, tables, forcing, iteration policy and
water/solute limits are unchanged. The unselected v1 emission is BYTE EXACT.
No active-macropore, MODFLOW, crop, oxygen or physical-energy claim is added.

## Qualification

Runtime4156596c70460a849892d1d81fd69853bf68f50c has the persisted repair.
Actual Windows tests pass:

- Native original top component O0/O2: exact80-byte roundtrip, staged assignment
  and ten refusal controls per profile, including old version, invalid clock,
  negative/nonfinite pondmx and stale application. Legacy v1 production driver
  O0/O2 passes unchanged; its emitted original source is byte exact.
- Both selected water/chemical configurations: short actual201 and exact199to201
  first; then full1096 at touched/controller O0 AND O2, immutable providerO2.
- All16 full physical/CSV/result.end/macro.bin own windows2to4,199to201,365to367,
  530to532 are exact, with unchanged origins. Old-source checkpoints and omitted
  policy metadata refuse. No differing bytes are skipped.
- Every complete forward physical row and CSV row is EXACT to the old complete
  source in PR1691, whose four native failures remain immutable.
- Maximum water1.6611712005953905e-13cm, solute2.1337792643905118e-13mg/cm2,
  against unchanged1e-10 limits. Full model/controller times5.29to7.91seconds;
  compile time is separately measured.
- Two fresh unmodified SWAP431 full1096 comparisons use identical executed
  input decks on the same laptop. Their existing numerical differences remain:
  maximum GWL2.706810392011cm, WTOT0.122125309420cm, chemical stock0.053796394726.
  This state repair does not change forward physics or qualify those differences.
- Fresh legacy-history/plate and all three registered builds retain every
  generated Fortran source and input byte. Binary identity is NOT claimed.
  Existing full unchanged periods are inherited only at that dependency surface.
- The complete old admission consumer was actually executed at d4ccdc7cb in a
  separate real detached worktree and passed. Its source/proofs and original
  tests remain unmodified. A literal current-entry forwarding hook selects this
  bounded new source and proof; it does not relabel historical guards.

QUALIFICATION.json is fixed by its SHA256 in tests/pondmx_restart/verify.py;
RAW_FULL/RAW_SUPPORT retain all raw payloads and member hashes. Test corruption
controls refuse weakened balance/native/source/legacy/science claims. The own
Ubuntu26.04 workflow independently repeats production components, all four full
periods/native windows and original431 comparisons before admission. Automatically
triggered unrelated broad frozen/kernel/performance workflows are NOT selected:
there is zero src/reference/tools delta and no change to physical algorithms.
The selected current F-CI source/proof check and dedicated runtime workflow must
finish; cancellation of unrelated jobs is never reported as numerical PASS.

Whole scientific equivalence remains NOT_QUALIFIED; prior oxygen, reference and
nominal-input failures remain explicit. Qualification covers the two reproduced
mixtures; it does not establish every unexecuted option combination.

## Reproduce

Use a source/compiler-validated original provider. All outputs must be fresh.

```powershell
python -B tests/pondmx_restart/component.py C:\SWAP5-RC2\provider <component-output>
python -B tests/pondmx_restart/qualify.py --reference-work C:\SWAP5-RC2\provider --output <full-output> --old-results C:\SWAP5-testing\nomacro-mixtures01
```

The old-results argument only compares prior complete physical rows and proves
old checkpoint refusal; it never imports/rebinds old native state. The baseline
hypothesis probe is bound to aff4997f0 and its pre-repair build, not current code.
