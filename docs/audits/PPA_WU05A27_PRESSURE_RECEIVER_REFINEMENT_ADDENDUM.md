# PPA-WU05-A27 pressure-aware receiver refinement addendum

Date: 2026-10-02. Status: PREREGISTERED_AFTER_RETAINED_GATE_FAILURE.

The original pressure-receiver contract remains failed at its preregistered matrix-refinement gate. Run 36975724320 produced, for dt 0.01, 0.005 and 0.0025 day, final matrix storages 39.953576257981915, 39.982575014322350 and 39.993499100623019 cm. The successive differences are therefore about 0.028999 and 0.010924 cm; the second remains above the original 0.005 cm gate. Final receiver storage already differs by only about 2.70e-5 cm between the finest two runs, and maximum combined ledger error is below 8e-15 cm. Both signed directions and multiple contact changes were exercised.

This addendum does not relax or reinterpret the failed gate. It asks whether the failure is consistent with an explicit accepted-state-frozen split that is still converging at the tested step size.

## Frozen continuation

Keep unchanged:
- B01 physical MvG parameters;
- receiver area fraction 0.05 and 100 cm depth;
- signed exchange primitive and cdarcy = 5e-4;
- water table, bottom boundary and zero top flux;
- receiver initial storage and fill/drain/rewet pulses;
- exact source/sink and receiver ownership;
- Reference solver tolerances.

Extend only the timestep sequence with 0.00125 and 0.000625 day.

## Gates

All original per-step mass, ownership, sign, contact and reject/replay gates remain active.

For matrix storage, let d12 ... d45 be absolute differences between successive timestep results from 0.01 through 0.000625 day. Require:
- d23 < d12;
- d34 < d23;
- d45 < d34;
- d45 <= 0.005 cm.

Require final receiver difference between the two finest runs <= 0.001 cm.

A pass means only that the research seam has a converging explicit-split execution under this stress case and that smaller/subcycled steps are a credible numerical remedy. It does not retroactively pass the original gate, qualify a production timestep bound, or admit signed exchange into production RFM.
