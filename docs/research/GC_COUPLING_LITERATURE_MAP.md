# Coupling literature map for SWAP5-MODFLOW6

Date: 2026-09-21
Status: RESEARCH LITERATURE MAP

## Why this map exists

"Coupling an unsaturated-zone model to MODFLOW" is not one mathematical
problem. Published approaches make different choices about:

- whether groundwater head is one shared state or two boundary states;
- whether storage belongs to one combined control volume or separate domains;
- whether information is exchanged once per time step or iteratively;
- whether a communicated quantity is recharge, a physical interface flux, a
  state correction, or a Jacobian-like response.

The dummy-SWAP testbank should therefore be compared to coupling **families**,
not to one generic notion of model coupling.

## 1. Shared-state / h-link family

### Van Walsum and Veldhuizen (2011)

P.E.V. van Walsum and A.A. Veldhuizen,
"Integration of models using shared state variables: Implementation in the
regional hydrologic modelling system SIMGRO",
Journal of Hydrology 409, 363-370.
DOI: 10.1016/j.jhydrol.2011.08.036.

The paper defines the phreatic surface as a shared state variable between the
SVAT/unsaturated model and groundwater model. Both submodels use the same
combined storage relationship.

The paper explicitly contrasts this with sequential and q-link coupling. A
finite resistance introduced at the saturated-unsaturated interface is
described as a model artefact when the phreatic surface is the natural
demarcation of a continuous system.

The paper also verifies the h-link against a supposedly equivalent q-link and
studies time-step sensitivity.

### Relevance to SWAP5

This is the closest literature analogue to the **dummy h-link** research
question behind DSW-01/02:

```
one phreatic physical head
one combined storage response
different process contributions to one balance
```

It supports treating storage ownership as part of the coupling definition, not
as an implementation detail.

MAP11 now establishes a necessary boundary on the analogy. The current
canonical F-GC route exchanges hydraulic head at the SWAP lower coupling plane,
and the source explicitly distinguishes that head from the freatic groundwater
level. The F-GC45 head-driven corrector applies it as a lower-boundary pressure
head.

Therefore the SIMGRO shared-phreatic h-link and the current SWAP5 F-GC
interface-head route are distinct coupling families unless a future authority
explicitly maps them onto the same phreatic state and storage volume.

The literature does **not** prove that the current SWAP5 `q_u/u` formulation
has the same mathematical meaning as SIMGRO complete-profile storage.

## 2. Sequential head/recharge exchange

### Twarakavi, Simunek and Seo (2008)

N.K.C. Twarakavi, J. Simunek and S. Seo,
"Evaluating Interactions between Groundwater and Vadose Zone Using the
HYDRUS-Based Flow Package for MODFLOW",
Vadose Zone Journal 7.
DOI: 10.2136/vzj2007.0082.

HYDRUS and MODFLOW can use different internal time steps. At the end of a
MODFLOW time step, recharge from HYDRUS is passed to MODFLOW. The newly
calculated water-table depth is then used as the lower boundary condition for
the next HYDRUS period.

Conceptually:

```
water-table head -> vadose boundary problem
vadose bottom flux -> MODFLOW recharge
```

This is not a shared-state storage formulation.

### Beegum et al. (2018)

S. Beegum, J. Simunek, A. Szymkiewicz, K.P. Sudheer and I.M. Nambi,
"Updating the Coupling Algorithm between HYDRUS and MODFLOW in the HYDRUS
Package for MODFLOW",
Vadose Zone Journal.
DOI: 10.2136/vzj2018.02.0034.

The authors identify errors caused by holding the groundwater boundary fixed
through a MODFLOW time step and then abruptly updating it. Their revised
coupling is aimed at reducing artificial bottom-flux changes caused by that
time-discrete boundary update.

### Zeng et al. (2019)

J. Zeng, J. Yang, Y. Zha and L. Shi,
"Capturing soil-water and groundwater interactions with an iterative feedback
coupling scheme: new HYDRUS package for MODFLOW",
Hydrology and Earth System Sciences 23, 637-655.

The paper develops iterative feedback coupling and evaluates the water balance
at the moving phreatic interface. It emphasizes that lateral saturated flow
can create nontrivial coupling error if the vadose and groundwater systems are
only exchanged sequentially.

### Relevance to SWAP5

These papers are useful counterexamples to the assumption that every
SWAP-MODFLOW link should be described as one shared state.

A head/recharge boundary-exchange scheme can be physically and numerically
coherent, but its state ownership and time-discretization error are different
from an h-link.

DSW-08 represents yet another explicitly controlled case: a real finite
resistance between two storage-owning states.

## 3. Head-dependent recharge inside a MODFLOW iteration

### UZF1

The USGS documentation for the MODFLOW-2005 UZF1 package describes recharge to
the water table as head dependent and therefore coupled inside the MODFLOW
iteration loop.

This is useful because it demonstrates a standard MODFLOW pattern:

```
Q(H) = HCOF * H - RHS
```

can represent a nonlinear/head-dependent **flux** response.

The existence of an HCOF slope does not tell us what physical object that slope
represents. It may be a flux derivative, a sink derivative, a conductance, or a
storage-related response.

DSW-07, DSW-12 and DSW-13 make this distinction explicit.

Reference:
USGS MODFLOW-2005 Unsaturated-Zone Flow Package documentation, UZF1.

## 4. External coupling tools

### HMSE, Pawlowicz et al. (2024)

HMSE provides external coupling between MODFLOW-2005 and HYDRUS-1D. Published
modes include recharge from HYDRUS under a prescribed/fixed water-table
assumption and periodic updating of the HYDRUS water table from MODFLOW.

Reference:
SoftwareX 26, 101680.
DOI: 10.1016/j.softx.2024.101680.

This again illustrates that software interoperability does not determine the
coupling mathematics. The same two model families can be connected using
different information-exchange contracts.

## 5. General partitioned multiphysics coupling

Hydrological model coupling is part of a broader class of partitioned
multiphysics problems.

### Rüth et al. (2021)

B. Rüth, B. Uekermann, M. Mehl, P. Birken, A. Monge and
H.-J. Bungartz,
"Quasi-Newton waveform iteration for partitioned surface-coupled multiphysics
applications",
International Journal for Numerical Methods in Engineering.
DOI: 10.1002/nme.6443.

The work treats iterative coupling between black-box subsolvers as its own
nonlinear/fixed-point problem and applies interface quasi-Newton acceleration
to the coupling variables.

### Degroote and Vierendeels (2012)

J. Degroote and J. Vierendeels,
"Multi-level quasi-Newton coupling algorithms for the partitioned simulation of
fluid-structure interaction",
Computer Methods in Applied Mechanics and Engineering.
DOI: 10.1016/j.cma.2012.03.010.

The work is not hydrological, but the numerical distinction is relevant:
subsystem solvers and the coupling iteration are separate algorithmic levels.

### Relevance to DSW-09

This literature provides useful terminology for the problem now exposed by
DSW-09:

```
inner/subsystem solve state
!=
outer/coupling fixed-point state
```

If the external coupler changes the affine SWAP-MODFLOW response after a
MODFLOW outer iteration, any solver acceleration history retained by MODFLOW
belongs mathematically to a previous assembled residual unless equivalence is
demonstrated.

This does not imply that SWAP5 should adopt an interface quasi-Newton method.
It does imply that coupling acceleration and MODFLOW's own nonlinear
acceleration should be treated as different algorithmic objects.

## Working taxonomy for SWAP5

Use the following terms consistently:

| Term | Physical meaning | Typical mathematical form |
|---|---|---|
| shared phreatic state | one water-table degree of freedom and combined storage used by both models | `h_phreatic,swap=h_phreatic,mf` |
| shared interface head | one hydraulic head imposed/matched at a declared coupling plane | `H_interface,swap=H_interface,mf` |
| combined storage | change of total physical water volume with shared state | `dV_total/dh` |
| physical q-link | flux between two distinct physical states | `C(h_a-h_b)` |
| atmospheric/recharge contribution | external water entering the coupled control volume | prescribed or process-computed `R` |
| state-dependent sink | physical removal controlled by state | `ET(h)`, `q_d(h)` |
| response tangent | derivative used to linearize a model response | `dq/dh` |
| coupling residual | mismatch defining the outer coupled nonlinear problem | `F_cpl=0` |
| subsystem convergence | convergence of one model solve for the currently assembled equations | model-specific criterion |

Two quantities having the same units is insufficient evidence that they belong
to the same row in this table.

## Implication for the SWAP5 research program

The next production-level coupling contract should be defensible in this
sequence:

1. define the physical control volume and shared/disjoint states;
2. assign storage ownership exactly once;
3. define physical external and interface fluxes;
4. derive the coupled residual;
5. derive response tangents only after the residual is fixed;
6. define which iteration level owns relaxation/acceleration;
7. qualify time-step and nonlinear convergence separately;
8. map real SWAP state/response onto that already verified contract.

The dummy-SWAP testbank exists to close steps 1-7 before real Richards physics
is allowed to obscure them.
