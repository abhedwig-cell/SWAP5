# STRIP01 standalone A/B execution contract

Research only. Baseline canonical: 53059a5225fa45cd6121d4bc4c7310dcc4e0660c.
This supplement freezes the standalone gates before native MODFLOW execution.

The independent finite-volume oracle treats DRN as a first-cell-centre sink:
Q = R N dx dy; h0 = stage - base + Q/C;
h_i^2 = h0^2 + (R dx^2/K) i(2N-1-i).
Its arithmetic saturated-thickness transmissivity is an independent Dupuit
discretization, not an assertion about MODFLOW's internal averaging.
The continuum uses h(x)^2 = h_d^2 + (R/K)(2Lx-x^2).
Cell-centred drain placement introduces a geometry error relative to an ideal
edge drain. Report both and refine from 50 to 100 cells over the same 50 m.

Correction to the initial preregistration's approximate hand calculation:
the ideal midpoint rises for K=0.1, 0.25, 0.5, 1, 2 m/d are
2.07107, 0.91608, 0.47723, 0.24404, 0.12348 m, respectively.
The earlier 1.80 m at K=0.1 was a arithmetic error, not a simulated result.
K=0.5 remains the initial selected candidate. DRN conductance is 100 m2/d,
giving Q/C=0.0005 m at recharge 0.05 m3/d. Sy=0.2 and Ss=0 are
standalone physical aquifer parameters, not coupled production authority.

Native engine: MODFLOW6 6.8.0; archive SHA256:
33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e.
FloPy 3.9.5. IMS head closure 1e-10 outer / 1e-11 inner m,
residual closure 1e-10 m3/d. Test limits before execution:

- standalone head/oracle discrepancy <=0.005 m, a discrete averaging allowance;
- recharge/drain and storage/drain rate residual <=1e-8 m3/d;
- cumulative transient storage/drain volume residual <=1e-6 m3;
- monotone total storage within that same roundoff allowance;
- monotone steady spatial head within 1e-9 m.

Drain-down starts at -3 m, lasts 120 d, with 0.25 d timesteps, no recharge,
no evapotranspiration, only first-cell DRN. Geometry alone imposes right/base
no-flow. Native budgets, rather than manufactured oracle outputs, qualify A/B.
Retain failed execution logs and package inputs. Limits cannot be increased
after seeing a failed result. Scripts must not download executables implicitly.

Reproduce:

```bash
python tests/fgc/strip01/oracle.py --output integration/f-gc/strip01/results
python tests/fgc/strip01/run_standalone.py --mf6 /path/to/mf6 --output /path/to/results
```

These gates do not qualify SWAP coupling, Hupsel, restart or production.
