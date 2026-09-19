# F-ROMV simplified-model precedent audit

**Workstream:** F-ROM  
**Purpose:** qualify purpose-dependent hydrological fidelity using existing simplified unsaturated-zone models as precedent  
**Status:** literature/evidence audit; no algorithm inheritance and no production authority

## 1. Question

The relevant precedent question is not whether an approximate unsaturated-zone model can reproduce a Richards solver numerically.

It is:

> How have deliberately simplified unsaturated-zone models defined usefulness, where do their approximations matter hydrologically, and how was the acceptable application domain bounded?

This audit informs the F-ROMV purpose-dependent acceptance envelope. It does not import another model's thresholds into SWAP5.

## 2. MetaSWAP

Primary source: Van Walsum, P.E.V. & Groenendijk, P. (2008), *Quasi Steady-State Simulation of the Unsaturated Zone in Groundwater Modeling of Lowland Regions*, Vadose Zone Journal, DOI 10.2136/vzj2007.0146.

### 2.1 Computational problem

The paper explicitly starts from a regional-computation problem. Richards-based variably saturated models were considered too expensive for the target of very large numbers of soil units over multi-decadal simulations.

The reduction is physical and numerical:

- steady-state Richards profiles are pre-solved offline;
- online dynamics use sequences of those profiles;
- water balances are evaluated over aggregated control volumes;
- groundwater coupling uses storage/response information rather than resolving the complete transient Richards profile online.

This is closer to a reduced physical/manifold model than to an alternative nonlinear solver.

### 2.2 How fidelity was judged

MetaSWAP was compared with SWAP over 21 Dutch soil types, different root-zone depths, different drainage depths and two meteorological years including the extreme dry summer of 1976.

The published plausibility test used application-facing quantities.

For groundwater levels, Nash-Sutcliffe model efficiency (ME) was reported. Under the 1995, 0.3-m root-zone, 0.75-m drainage-depth case, 17/21 soil types had ME > 0.95. Performance degraded for deeper root zones and deeper drainage. The authors therefore interpreted applicability conditionally rather than claiming general equivalence.

Evapotranspiration totals were generally lower than SWAP by only a few percentage points, but one clay case differed by 15%. These values are historical observations, **not F-ROMV acceptance thresholds**.

### 2.3 Known dynamic differences

The paper is unusually useful because it does not hide where the simplification changes hydrology.

After major precipitation events, MetaSWAP and SWAP can show substantial profile differences. The causes identified include instantaneous root-zone spreading, steady-state-profile use and temporal weighting.

MetaSWAP transmits changes toward groundwater more quickly than SWAP. Day-averaged recharge can nevertheless be very similar even while root-zone flux pulses differ.

The authors explicitly note that this loss of wave-like event dynamics can have limited consequences for applications in which water balance at time scales larger than one day matters more than sub-daily flux pulses.

The paper also reports artifacts around the transition from percolation to capillary rise. That is directly relevant to F-ROMV: regime transitions must be evaluated separately from mean errors.

### 2.4 Practical precedent

The current NHI MetaSWAP information page describes MetaSWAP as a SWAP-based metamodel and states a practical speed advantage of roughly 10-20 times compared with SWAP for regional use.

This speed statement is external product information, not a SWAP5 benchmark. It nevertheless demonstrates the type of cost-fidelity trade that can make an approximate unsaturated-zone model operationally worthwhile.

A later operational study, Pezij et al. (2019), used MetaSWAP root-zone soil moisture in a data-assimilation setting, further illustrating that a reduced model can be judged on state-estimation utility rather than full Richards profile identity.

## 3. De Laat pseudo steady-state precedent

Primary source: De Laat, P.J.M. (1976), *A pseudo steady-state solution of water movement in the unsaturated zone of the soil*, Journal of Hydrology 30, 19-27, DOI 10.1016/0022-1694(76)90086-X.

The method represents transient unsaturated-zone flow as a sequence of steady-state solutions.

The abstract already provides an important validity lesson: the efficiency comes with a restricted application domain, including permeable soils, relatively high groundwater levels and periods dominated by either evaporation excess or rainfall excess.

This is an early example of **model reduction with an explicit regime envelope**, not an attempt to claim universal Richards equivalence.

## 4. MODFLOW UZF1 as a contrasting simplification

Primary source: Niswonger, R.G., Prudic, D.E. & Regan, R.S. (2006), USGS Techniques and Methods 6-A19, *Documentation of the Unsaturated-Zone Flow (UZF1) Package for Modeling Unsaturated Flow Between the Land Surface and the Water Table with MODFLOW-2005*.

UZF1 uses a kinematic-wave approximation to Richards flow.

Its documentation explicitly states limitations:

- negative pressure gradients are ignored;
- capillary-induced infiltration is not represented at wetting onset;
- a capillary fringe is not simulated;
- the original formulation assumes uniform hydraulic properties for an unsaturated column.

The approximation can still reproduce useful wetting-front behaviour and recharge for its intended basin-scale settings.

For F-ROMV this is a cautionary precedent. A reduction can be successful for gravity-dominated recharge and still be structurally unsuitable for shallow-groundwater/capillary-rise applications. Application domain must therefore be defined in hydrological terms, not just by parameter min/max ranges.

## 5. Implications for SWAP5/MultiSWAP ROM

### 5.1 Numerical identity is the wrong universal target

For an alternative solver such as RossFast, tight equivalence is appropriate because the objective is another route to essentially the same SWAP process solution.

For a reduced model, acceptable discrepancy is purpose-specific.

### 5.2 Conservation is different from output fidelity

MetaSWAP and UZF-type precedents reinforce a useful distinction:

- mass/accounting integrity is a structural requirement;
- exact transient profile and event fidelity may be intentionally reduced;
- cumulative ET, recharge, groundwater response or soil-moisture state can be the primary quantities for a declared application.

### 5.3 Error must be decomposed by hydrological function

A single global RMSE can hide the failure mode that matters.

F-ROMV therefore keeps separate:

- accumulated flux bias;
- storage drift;
- ET bias;
- recharge/drainage response;
- groundwater feedback;
- soil-moisture state;
- drought and extremes;
- event timing;
- regime transitions;
- OOD and robustness.

### 5.4 A speed claim has meaning only with a fidelity claim

The correct comparison is not:

> reduced model versus Richards error

but:

> computational cost versus application-relevant hydrological fidelity.

Each model or configuration becomes a point or region on a cost-fidelity frontier.

### 5.5 Different reductions may dominate different applications

A dynamic local state-space ROM may be attractive where transient state is important.

A quasi-steady/tabulated physical reduction may dominate for regional, many-column, long-term or groundwater-coupled calculations.

A pure output surrogate may dominate calibration, UQ or data-assimilation tasks that do not require an internally reusable prognostic state.

There is no reason to expect one reduced architecture to dominate all three.

## 6. Consequence for the F-ROMV experiment programme

The failed Stage-1 bilinear closure must not be rescued by loosening solver-equivalence criteria. It violated physical admissibility, which is an integrity failure under every application envelope.

However, that failure does not invalidate deliberately approximate model reduction.

The next independent discriminator should therefore test a different hypothesis rather than tune the failed regression:

> Can a conservative quasi-steady or integrated-manifold reduction retain the long-term storage/recharge behaviour needed for regional or groundwater-coupled use at substantially lower online cost, while explicitly accepting weaker fast-event fidelity?

This candidate should be rejected for fast-event/process-science use if event timing or regime transitions are materially wrong, even if annual balances are good.

## References

- De Laat, P.J.M. (1976). A pseudo steady-state solution of water movement in the unsaturated zone of the soil. *Journal of Hydrology*, 30, 19-27. DOI: 10.1016/0022-1694(76)90086-X.
- Niswonger, R.G., Prudic, D.E. & Regan, R.S. (2006). *Documentation of the Unsaturated-Zone Flow (UZF1) Package for Modeling Unsaturated Flow Between the Land Surface and the Water Table with MODFLOW-2005*. USGS Techniques and Methods 6-A19.
- Pezij, M. et al. (2019). State updating of root zone soil moisture estimates of an unsaturated zone metamodel for operational water resources management. *Journal of Hydrology X*, 4, 100040. DOI: 10.1016/j.hydroa.2019.100040.
- Schaap, J. & Dik, P. (2007). MetaSWAP meet zich met SWAP: simulatie van de onverzadigde zone voor regionale en nationale modellen. *Stromingen*, 13(3), 15-25.
- Van Walsum, P.E.V. & Groenendijk, P. (2008). Quasi Steady-State Simulation of the Unsaturated Zone in Groundwater Modeling of Lowland Regions. *Vadose Zone Journal*. DOI: 10.2136/vzj2007.0146.
- NHI modelcode page, MetaSWAP, consulted 2026-09-19.
