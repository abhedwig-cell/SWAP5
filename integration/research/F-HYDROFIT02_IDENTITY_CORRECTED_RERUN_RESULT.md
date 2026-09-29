# F-HYDROFIT02 identity-corrected rerun result

Authority run: `36520926454`, head `a715a0603d0cbcb0a5be5daeb9af920beb246979`.

Artifact: `11012537753`, digest `sha256:06c73a4db2c72d4578d5720234b1d0b278c3a9cbd1fa85a3c587df28a301e88a`.

This run used the frozen identity-corrected 31-record corpus and bound every hydrophysical fit by hydraulic SHA-256.

## Identity reconciliation outcome

The deterministic 12-case subset is unchanged. Its old record binding was already correct, including the later BHR000000378543 0.60-0.70 m record with hash `f095f112...`.

Exactly three earlier duplicate-depth records in the 19-case complement had been wrong-bound under the old depth-only dictionary lookup. They are now fitted to their own hydraulic hashes:
- BHR000000378543 0.60-0.70 m, lambda -10, hash `5f653eae...`;
- BHR000000378543 1.40-1.50 m, lambda -1.9999, hash `aab632a2...`;
- BHR000000378544 0.35-0.45 m, lambda 0.0001, hash `52c85ee0...`.

## Deterministic profile and fallback

The deterministic profile and fixed/median fallback results reproduce the earlier results to numerical precision.

LOO_MEDIAN fallback:
- median J/Jbest 1.18065;
- mean 1.50902;
- max 4.13247;
- zero formal bound blocks.

This confirms that P-LPROF and the scalar fallback conclusions were not artifacts of the identity defect.

## Conditional prior rerun

The descriptor-corrected 31-record prediction diagnostics change modestly:
- KNN5 median absolute lambda error: 1.32237;
- KNN5K median absolute lambda error: 1.21693.

The hydraulic fit qualification on the deterministic 12 is effectively unchanged:
- LOO_MEDIAN: 12/12 identifiable;
- HORIZON: 12/12 identifiable;
- KNN5: 11/12 identifiable, one SEVERE;
- KNN5K: 10/12 identifiable, two SEVERE.

KNN5K still produces SEVERE fits for both problematic BHR000000378543 deterministic cases. It remains unqualified despite its favorable objective distribution.

## Soft shrinkage rerun on deterministic 12

The LOO-centered variants reproduce the earlier result:
- sigma 0.5: median 1.01820, mean 1.04554, max 1.26152, zero SEVERE;
- sigma 1.5: median 0.99973, mean 1.01893, max 1.25452, zero SEVERE;
- sigma 4.0: two SEVERE cases.

The KNN5K-centered variants remain unqualified. After identity-correct descriptor binding all three tested widths have two hydraulic and two penalized SEVERE cases.

Thus the empirical conclusion favoring a simple leakage-resistant LOO-median center over KNN5K remains intact.

## Identity-corrected independent complement

The 19-case hold-out metrics change because three records now use their correct hydraulic observations.

LOO sigma 0.5:
- median J/Jbest 1.02990;
- mean 1.04647;
- max 1.27532;
- zero formal bound blocks;
- one hydraulic SEVERE;
- one penalized SEVERE.

LOO sigma 1.5:
- median J/Jbest 1.00011;
- mean 0.97650;
- max 1.19861;
- zero formal bound blocks;
- one hydraulic SEVERE;
- one penalized SEVERE.

For the three corrected duplicate-depth hold-out records, all hash-correct fits are non-SEVERE.

The sole failure for both widths remains:

`BHR000000378532 0.65-0.75 m`, hash `19f7fe0532875070ff6049f98959a5ea57f2cc3b95724387fd74dbf68bc6df12`.

- sigma 0.5: fitted lambda -3.14239, J/Jbest 1.25085, hydraulic cond 2.20e17;
- sigma 1.5: fitted lambda -4.03915, J/Jbest 0.95415, hydraulic cond 1.73e17.

This is the same unique record characterized by P-LID02. Its severe valley is therefore not caused by duplicate record identity.

## Qualification

P-LSHRINK01 remains **NOT_REPLICATED** under the preregistered zero-SEVERE criterion.

Identity correction improves the validity of the aggregate hold-out metrics but does not rescue the estimator. The negative replication result is scientifically strengthened: the failure localizes to a genuine hydrophysical record whose low-objective lambda region overlaps a severe identifiability ridge.

## Scientific conclusion

The current evidence supports all of the following:
- hard lambda=0.5 is a poor general fallback;
- a robust empirical LOO-median center is preferable to the tested low-capacity conditional centers;
- soft LOO shrinkage with sigma 0.5 or 1.5 gives good objective behavior on most cases;
- a soft prior alone cannot guarantee identifiability when the hydraulic likelihood itself favors a locally singular lambda/alpha/Ks ridge;
- explicit post-fit identifiability qualification is therefore not optional.

The next estimator, if tested, should not tune another sigma or KNN rule. A defensible next step is to retain the already tested soft LOO estimator as the primary fit, apply the existing preregistered SEVERE gate, and use a stronger already-defined fallback only when that gate fails. Any such estimator must be preregistered before execution.

This remains a research result. No production admission is implied by this 31-record corpus.
