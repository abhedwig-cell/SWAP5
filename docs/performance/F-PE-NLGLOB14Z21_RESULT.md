# F-PE-NLGLOB14Z21 result — long-horizon bidirectional persistence to 13:16 -> 14:16

Date: 2026-09-30

Status:

`QUALIFIED_Z21_BIDIRECTIONAL_PERSISTENCE_TO_13_14`

Qualification authority:

- workflow run: `36706551237`;
- HEAD fine segment-B job: `109861094550`;
- RUNOFF fine segment-B job: `109861094578`;
- workflow conclusion: SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Research postimage before result persistence:

`research/f-pe-nlglob14z21-long-horizon-bidirectional@2270b5879d5ad1c1dabb3625d37d8544b2e6c810`

## Frozen question

After the qualified Z20 five-change finite chatter transient, does unchanged exact accepted-state bidirectional ownership remain coherent over the long interval to the independently qualified physical retreat:

`13:16 -> 14:16`?

## Aggregate result

PASS.

Both frozen fine O05 fixtures classify:

`BIDIRECTIONAL_PERSISTENCE_TO_13_14`.

Therefore the frozen aggregate classification is:

`QUALIFIED_Z21_BIDIRECTIONAL_PERSISTENCE_TO_13_14`.

## HEAD fine

The qualified Z20 local transient is reproduced exactly:

1. retreat at offset 1;
2. reverse at offset 2;
3. retreat at offset 3;
4. reverse at offset 4;
5. retreat at offset 5.

The trajectory then remains at accepted tail:

`13:16`

for 4,058,834 further accepted nominal intervals without any ownership change.

The first later ownership change is the exact target retreat:

`13:16 -> 14:16`

at:

`514.6110625 d`.

Diagnostics:

- total post-reverse ownership changes: 6;
- target ownership-change offset: 4,058,840;
- late recurrence before target: false;
- final accepted tail: `14:16`;
- max interval physical mass ledger: about `1.62e-9 cm`;
- max nonlinear residual: about `1.00e-10`;
- max rollback: 0;
- provider route: `surface-flux`;
- geometry remains contiguous and one-face.

## RUNOFF fine

The same five-change Z20 transient is reproduced:

1. retreat at offset 1;
2. reverse at offset 2;
3. retreat at offset 3;
4. reverse at offset 4;
5. retreat at offset 5.

The trajectory then remains at accepted tail:

`13:16`

for 4,058,839 further accepted nominal intervals without any ownership change.

The first later ownership change is the exact target retreat:

`13:16 -> 14:16`

at:

`514.6081875 d`.

Diagnostics:

- total post-reverse ownership changes: 6;
- target ownership-change offset: 4,058,845;
- late recurrence before target: false;
- final accepted tail: `14:16`;
- max interval physical mass ledger: about `1.49e-9 cm`;
- max nonlinear residual: about `1.00e-10`;
- max rollback: 0;
- provider route: `surface-flux`;
- geometry remains contiguous and one-face.

## Relation to independent control evidence

Previously qualified fine control retreat times were approximately:

- HEAD: 514.66475 d;
- RUNOFF: 514.6615625 d.

The bidirectional split trajectories therefore reach the same physical retreat topology slightly earlier:

- HEAD difference: about -0.0536875 d;
- RUNOFF difference: about -0.0533750 d.

These time differences are descriptive only. They are not ownership triggers and were not used by the harness.

## Scientific interpretation

The immediate bidirectional chatter found in Z19 and characterized in Z20 does not recur over the long stable interval to the next physical retreat.

For both fine fixtures:

- exact accepted-state bidirectionality remains transactionally valid;
- the local five-change chatter self-settles;
- ownership remains stable for more than four million accepted fine-dt intervals;
- the next ownership event is the physically expected one-face retreat to `14:16`;
- no hysteresis, dwell time, fitted threshold or event suppression is required to obtain that behavior.

This materially strengthens the case that the no-hysteresis bidirectional accepted-state semantics are physically coherent in this local moving-interface regime.

It does not yet establish production suitability. The remaining production question is dominated by architecture, execution cost and broader fixture coverage rather than demonstrated persistent chatter.

## Qualified claim boundary

Qualified:

`QUALIFIED_Z21_BIDIRECTIONAL_PERSISTENCE_TO_13_14`.

Established for the two fine O05 fixtures:

- Z20 finite chatter transient reproduces;
- no late recurrent chatter occurs before the next physical retreat;
- exact bidirectional accepted-state ownership persists coherently to `13:16 -> 14:16`;
- mass, residual, rollback, provider and one-interface geometry gates remain valid.

Not qualified:

- coarse-dt bidirectional persistence;
- broader material/profile portability;
- later retreat beyond `14:16`;
- saturated-tail disappearance;
- whole-column TG re-entry;
- production temporal ownership;
- production acceptance of transient chatter cost;
- event coalescing or anti-chatter state machines.

## Consequence

Do not introduce hysteresis solely to solve the Z19 chatter phenomenon.

The next safe research question is to determine whether the same exact bidirectional semantics remain valid beyond `14:16`, including eventual tail disappearance, and whether the local five-change transient has material execution cost or coupling-side consequences in a production-shaped implementation.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
