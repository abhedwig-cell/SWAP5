# F-PE-NLGLOB13 result — near-saturation TG subdivision

Date: 2026-09-29

Status:

`CLOSED_TG_NEARSAT_SUBDIV2_INSUFFICIENT`

Canonical base:

`integration/f-ci-canonical@ab151e5dcc3054f8be2bc0d7a25f905e44395f96`

Qualification authority:

- workflow run: `36554573296`;
- job: `109360584755`;
- conclusion: SUCCESS.

## Frozen candidate

NLGLOB13 tested one-level event-local temporal subdivision for TG near-saturation admissibility.

The full nominal TG probe used the order-preserving NLGLOB11A head-space endpoint coefficient stage. If the prospective accepted TG moisture state left the retention domain, the nominal trial was rejected and the interval was retried as two conservative TG halfsteps of `h/2`.

The full dynamic bank retained the preregistered S0 research replay rule unchanged. R0 was deliberately excluded from the qualification run so subdivision could be attributed independently.

No accepted theta clipping, recursive subdivision, tolerance change or production source change was introduced.

## Smooth preservation bank

PASS.

The smooth TIMEINT16C bank remains strongly second order:

- median refined top-head order: `2.04787`;
- median refined top-theta order: `2.04787`;
- median deterministic work ratio versus KLAG BE: `1.0`.

Thus the temporal-order authority itself is preserved.

## Full dynamic bank

Completed requested horizon:

`79 / 96 = 0.82292`.

Physical mass remains near roundoff:

- max accepted-interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`.

No process failures occurred.

S0 acceptances:

`1255`.

R0 representation-floor replay was not active in this isolated qualification run.

## Near-saturation target bank

The seven frozen O05/TG HEAD/RUNOFF target trajectories do not complete:

- target cases: 7;
- completed: 0/7;
- successful completed subdivision events: 0.

All seven targeted trajectories fail the one-level subdivision attempt; the isolated classifier records 0/7 completed target cases and 0 successful completed subdivision events. The wrapper reports `NEARSAT_SUBDIVISION_FAILED` for the failed subdivision attempts.

The physical state remains finite and prior accepted intervals remain mass-clean.

## Frozen classification

`CLOSED_TG_NEARSAT_SUBDIV2_INSUFFICIENT`.

The one-level subdivision candidate does not qualify.

## Interpretation

The failure is not due to loss of smooth temporal order or physical mass. Representation-floor R0 replay was not active in the isolated run and therefore is not part of this attribution.

The near-saturation temporal problem survives one conservative subdivision level.

At least one of the two halfsteps in each target interval remains inadmissible or otherwise fails before the nominal interval can be committed.

NLGLOB13 does not identify which halfstep failure class dominates because the preregistered candidate only required fail-closed rollback.

## Consequence

Do not add recursive subdivision inside NLGLOB13.

Open a separately preregistered attribution workunit that records, for the seven target trajectories:

- whether halfstep 1 or halfstep 2 fails;
- whether the failure is accepted-state retention-domain, endpoint nonconvergence, route mismatch, ponding failure, or another explicit terminal reason;
- the halfstep dt and accepted state immediately before the failed halfstep.

Only after that attribution may a deeper temporal subdivision or a different near-saturation temporal construction be proposed.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
