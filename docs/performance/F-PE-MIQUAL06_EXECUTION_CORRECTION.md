# F-PE-MIQUAL06 execution correction — run 36823480403

Date: 2026-10-01

Status: `EXECUTION_INVALID_BEFORE_RUNTIME_EXPOSURE`

The first MIQUAL06 qualification run failed during compilation of the new runtime adapter, before the serialized runtime gate executed.

Observed compiler error:

- pointer assignment to `reduced_constitutive` and `reduced_source_sink` failed because those adapter-owned providers were not pointer/target objects.

Correction boundary:

- make the two adapter-owned provider objects pointer-owned scratch and allocate/release them explicitly;
- do not change the frozen runtime eligibility envelope;
- do not change moving-interface physics, reconstruction, numerical tolerances, fallback rules or test fixtures.

Run `36823480403` is build-invalid and provides no scientific or runtime qualification evidence.
