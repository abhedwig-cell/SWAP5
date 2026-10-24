# PERF01 runoff-shift interpretation,24 October2026

Follow-up on the same pinned raw481-day zero-tracer runs. No new model run,
production change, tolerance change or admission. The strict daily0.01mm
comparison failure remains recorded. It does not by itself demonstrate a
practically important runoff defect. The preceding broad non-usability conclusion
was stronger than the measured hydrological consequences support.

Reference total runoff is691.37624853mm. No variant changes any day's exact
zero/nonzero runoff occurrence. Independently reconstructed whole-period water
closures remain below1e-9mm. Positive original chemistry remains outside scope.

| Variant | Final cumulative runoff difference,mm | Max cumulative difference,mm | Max daily difference,mm |
| --- | ---: | ---: | ---: |
| Retained water/flux | -0.06710514 |0.06710527|0.05679390|
| Plus dry-head safeguard |0.00280259|0.01848250|0.01687283|
| Plus complete incumbent assessment |-0.00032784|0.01636488|0.01687283|

Even the fastest variant's total runoff discrepancy is approximately0.0097% of
reference runoff. This ratio is a whole-period result; it does not bound relative
errors on tiny individual events or prove equivalence outside this input.
The conservative variant's largest daily discrepancies occur in opposite-signed
pairs: day340 +0.01687283mm, day343 -0.01685117mm; day302 +0.01178999mm,
day303 -0.01178631mm. They largely redistribute output between days.
Its final storage discrepancy is0.00000517mm. The fastest variant has a persistent
small total-runoff difference, so not every discrepancy is a pure time shift.

Interpretation: on these measured water-only consequences, practical relevance
is far less concerning than the binary strict daily screen implied. A broader
production release still requires explicit owning qualification, the numerical
contract's acceptance disposition and positive-chemistry exclusion. Do not
silently relabel the strict failure PASS. The next implementation/admission phase
should assess the actual intended water-balance/runoff requirements rather than
continue adding costly temporal safeguards solely to chase0.01mm on one day.

Reproduction: analyze_perf01_runoff_shifts.py binds all six input CSV hashes,
reports daily/cumulative discrepancies and event occurrence, and independently
reconstructs period balance from storage and gross input/output columns. Raw
inputs remain in the immutable historical evidence capsule.
