# PPA-WU05-A27-PERF04 preregistration — exact run-trial surface hydraulic memo

Date: 2026-10-02
Status: PREREGISTERED_BEFORE_IMPLEMENTATION
Parent: `7d1f85d8c34a99b0e70420cac95dd21194bb45be`

PERF03 run 37001874665 establishes bitwise equality of default-MvG surface sorptivity and point conductivity across trial durations 0.01 through 0.000625 day for B01/O05 and four groundwater states.

PERF04 may memoize the production surface hydraulic pair only within one serialized-backend `run_trial`.

Key:
- exact accepted surface pressure head;
- exact accepted surface water content;
- RFM sorptivity panel count.

The memo must not be physical state, restart state, checkpoint state or accepted continuation state. It is disposable worker scratch. It is cleared at entry and exit of every `run_trial`.

A memo hit is allowed only when the exact key matches. Any changed accepted substep state is a miss.

Authorized implementation:
- activation binding may accept an optional precomputed surface conductivity/sorptivity pair;
- live preparation may receive optional memo scratch and update it only after a successful ordinary hydraulic evaluation;
- serialized RFM execution may pass its run-trial-scoped scratch into live preparation.

No tolerance-based key, cross-run reuse, panel reduction, constitutive approximation or physical change is allowed.

Qualification:
1. A26 live preparer, backend preservation and A8 preservation pass.
2. Dedicated memo test proves first call 65 demand calls, identical-key second call 0, changed-head call 65, and run-trial reset semantics.
3. Full qualified ABC01 rerun preserves B>=29/32, C>=30/32 and all joint cases E1.
4. All 96 non-wall-time raw records match the qualified PERF02 comparator exactly.
5. Repeat timing. No minimum speedup gate.
