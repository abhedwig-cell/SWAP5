# PUB-RC / ACCELERATE literature and prior-art register

## Purpose

This register records the literature that constrains the novelty claims of PUB-RC / ACCELERATE.

The goal is not to accumulate supportive references. The goal is to preserve the strongest prior art found during the 2026-09-18 adversarial review and to state explicitly which candidate novelty claims it weakens or falsifies.

Search scope included:

- partitioned and segregated multiphysics coupling;
- fixed-point and Aitken acceleration;
- interface quasi-Newton and IQN-ILS methods;
- Anderson/multisecant coupling;
- interface Jacobian and derivative-informed co-simulation;
- surrogate/physics-assisted quasi-Newton methods;
- waveform relaxation and multirate coupling;
- FMI/FMU co-simulation;
- MODFLOW coupling architecture and API;
- vadose-zone/groundwater coupling;
- HYDRUS-MODFLOW;
- MetaSWAP/SIMGRO-MODFLOW;
- state-dependent storage and transient specific yield;
- convergence analysis for hydrological partitioned coupling.

This register is a research checkpoint, not a claim that the literature search is globally exhaustive.

## Strongest prior art

| Reference | Domain / method | Information available to coupler | Internal time integration ownership | Consequence for ACCELERATE |
| --- | --- | --- | --- | --- |
| Degroote et al. (2010), *Performance of partitioned procedures in fluid-structure interaction*, Computers & Structures 88, 446-457. DOI: 10.1016/j.compstruc.2009.12.006 | Partitioned FSI; IQN-ILS; Aitken and other black-box comparators | Interface input/output history; approximate inverse Jacobian learned from evaluations | Separate component solvers retained | Falsifies any claim that an exact/component-supplied Jacobian is necessary for fast implicit partitioned coupling. Establishes IQN-ILS as mandatory strong comparator. |
| Sicklinger et al. (2014), *Interface Jacobian-based Co-Simulation*, IJNME 98, 418-444. DOI: 10.1002/nme.4637 | General co-simulation | Explicit interface Jacobians | Specialized subsystem solvers retained | Directly falsifies broad novelty claim "a coupler uses component response/Jacobian information without taking over component solvers". |
| Delaissé et al. (2022), *Surrogate-based acceleration of quasi-Newton techniques for fluid-structure interaction simulations*, Computers & Structures 260, 106720. DOI: 10.1016/j.compstruc.2021.106720 | Partitioned FSI; IQN-ILSM | Black-box secants plus surrogate-provided initial solution/Jacobian | Separate solvers retained | Falsifies broad novelty claim "combine physics/surrogate response with learned quasi-Newton information". |
| Haelterman et al. (2016), *Improving the performance of the partitioned QN-ILS procedure for fluid-structure interaction problems: Filtering*, Computers & Structures 171, 9-17. DOI: 10.1016/j.compstruc.2016.04.001 | Partitioned FSI; QN-ILS history reuse/filtering | Interface histories from previous time steps with filtering | Separate solvers retained | Makes warm-history IQN a required comparator. ACCELERATE cannot compare only against cold-start black-box coupling. |
| Rüth et al. (2021), *Quasi-Newton waveform iteration for partitioned surface-coupled multiphysics applications*, IJNME 122, 5236-5257. DOI: 10.1002/nme.6443 | Partitioned multiphysics; waveform iteration + interface QN | Minimal black-box interface data over time windows; QN history | Supports different internal time steps | Falsifies novelty from combining independent/multirate component integration with accelerated implicit coupling over finite windows. |
| Kotarsky & Birken (2025), *A Time-Adaptive Multirate Quasi-Newton Waveform Iteration for Coupled Problems*, IJNME. DOI: 10.1002/nme.70063 | Partitioned multiphysics; adaptive multirate waveform QN | Black-box interface waveform/history | Separate adaptive time grids retained | Further removes "independent adaptive time integration" as a novelty claim. |
| FMI 3.0.2 specification, section 2.2.12 | General model exchange/co-simulation standard | Partial/directional derivatives explicitly supported for Newton and iterative co-simulation | Co-simulation FMU advances time internally | Falsifies broad claim that component-provided derivatives plus solver autonomy are novel. FMI derivatives are defined at communication points and are not automatically equivalent to the SWAP finite-window response considered here. |
| van Walsum & Veldhuizen (2011), *Integration of models using shared state variables: Implementation in the regional hydrologic modelling system SIMGRO*, Journal of Hydrology 409, 363-370. DOI: 10.1016/j.jhydrol.2011.08.036 | Hydrological component coupling; MetaSWAP/SIMGRO | Shared groundwater-level state plus combined/dynamic storage relation | Hydrological submodels remain distinct | Strong hydrological prior art for exchange of state-dependent storage/response information to support groundwater-unsaturated-zone coupling. Blocks novelty from "hydrological storage response coefficient supplied to groundwater solver". |
| Twarakavi, Simunek & Seo (2008), *Evaluating Interactions between Groundwater and Vadose Zone Using the HYDRUS-Based Flow Package for MODFLOW*, Vadose Zone Journal. DOI: 10.2136/vzj2007.0082 | HYDRUS-MODFLOW vadose-groundwater coupling | Recharge flux and groundwater-table position | Distinct vadose and groundwater formulations; hydrological time-scale separation | Blocks novelty from basic HYDRUS/MODFLOW-style bidirectional vadose-groundwater coupling and from simply retaining separate subsystem formulations. |
| Zeng et al. (2019), *Capturing soil-water and groundwater interactions with an iterative feedback coupling scheme: new HYDRUS package for MODFLOW*, HESS 23, 637-655. DOI: 10.5194/hess-23-637-2019 | Iterative HYDRUS-MODFLOW coupling | Water-table/head and recharge/feedback quantities; iterative scheme and relaxation | Distinct soil-water and groundwater solves | Strong comparator for hydrological iterative coupling. Blocks novelty from iterative feedback coupling itself. |
| Schüller, Birken & Dedner (2025), *Convergence properties of iteratively coupled surface-subsurface models*, GEM - International Journal on Geomathematics 16:9. DOI: 10.1007/s13137-025-00265-4 | Hydrological partitioned coupling; Richards + surface water; convergence analysis | Standard partitioned interface quantities; relaxation/convergence factor analysis | Separate subsystem solves | Blocks generic novelty claim "map hydrological/material/numerical regimes to coupling convergence and optimal acceleration". Also establishes weak-coupling/null-regime as a serious possibility. |
| Hughes et al. (2022), *The MODFLOW Application Programming Interface for simulation control and software interoperability*, Environmental Modelling & Software 148, 105257. DOI: 10.1016/j.envsoft.2021.105257 | MODFLOW 6 API/BMI/XMI | External programs can modify/read MODFLOW variables multiple times within a time step | MODFLOW remains an independently implemented solver | Blocks novelty from external tight coupling or intra-time-step model control alone. |
| Nachabe (2002), *Analytical expressions for transient specific yield and shallow water table drainage*, Water Resources Research 38(10), 1193. DOI: 10.1029/2001WR001071 | Unsaturated-saturated storage response | Time- and water-table-depth-dependent specific yield | Not a coupling algorithm | Blocks novelty from the mere observation that groundwater/vadose storage response is state-, depth- or time-dependent. Supports treating response drift as expected hydrological behaviour rather than novelty. |

## Additional prior-art implications

### Aitken and fixed-point relaxation

Dynamic relaxation is established classical partitioned-coupling practice. ACCELERATE must include Aitken as a low-complexity comparator but must not treat it as the state of the art against which derivative-informed coupling alone establishes novelty.

### IQN-ILS / Anderson family

IQN-ILS is a multisecant black-box acceleration method. The literature explicitly relates IQN-ILS to Anderson acceleration and, for linear problems, to Krylov/GMRES behaviour. The publication experiment therefore does not need to inflate the benchmark set by treating every equivalent formulation as an independent scientific comparator.

Use one credible multisecant implementation and distinguish:

- cold start;
- admissible history reuse;
- history filtering/reset under response drift.

### Surrogate and physics-informed quasi-Newton

Delaissé et al. (2022) is especially important. It already combines prior/surrogate Jacobian information with black-box quasi-Newton updates. Therefore a hybrid method of the form:

```text
physics-informed response + learned secants
```

cannot be claimed as methodologically new in itself.

### Autonomous and multirate time integration

Rüth et al. (2021) and Kotarsky & Birken (2025) show that partitioned acceleration can coexist with different and adaptive internal component time grids. Solver ownership and independent internal time integration remain important SWAP5 architecture properties, but do not establish PUB-RC novelty.

### Hydrological storage response

The 2011 SIMGRO/MetaSWAP paper is the strongest hydrological challenge to a broad F-GC30-derived novelty claim. Its shared-state coupling uses a combined storage relation in order to balance feedback accuracy and computational cost. ACCELERATE must therefore distinguish:

```text
dynamic storage response
```

from:

```text
the actual finite-window interface response J_R = dV_u/dH
```

and then prove that the distinction matters computationally.

### Hydrological convergence regimes

Schüller et al. (2025) already analyze how material and numerical parameters affect convergence of an iteratively coupled hydrological problem. A generic regime map of coupling difficulty is therefore insufficient novelty.

A viable ACCELERATE result would need to concern the **incremental value of supplied response information relative to learned black-box response information**, not merely the existence of easy and hard hydrological coupling regimes.

## Claim-falsification matrix

| Candidate claim | Status after review | Reason |
| --- | --- | --- |
| Derivative-informed partitioned coupling is new | REJECTED | Sicklinger; FMI |
| Coupler can use derivatives without owning component solver | REJECTED | Sicklinger; FMI |
| Independent internal time integration plus implicit acceleration is new | REJECTED | Rüth; Kotarsky & Birken |
| Black-box quasi-Newton interface acceleration is new | REJECTED | IQN-ILS literature |
| Reuse of interface history is new | REJECTED | QN-ILS filtering/reuse literature |
| Physics/surrogate response plus learned QN is new | REJECTED | Delaissé et al. |
| Dynamic hydrological storage response is new | REJECTED | van Walsum & Veldhuizen; Nachabe |
| Supplying flux plus response/storage information to MODFLOW is new | REJECTED as broad claim | SIMGRO/MetaSWAP and MODFLOW coupling history |
| Iterative HYDRUS/MODFLOW coupling is new | REJECTED | Twarakavi et al.; Zeng et al. |
| Hydrological coupling convergence depends on physical/numerical regime | REJECTED as novelty | Schüller et al. |
| A finite-window head-to-flux response operator is abstractly new | REJECTED as broad numerical claim | partitioned/domain-decomposition and co-simulation literature |
| Minimal response information as a generic numerical idea is new | NOT SUPPORTED | low-rank/approximate Jacobian and multisecant literature |
| Supplied finite-window hydrological response can outperform learned black-box history after information cost is counted | OPEN / UNPROVEN | No directly matching hydrological study identified in this review |
| Fresh response has special value after hydrological regime shifts while the new local response remains regular | OPEN / UNPROVEN | Candidate information-scarcity mechanism; requires direct falsification |

## Required comparators derived from literature

Minimum:

```text
FP
Aitken
IQN/Anderson cold
IQN/Anderson warm with credible history reuse/filtering
supplied-response method
```

Waveform QN does not necessarily need to be implemented in the first falsification experiment, but its existence must be acknowledged whenever independent/multirate time integration is discussed.

## Literature-derived experimental constraints

1. Compare total component work and runtime, not only outer iteration counts.
2. Give black-box multisecant methods access to scientifically admissible history reuse.
3. Do not count a response coefficient as free unless explicitly running the zero-cost oracle upper-bound experiment.
4. Use the same final convergence tolerances and physical solution criteria for all methods.
5. Test the weak-coupling null hypothesis. The hydrological domain may contain large regions where acceleration has no material value.
6. Separate storage response, interface response and F-GC30 finite-difference u.
7. Continue literature watch before any manuscript novelty statement.

## Candidate surviving gap

The narrow gap retained after this review is:

> Whether, for independently time-integrating vadose-zone and groundwater models, fresh component-provided finite-window hydrological response information has a reproducible net computational value over state-of-the-art black-box multisecant learning, especially when prior interface history becomes stale after hydrological regime change but the new local response remains sufficiently regular.

This is a hypothesis, not an established novelty claim.

## References and stable links

- Degroote, J., Haelterman, R., Annerel, S., Bruggeman, P., & Vierendeels, J. (2010). Performance of partitioned procedures in fluid-structure interaction. *Computers & Structures*, 88, 446-457. https://doi.org/10.1016/j.compstruc.2009.12.006
- Sicklinger, S., Belsky, V., Engelmann, B., Elmqvist, H., Olsson, H., Wuechner, R., & Bletzinger, K.-U. (2014). Interface Jacobian-based Co-Simulation. *International Journal for Numerical Methods in Engineering*, 98, 418-444. https://doi.org/10.1002/nme.4637
- Delaissé, N., Demeester, T., Fauconnier, D., & Degroote, J. (2022). Surrogate-based acceleration of quasi-Newton techniques for fluid-structure interaction simulations. *Computers & Structures*, 260, 106720. https://doi.org/10.1016/j.compstruc.2021.106720
- Haelterman, R., Bogaers, A. E. J., Scheufele, K., Uekermann, B., & Mehl, M. (2016). Improving the performance of the partitioned QN-ILS procedure for fluid-structure interaction problems: Filtering. *Computers & Structures*, 171, 9-17. https://doi.org/10.1016/j.compstruc.2016.04.001
- Rüth, B., Uekermann, B., Mehl, M., Birken, P., Monge, A., & Bungartz, H.-J. (2021). Quasi-Newton waveform iteration for partitioned surface-coupled multiphysics applications. *International Journal for Numerical Methods in Engineering*, 122, 5236-5257. https://doi.org/10.1002/nme.6443
- Kotarsky, D., & Birken, P. (2025). A Time-Adaptive Multirate Quasi-Newton Waveform Iteration for Coupled Problems. *International Journal for Numerical Methods in Engineering*. https://doi.org/10.1002/nme.70063
- Modelica Association Project FMI. Functional Mock-up Interface Specification 3.0.2, especially section 2.2.12 on partial derivatives. https://fmi-standard.org/docs/3.0.2/
- van Walsum, P. E. V., & Veldhuizen, A. A. (2011). Integration of models using shared state variables: Implementation in the regional hydrologic modelling system SIMGRO. *Journal of Hydrology*, 409, 363-370. https://doi.org/10.1016/j.jhydrol.2011.08.036
- Twarakavi, N. K. C., Simunek, J., & Seo, S. (2008). Evaluating Interactions between Groundwater and Vadose Zone Using the HYDRUS-Based Flow Package for MODFLOW. *Vadose Zone Journal*. https://doi.org/10.2136/vzj2007.0082
- Zeng, J., Yang, J., Zha, Y., & Shi, L. (2019). Capturing soil-water and groundwater interactions with an iterative feedback coupling scheme: new HYDRUS package for MODFLOW. *Hydrology and Earth System Sciences*, 23, 637-655. https://doi.org/10.5194/hess-23-637-2019
- Schüller, V., Birken, P., & Dedner, A. (2025). Convergence properties of iteratively coupled surface-subsurface models. *GEM - International Journal on Geomathematics*, 16, 9. https://doi.org/10.1007/s13137-025-00265-4
- Hughes, J. D., et al. (2022). The MODFLOW Application Programming Interface for simulation control and software interoperability. *Environmental Modelling & Software*, 148, 105257. https://doi.org/10.1016/j.envsoft.2021.105257
- Nachabe, M. H. (2002). Analytical expressions for transient specific yield and shallow water table drainage. *Water Resources Research*, 38(10), 1193. https://doi.org/10.1029/2001WR001071

## Literature-watch triggers

Re-run targeted novelty review before manuscript drafting if any new paper is found on:

- derivative- or tangent-informed vadose-zone/groundwater coupling;
- IQN/Anderson acceleration applied directly to groundwater-vadose-zone coupling;
- finite-window or waveform Jacobians for Richards-groundwater interaction;
- adaptive choice between black-box and supplied-response coupling;
- response-information cost or value-of-information analysis in environmental co-simulation;
- current MODFLOW6 coupling packages that expose derivative/storage-response contracts beyond the MetaSWAP pattern.
