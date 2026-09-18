# PUB-GC E1/E2 results — interface identity and transaction authority

## Status

**E1/E2 FIRST RESTRICTED PUBLICATION EVIDENCE BLOCK: PASS**

Date: 2026-09-18.

Canonical baseline at workunit start:

`integration/f-ci-canonical @ c42db098cc246e3da06472a34979bdf24cfa81cb`

Evidence branch head used for the successful PR run:

`0022e854000afe5a050303d9a0709f72b7dae518`

Primary workflow:

- `PUB-GC E1 E2 interface transaction evidence`
- GitHub Actions run: `35342313248`
- conclusion: **success**

Independent relevant preservation checks on the same head:

- F-GC44 real SWAP + live MODFLOW6 end-to-end: **success**
- F-VQ116 F-GC44 independent qualification: **success**
- F-GC42 live whole-window service: **success**
- Documentation: **success**

Some historical F-GC25 scope-guard workflows failed because they reject documentation paths already present in the current canonical/PR diff. Their logs report `*_SCOPE_FAIL unexpected path: .github/workflows/docs.yml`; they do not report a numerical or E1/E2 failure and are outside the PUB-GC evidence scope.

## Frozen envelope

The successful evidence is intentionally narrow:

- one real FMR/SWAP reference Richards column;
- one live MODFLOW6 6.8.0 groundwater cell;
- one coupling window of `1.0e-4 day` (= 8.64 s);
- near-equilibrium forcing/profile inherited from F-GC44;
- drainage, root extraction, macropore flow, snow and soil temperature disabled;
- analytic accepted-trajectory response;
- one accepted whole-window publication.

No broader hydrological generalization is claimed from this experiment.

---

## E1 — interface identity and conservation

### Predictor response values

The real predictor exposed:

| quantity | value |
| --- | ---: |
| `q_bot,predictor` | `1.0000000000000000e-6 cm/day` |
| `q_u` | `-9.6588521204796776e-7 cm/day` |
| coupling response `u` | `3.4029360372790930e-5` |
| storage start | `1.0430631535459627` native storage unit |
| storage end | `1.0430631535459627` native storage unit |
| storage change | `0` |
| total in | `1.0e-10` native amount |
| total out | `1.0e-10` native amount |
| canonical mass residual | `0` |

The F-GC30 reconstruction

```text
q_u =
  u * (H_end - H_start) * 100 / DeltaT_day
  - q_bot
```

passed at representation-scale tolerance.

The canonical mass identities

```text
storage_change = storage_end - storage_start

mass_residual =
  storage_change - (total_in - total_out)
```

also passed.

### Accepted corrector and interface ledger

The converged real coupling gave:

| quantity | value |
| --- | ---: |
| coupled iteration count | `2` |
| final head | `-0.71499996773317653 m` |
| final SWAP interface rate | `-1.2708557527755854e-13 m/s` |
| final MODFLOW interface rate | `-1.2708580747683645e-13 m/s` |
| final flux residual | `2.3219927791065243e-19 m/s` |
| final SWAP bottom outward amount | `-1.0980193703981059e-10 cm` |
| committed ledger exchange | `-1.0980193703981059e-12 m` |
| rate integrated over 8.64 s | `-1.0980193703981057e-12 m` |

Thus:

```text
ledger_exchange_m
  = final_bottom_outward_exchange_cm * 0.01
```

and:

```text
q_swap_public * DeltaT_s
  = ledger_exchange_m
```

within representation precision.

### Sign-hypothesis falsification and adjudication

The first preregistered execution, GitHub Actions run `35342179045`, failed because the preregistration expected the public rate and ledger amount to have opposite signs.

That expectation was wrong.

The code trace showed:

```text
qbot_mean_cm_per_day =
  - bottom_outward_exchange_native / DeltaT_day

q_swap_public =
  - qbot_mean_cm_per_day * 0.01 / 86400
```

so the two sign inversions cancel. The public outward-from-SWAP rate and the ledger's SWAP-outward integrated amount must have the same sign.

The production coupling code was not changed. The failed hypothesis and its correction are recorded in `PUB_GC_E1_E2_PREREGISTRATION.md`.

This is useful publication evidence because it demonstrates that the sign semantics were tested against the implementation rather than inferred from variable names.

### E1 interpretation

Inside this restricted envelope:

- `q_bot` and `q_u` are demonstrably not silently identical;
- the F-GC30 response reconstruction is internally consistent;
- the real SWAP trial publishes complete canonical mass accounting;
- the final accepted rate and committed interface amount are consistent under the explicit sign/unit conversion;
- the coupled interface residual is far below the existing `1e-15 m/s` acceptance tolerance.

This does **not** yet establish these properties across non-equilibrium, strongly nonlinear or process-rich hydrological regimes. E3/E4 must expand that evidence.

---

## E2 — transaction and mass authority

### Deterministic failure injection

The existing F-GC41 suite ran as part of the E1/E2 workflow:

```text
7 passed
```

It confirms within its deterministic harness that:

- SWAP preflight failure publishes nothing;
- MODFLOW preflight failure publishes nothing;
- ledger preflight failure publishes nothing;
- invalid identity touches no participant;
- failure after the publication point is not misclassified as rollback-safe retry;
- MODFLOW publication readiness is non-mutating;
- MODFLOW timestep finalization is one-shot;
- all preflights precede the first publication operation.

### Real SWAP authority probes

The live F-GC44 route additionally tested real participant state.

At the accepted origin:

```text
SWAP revision = 0
SWAP time = 0
ledger committed count = 0
ledger committed exchange = 0
```

The tuple remained unchanged after:

1. a real SWAP prescribed-head trial;
2. discard of that trial;
3. preparation of a real retained SWAP candidate and ledger;
4. abort before the publication point;
5. every rejected coupled corrector before discard;
6. every rejected coupled corrector after discard;
7. all final publication preflights.

### Publication ordering

After convergence the observed authority sequence was:

```text
before publication:
  SWAP revision = 0
  ledger count = 0

after MODFLOW finalize_time_step:
  SWAP revision = 0
  ledger count = 0

after SWAP commit:
  SWAP revision = 1
  SWAP time = DeltaT
  ledger count = 0

after ledger commit:
  SWAP revision = 1
  ledger count = 1
  ledger amount = accepted final bottom exchange
```

A second MODFLOW finalization remained blocked by the existing one-shot lifecycle.

The workflow markers were:

```text
PUB_GC_E2_REJECTED_TRIAL_ZERO_AUTHORITY=PASS
PUB_GC_E2_PREPUBLICATION_ABORT_ZERO_AUTHORITY=PASS
PUB_GC_E2_EXACTLY_ONCE_PUBLICATION=PASS
PUB_GC_E2_PUBLICATION_ORDER=PASS
```

### E2 interpretation

Within the restricted real-SWAP/live-MODFLOW envelope, trial computation, coupled convergence and authoritative publication are demonstrably distinct operations.

In particular:

```text
computed trial flux != authoritative interface mass
```

until the publication transaction is crossed and the accepted ledger is committed exactly once.

This provides direct evidence for the manuscript's state-authority and mass-authority claims, but it does not yet prove restart durability after a platform failure occurring after the irreversible publication point.

---

## Consequences for the manuscript

E1/E2 now support a first real Results section, not merely a method description.

The evidence strengthens:

- GC-C02 — same accepted origin / rejected trials non-authoritative;
- GC-C05 — explicit distinction and conversion among coupling quantities;
- GC-C06 — rejected trials contribute zero authoritative mass;
- GC-C07 — exactly-once accepted publication;
- GC-C03/GC-C04 — restricted real prepared-solve/conjunctive convergence evidence.

The next scientific workunit remains E3: vary coupling-window duration and hydrological feedback strength so the paper can show when iterative coupling changes the physical/numerical solution and where the current method succeeds or fails.
