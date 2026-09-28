# F-HYDROFIT02 P-LPOL01 — conductivity-exponent policy preregistration

Authority observed: `integration/f-ci-canonical@1113eb11966f3e5a5ced5c6e14f243d6de79a3b5`.

## Question

Can a bounded policy for Mualem conductivity exponent l retain most of the joint theta/K objective improvement seen in real BRO data while avoiding the non-qualified boundary/extreme solutions observed under broad free-l fitting?

## Frozen real-data set

Use exactly the six hydrophysical intervals already extracted from:

- BHR000000346010;
- BHR000000346024;
- BHR000000378560.

No interval may be dropped because of an unfavorable result.

## Policies

A. STORED_L: fix l to the l value stored in the BRO/WENR model; refit theta_r, theta_s, alpha, n, Ks.

B. BOUNDED_L: fit l within [-4, 0]. This interval is chosen before observing this comparison because all qualified/non-boundary real fits seen so far lie roughly between -3.1 and -1.2, while the failed solutions ran to -10. It is a research bound, not yet a production physical law.

C. BROAD_L: existing research baseline l in [-10, 10].

All other parameter bounds and the family-mean objective remain identical.

## Metrics

For each interval and policy report:

- objective J;
- ratio to stored-parameter objective;
- theta_r, theta_s, alpha, n, Ks, l;
- whether any fitted parameter is within 0.1% of a bound;
- objective penalty relative to BROAD_L.

## Gates

L0. Same observations and weights for all policies.

L1. A boundary solution is reported, never silently accepted.

L2. BOUNDED_L is considered promising only if it removes the broad-l pathological solutions and retains at least 90% of the BROAD_L objective improvement on at least 5 of 6 intervals.

L3. Failure of L2 is an admissible negative result.

L4. No production l range is inferred from six intervals alone.
