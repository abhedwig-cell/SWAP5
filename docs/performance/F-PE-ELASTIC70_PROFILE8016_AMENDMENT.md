# F-PE-ELASTIC70 — fixture representativeness amendment

Date: 2026-09-30

Status: PREREGISTERED_AMENDMENT_BEFORE_SECOND_RUN

Parent preregistration:
`F-PE-ELASTIC70_PRODUCTION_TRANSACTION_PERFORMANCE_PREREGISTRATION.md`

## Trigger

The first ELASTIC70 run used a synthetic two-layer generated-prior fixture.

Run:
`36739294914`

Result:
all four forcing cases completed at the initial dt under both 0.01 cm and
0.20 cm, with zero retries in both arms.

Therefore that fixture is too easy to answer the preregistered performance
question. The run is retained as a qualified negative fixture-sensitivity
result and is not counted as evidence for or against the 0.20 cm application
policy.

## Frozen correction

Before any second run, replace only the synthetic material/grid fixture with the
already characterized difficult GENERATED profile used in the ELASTIC68 bank:

- normalsoilprofile_id = 8016;
- exact frozen BRO/BOFEK artifact used by ELASTIC55/68;
- exact 16-node profile discretization used in the ELASTIC55/68 research bank;
- exact generated row-interchange preparation path.

Keep unchanged:

- h0 = -20 cm;
- forcing deltas -0.05, -0.035, +0.035, +0.05 cm/day;
- initial dt = 0.015625 day;
- budgets 0.01 and 0.20 cm;
- max retries = 8;
- production ELASTIC44 + ELASTIC65 composition;
- all deterministic gates;
- runtime remains descriptive only.

## Rationale

Profile 8016 is not selected from the failed first-run output. It is the
pre-existing localized difficult profile from ELASTIC61/66/67/68 and is the
appropriate production-transaction discriminator for the already admitted
application policy.

No production source or numerical tolerance may change.
