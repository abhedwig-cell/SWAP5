# A27 actual hydraulic domain and pressure frontier

Date:2026-10-02. Status: LOCAL_RESEARCH_ROUTE_FALSIFICATION. Production A/B/C OPEN; canonical admission false.
Canonical reconciliation:7a629a10cabb3553ff77474423e6ccac81b29aec. Delta since0d44f0195 is LOW03 shared-dependency documentation/control only, no production or Status-A/AGENTS change. Branch baseline:51ef1fc8b42eaa163804b23ab447a3d2d9cdfaa4. Source run code:eb493c53feec8f80cd10cff76aff5ae400644da9. Precision analysis code:9de14bbd961ac12ea0f111d22cc7323285ba698f. [Preregistered contract](PPA_WU05A27_REAL_HYDRAULICS_CONTRACT.md).

## Decision

The proposed **general moisture-only wall closure** does not cover the actual saturated constitutive domain without a separate pressure-exchange treatment. This was the first prospective dependency gate before moving-contact/receiver implementation and fails in every one of36 catalog materials. Do not propagate this failed closure into a larger coupled benchmark. The earlier128-cell result remains valid for its synthetic diffusion slab and fixed-wall numerical screen; it cannot establish this omitted domain capability.

This does **not** falsify all RFM routes, the admitted A26 runtime or an unsaturated moisture-profile closure augmented with signed pressure exchange. A26 already carries matrix/receiver heads and Darcy exchange; preserving that capability is a requirement for any new history representation. The result also does not prove a universal requirement for monolithic coupling. The reference/source tests here are actual constitutive and exchange primitives, not production A/B/C runtime tests.

## Actual parameter/source scope

All36 rows of tests/fpe/data/fpe_elastic05_staringreeks_2018.csv supply wcr,wcs,alpha,n,lambda and ksfit without adjustment. These are repository catalog parameters, not new field validation. The default-MvG branch uses cofgen9=0, no KSATEXM and no physical elastic storage. Near-saturation continuation and source numerical capacity policies remain intact. Catalog Ks is used isotropically in the controlled horizontal slab counterexample; no general anisotropy correspondence is asserted.

Compile actual mod_b110_default_mvg_provider and actual mod_ppa_wu05a6_saturated_exchange_rate. Run1296 hydraulic samples and576 signed-source samples at O0/O2; both pairs have byte-identical output and all runtime/source-bound checks pass. The saturated primitive receives controlled unit-wall conductance Ks/10 and full wet fractions. That is a slab sign/pressure counterexample, not the production standard pore-geometry mapping.

## Findings

For h>=0, actual default retention without physical elastic storage is theta=theta_s and K=Ks. Thus equal moisture profiles can hide distinct pressure fields and different steady exchange. For B01,theta_s=0.42749391,Ks=31.22501566cm/day, wall pressure5cm and slab length10cm:

| Matrix pressure cm | Actual matrix theta | Actual macro-to-matrix flux cm/day | Moisture-only saturated diffusion flux cm/day |
| --- | --- | --- | --- |
|0|0.42749391|15.61250783|0|
|1|0.42749391|12.490006264|0|
|5|0.42749391|0|0|
|9|0.42749391|-12.490006264|0|

All36 materials reproduce positive, zero and reverse source signs. Maximum difference from independent q=Ks*(h_wall-h_matrix)/10 is7.10543e-15cm/day. The moisture-only zero-flux prediction follows from equal saturated theta throughout the slab, not a separately run production model. This exact counterexample falsifies general pressure reconstruction from that state. A pressure gradient may transport water without changing incompressible saturated moisture storage.

Actual numerical capacity at these saturated states is dt*1e-7cm^-1, while the physical derivative of this retention plateau is0. Consequently the source **solver** ratio K/C depends on dt and is not a material diffusivity. For B01 it rises from3.122501566e9 to3.122501566e12cm2/day when dt falls from0.1 to0.0001day. The ratio is1000 in all36 materials at fixed pressure. Do not treat the solver floor as physical elastic storage, remove it from production, or tune a new storage to make this representation invertible.

At the sampled strictly unsaturated heads, the physical retention derivative is positive and independent of dt. Source capacity agrees with the80-digit independent differentiation to maximum relative1.35138e-15. The initial ordinary central difference gave a maximum1.01745% discrepancy at O05,h=-0.02cm because the water-content difference approaches double-precision resolution. This negative precision finding is retained alongside both derivative estimates. It is not evidence of a constitutive defect. The near-saturated D estimate is large even below saturation; replacing the former synthetic finite diffusivity will introduce a substantially different stiffness envelope.

The failed local attempt to load an unavailable mpmath package preceded all high-precision file edits; it produced no completed precision gate. The next preregistered analysis used Python Decimal80 and central increment1e-25cm, with no external precision package. Raw source runs completed successfully; an analysis preparation failure must not be relabeled as a failed numerical source run.

## Replacement design boundary, proposed only

Two defensible continuations remain: restrict the moisture-profile operator to its invertible unsaturated domain and preserve an explicitly separate signed saturated-pressure operator, or use a mixed pressure/storage wall formulation through saturation. Neither is implemented/qualified by this result. Use the explicit [mixed wall design boundary](PPA_WU05A27_MIXED_WALL_STATE_DESIGN.md) before new coupling work.

The mixed formulation should retain physical storage theta(h) and pressure as a trial unknown; saturated capacity may be zero while pressure is fixed by hydraulic boundary/conservation equations. A timestep-dependent Newton regularization may help a solver, but must never enter the physical mass residual or diffusivity. Receiver feedback changes wall head and wetted geometry during a trial; it must consume the same conserved exchange as matrix storage. Numerical execution can be explicit, subcycled or coupled only after comparison under a common physical contract.

Moving wall geometry and closed receiver evolution have deliberately not been implemented after this failed dependency gate. Full production A/B/C, parameter mapping, eight forcing regimes and repeated/scaled performance remain OPEN. No shared interface, production source, top receipt, MB deep receipt, no-passage-exchange rule or A26 admission boundary changes.

## Reproduction and durable evidence

```bash
FC=/tmp/top03-bin/gfortran bash research/rfm/a27/run_real_hydraulics.sh > /tmp/a27-hydraulic.csv
FC=/tmp/top03-bin/gfortran bash research/rfm/a27/run_real_hydraulics.sh darcy > /tmp/a27-darcy.csv
python3 research/rfm/a27/analyze_real_hydraulics.py /tmp/a27-hydraulic.csv /tmp/a27-darcy.csv /tmp/a27-real-analysis
```

Use the source run SHA for original raw runs and the analysis SHA for the final precision analysis. Per-ref source hashes, versions, all raw output/logs and tables are in the REAL_HYDRAULICS evidence manifest/split archive. Concatenate PPA_WU05A27_REAL_HYDRAULICS.tar.gz.part-* in lexical order and extract the gzip tar. The verifier checks the immutable archive and each dependency at its original ref. Repository documentation/source checks and strict MkDocs are recorded separately. Locally verified source-domain counterexamples and durable branch evidence are distinct from production qualification and canonical admission, both false.

## Final live canonical reconciliation

Canonical moved during this block to82351099a8c5c77ce111f8ace6648b8b5ffa7167, admitting the bounded LOW03 typed resistive-head solver prerequisite. Actual changes affect mod_soil_water_solver_contract, headcalc and Reference binding; AGENTS, default-MvG and saturated exchange primitive stay unchanged. The new shared contract was compiled in an isolated source assembly with the pinned A27 tests and current canonical hydraulic/catalog inputs. Both1296 hydraulic and576 signed-source O0/O2 gates pass, and output is byte-identical to the original source runs. Exact per-file input refs are retained. This qualifies only these source-domain probes under the new contract. It does not preserve the complete earlier A27 real-Richards/composer/backend dependency surface. The new canonical backend delta has not been merged into the A27 source branch; reconcile and requalify affected production/column gates before full A/B/C. Mode3 serialized application remains fail-closed under central authority.
