# PPA-WU05-A26 result — bounded live RFM serialized backend

Date: 2026-10-01
Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE
Qualified postimage: 836d5f8d5d001e0fa45eb838401abd1a9df86785
Qualification run: 36910084764 — SUCCESS

Focused markers:
- PPA_WU05A26_ZERO_RFM_LIMIT=PASS
- PPA_WU05A26_TIMESTEP_REFINEMENT=PASS
- PPA_WU05A26_LIVE_TRIAL_PREPARER=PASS
- PPA_WU05A26_BACKEND_STATIC_BINDING=PASS
- PPA_WU05A26_BACKEND_RUNTIME_O0=PASS
- PPA_WU05A26_BACKEND_RUNTIME_O2=PASS
- PPA_WU05A26_BACKEND_COMPILE_GATE=PASS

The serialized Reference backend invokes the qualified RFM live-trial preparer in the same postimage in which the A20 NOT_ADMITTED guard is replaced.

Bounded route: explicit caller-owned RFM configuration/forcing; unponded runoff-free B1.10 flux regime; Reference Richards only; standard SWAP macropore mutually excluded; accepted-state frozen first-order split; hydrostatic IC exchange through A26J/K+A22A; IC matrix receipt only through A24; leading fast-through MB as distinct deep receipt with no passage wall exchange.

Checkpoint preservation, zero-RFM limit, timestep-refinement contraction, accepted-state immutability/replay, and O0/O2 preservation are qualified.

Earlier A26 blockers were resolved by canonically admitted A26H, A26J and A26K plus the A26I source-backed route correction. Failed runs before 36910084764 were harness/compile defects and did not falsify physics.

This remains an explicit first-order operator split, not a monolithic nonlinear RFM/Richards solve.

Decision: A26 is a qualified production-admission candidate. Next: canonical admission and post-merge preservation.
