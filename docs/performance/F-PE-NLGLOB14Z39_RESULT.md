# F-PE-NLGLOB14Z39 result — compiled Richards solve-service manager-overhead amortization

Date: 2026-09-30

Status:

`QUALIFIED_Z39_MANAGER_OVERHEAD_AMORTIZED`

Qualification authority:

- workflow run: `36772207395`;
- job: `110081142691`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Aggregate result

The frozen amortization test classifies:

`QUALIFIED_Z39_MANAGER_OVERHEAD_AMORTIZED`.

The remaining Z38 persistent-manager fixed overhead is negligible relative to an actual compiled Heritage Richards solve.

## Richards solve-service timing

Median full solve time per repeated immutable-origin solve:

- B01: about `9.13 us`;
- B12: about `7.05 us`;
- O05: about `7.07 us`;
- O14: about `11.19 us`.

All repeated solves converge and produce finite checksums.

## Frozen overhead fractions

Using the preregistered Z38 residual manager overhead:

### n = 13 representative overhead: 0.018 us

Fraction of full solve time:

- B01: about 0.197%;
- B12: about 0.255%;
- O05: about 0.255%;
- O14: about 0.161%.

### n = 12 representative overhead: 0.009 us

Fraction of full solve time:

- B01: about 0.099%;
- B12: about 0.128%;
- O05: about 0.127%;
- O14: about 0.080%.

All are far below the frozen 5% materiality gate.

## Interpretation

Z37 and Z38 correctly exposed fixed manager overhead when benchmarked against a sub-microsecond TRIDAG-only operation.

Z39 shows that this remaining fixed overhead is practically negligible once compared with the actual Richards solve-service cost scale.

Therefore further optimization of view/request/materialization overhead before binding the real reduced solve-service is not justified.

The performance question now returns to the intended mechanism:

does reducing the actual nonlinear solve dimension from approximately 16 to 12–14 convert the already-qualified ~20% deterministic work reduction into end-to-end solve-service speedup?

## Qualified claim boundary

Qualified:

- real Heritage/reference Richards solve-service cost is several microseconds per solve on the frozen four-material fixture;
- remaining persistent manager overhead is below 0.3% of full solve cost in all cases;
- additional manager-seam micro-optimization is not warranted before real reduced solve-service binding.

Not qualified:

- actual reduced Heritage solve-service speedup;
- whole-SWAP end-to-end speedup;
- production admission.

## Consequence

Proceed directly to the real reduced Heritage solve-service binding behind the qualified manager seam.

The successor should:

1. retain full-column accepted-state authority;
2. execute the actual reduced nonlinear service at active n;
3. reconstruct/materialize the full candidate;
4. retain explicit fallback/bypass;
5. compare physical result to full reference;
6. measure full versus reduced solve-service wall-clock timing.

Use a small focused case set first; no broad trajectory campaign is needed.

## Production boundary

Research only.

`LEGACY_NUMERICS` remains production default.
