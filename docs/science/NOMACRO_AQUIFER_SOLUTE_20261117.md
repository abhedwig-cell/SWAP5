# Bounded original mixed aquifer solute correction

**Implemented and tested work-unit scope; canonical admission is separate.**
Historical functional closure remains PARTIAL, whole scientific equivalence
NOT_QUALIFIED, and release qualification limited to the named RC2 profiles.

## Original defects and explicit correction

Original SWBR=1 selects a constant-volume mixed saturated reservoir. Actual
original Hupsel execution with bounds checking at O0/O2 accesses element35 of
an array of length34 after the soil loop. Without checking, the original
executable reports normal completion over1096days but emits5480 nonfinite
solute values. Normal completion is therefore not a scientific oracle.

Correcting only the index leaves another demonstrated defect: the original
update treats cumulative drainage mass as a rate and multiplies it by elapsed
time again. It also records surface export using the updated concentration
although forward Euler removes mass at the previous concentration. The actual
index-only diagnostic has a daily compound imbalance of0.68968mg/cm2 despite
a closing soil-only ledger. Its raw failure remains evidence, not a reference.

The corrected storage coefficient uses the bottom soil compartment:
`capacity = (porosity + bottom_bulk_density * KFsat) * aquifer_thickness`.
Positive sorption requires the original bottom bulk density. The shared pure
production provider is `src/process/mod_aquifer_solute_reservoir.f90`.
For each microstep it accepts the current signed soil drainage mass rate,
positive net drainage water export and decay rate. It retains original forward
Euler concentration arithmetic and reports soil input, previous-concentration
surface export, decay, stock and residual. Invalid candidates leave its result
unchanged. There is no concentration clipping.

The explicit numerical policy limits the interval to
`0.9 / (outward_water_loss / capacity + decay_rate)`, in addition to the existing
soil/time limits. Outward water includes return flow from the reservoir into
soil compartments and positive net surface drainage. The factor0.9 is a
positivity/stability policy; it does not qualify an accuracy tolerance. No loss
gives an unrestrictive finite limit. Physical options and this numerical policy
have distinct build identities.

The original constant-volume assumption, including implicit fresh-water
replacement for negative net drainage, is retained. Original soil bottom flow
remains an external boundary whose seepage concentration derives from the
reservoir. This does not implement general aquifer water dynamics or MODFLOW.
Active macro execution is excluded; its original equation body is preserved.

## State, coupling and preservation contract

`app/hybrid_water/conserved_aquifer_solute.py` selects the correction only for
experimental no-macro chemical SWBR=1 projects. The builder composes it with
the admitted chemical SSDI correction when selected. The ordinary soil ledger
is preserved. Additional daily guards independently check reservoir storage,
soil-to-reservoir transfer, and the combined soil/reservoir mass balance against
the unchanged absolute1e-10mg/cm2 bound, before kernel acceptance.

The native owner adds concentration, capacity, stock, cumulative soil input,
surface export, decay and loss-limited step count. Restoring checks finite/domain
values, unchanged capacity, stock consistency and exact accepted receipt; it
restores both private concentration and its derived seepage concentration.
The new native fields and generated source are absent when SWBR=0. Rejected
days cannot modify committed water, soil or reservoir state.

## Selected evidence and limits

- Independent real production driver at O0/O2 covers units, conservation,
  signed return flow, decay, zero time, loss limits, A/B/A independence,
  invalid domains, nonfinite values, overflow and output nonmutation.
- Corrected original O0/O2 reference: eight complete1096day periods for soil
  transfer, initial reservoir release, sorption/decay and strong losses. Two
  additional index-only periods expose the legacy time/ledger defect. Raw
  seven-field reservoir and nine-field soil observations support the balances.
- Windows and Ubuntu real SWAP5 host: the same eight full periods per platform,
  strict water/soil/reservoir/compound guards and32 exact physical/CSV/native
  restart windows per platform, including the year boundary. Strong losses
  actually activate the new interval limit.
- External adoption, discard/replay and disk recovery are exact at O0/O2 on
  both platforms. Deliberate candidate corruption preserves committed state;
  two independent origins execute six interleaved steps per optimization.
- Windows additionally refuses fourteen actual invalid input executions and
  eighteen actual damaged native-state executions. Separate full O0/O2 SSDI
  compositions inject48mg/cm2 and retain exact active/year native windows.
- Thirteen fresh admitted contexts preserve all generated Fortran, provider,
  flag and input closures and exact physical/CSV/native prefixes. Unchanged
  full periods are not rerun or presented as fresh qualification.

The corrected original and SWAP5 full trajectories are finite and conservative
but are not identical. The maximum observed reservoir stock differences reach
approximately0.00645mg/cm2; the strong-loss step counts differ by242. These are
recorded as unresolved numerical differences, without a fitted tolerance or
an asserted cause. Source conservation, bounded positivity, state semantics
and the tested functional scope do not establish whole-model scientific
equivalence, convergence accuracy or all historical option combinations.

Machine-readable scope, raw archives and admission are maintained separately
under `integration/f-ci/nomacro-complete01/AQUIFER_*`. The actual immutable e677
predecessor consumer remains the authority for the scheduled/fixed/S/pulse/R
chain. The successor must preserve that chain and bind this new production
surface to the executed evidence; source changes require new qualification.

```text
python -B tests/nomacro_scheduled_subsurface/aquifer_ci.py --reference-work PROVIDER --output PROOF
python -B tests/nomacro_scheduled_subsurface/aquifer_native_controls.py --evidence RUNTIME --input-root INPUTS --reference-work PROVIDER --output REFUSALS
python -B tests/nomacro_scheduled_subsurface/aquifer_composition.py --input FIXED_INPUT --reference-work PROVIDER --output COMPOSITION
```
