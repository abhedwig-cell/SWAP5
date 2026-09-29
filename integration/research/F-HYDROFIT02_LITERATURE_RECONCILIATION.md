# F-HYDROFIT02 literature reconciliation — lambda and identifiability

This note contextualizes the BRO fitting results. Repository experiments remain the evidence authority for F-HYDROFIT02.

## Relevant literature

### Vrugt et al. (2003), Vadose Zone Journal

J. A. Vrugt and co-authors, *Toward Improved Identifiability of Soil Hydraulic Parameters: On the Selection of a Suitable Parametric Model*, Vadose Zone Journal, DOI: 10.2136/vzj2003.9800.

The paper analyzes identifiability of parametric soil-hydraulic models, including Mualem-van Genuchten, while explicitly accounting for parameter interdependence and nonlinearity. Its main relevance here is methodological: a low objective value alone is not evidence that a fitted hydraulic parameter vector is identifiable.

This supports the use of a separate conditioning/identifiability gate in F-HYDROFIT02. It does not determine the numerical threshold used here; that threshold remains the preregistered project rule.

### Schaap and van Genuchten (2006), Vadose Zone Journal

M. G. Schaap and M. Th. van Genuchten, *A Modified Mualem–van Genuchten Formulation for Improved Description of the Hydraulic Conductivity Near Saturation*, Vadose Zone Journal, DOI: 10.2136/vzj2005.0005.

The paper notes that the pore-connectivity parameter L is commonly fixed at 0.5 when conductivity is predicted from retention parameters, but that when retention and unsaturated conductivity measurements are available, L and other parameters can instead be optimized jointly or sequentially.

This is consistent with the F-HYDROFIT02 starting point: hard lambda=0.5 is a convention, not an empirical guarantee for every measured hydraulic record.

### Lambot et al. (2002), Water Resources Research

S. Lambot and co-authors, *A global multilevel coordinate search procedure for estimating the unsaturated soil hydraulic properties*, Water Resources Research, DOI: 10.1029/2001WR001224.

This work formulates the Mualem-van Genuchten inverse problem with theta_r, theta_s, alpha, n, Ks and lambda as estimated parameters. It also discusses negative fitted lambda values and the resulting difficulty of interpreting lambda literally as pore connectivity/tortuosity.

That is directly relevant to the BRO corpus, which contains strongly negative source lambda values. F-HYDROFIT02 should therefore treat empirical lambda primarily as a constitutive fitting parameter unless a separate physical-interpretation analysis supports more.

### Broader inverse-problem literature

Later inverse-identification work continues to describe non-uniqueness and convergence/identifiability problems for Mualem-van Genuchten parameter estimation. This reinforces the distinction between:
- optimizer convergence;
- objective quality;
- formal parameter-bound contact;
- local parameter identifiability.

## Reconciliation with F-HYDROFIT02

The literature is consistent with, but does not independently prove, the project findings:

1. fixing lambda=0.5 is not methodologically mandatory when conductivity observations are available;
2. fitting lambda jointly with alpha, n and Ks can expose nonlinear parameter trade-offs;
3. objective quality alone is insufficient to qualify a fit;
4. explicit identifiability diagnostics are scientifically defensible;
5. negative empirical lambda values should not automatically be rejected solely because the classical pore-connectivity interpretation becomes problematic.

The specific localized ridge found for BHR000000378532 0.65-0.75 m remains an empirical BRO result from this repository. No literature source is used to tune its lambda range, sigma, fallback or condition threshold.
