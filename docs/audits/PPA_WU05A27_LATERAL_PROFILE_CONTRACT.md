# A27 bounded lateral profile contract

Date: 2026-10-02. Status: PREREGISTERED_RESEARCH_ONLY.
Branch baseline:b729aef1af3ec9ceca4f679ab32fcc126afa974d. Canonical:0d44f0195c94a9732c67b5e77f2148912df9bbc8, unchanged since last reconciliation. AGENTS, Status-A and A26 ownership remain unchanged. This extends the physical-mechanism frontier without changing production code, interfaces or admission.

## Question and model

Can a fixed number of lateral moisture cells preserve wetting feedback and interrupted-contact relaxation across specified nonlinear diffusion and drying hypotheses? This is a state-representation screen, not RFM theory reconstruction or production Richards equivalence.

Horizontal slab length10cm, initial theta0.20, saturated theta0.45. Conservative finite volumes solve dtheta/dt = d2Psi(theta)/dx2 with Psi'=D(theta). D=10*exp(beta*(theta-0.20)/0.25) cm2/day; beta=-2,0,2. These are prescribed positive diagnostic laws, not fitted soil parameters or validated retention/conductivity combinations. Use exact Kirchhoff potential differences between cell centres, wet-wall theta0.45, no-flow centre. During contact interruption choose no-flow or specified outward evaporation0.1cm/day. Evaporation is a controlled boundary hypothesis, not an atmospheric evaporation model. Stop/record if physical range0.05<=theta<=0.45 fails; do not clip state or hide water loss.

Grid edges x_j=10*(j/N)^2 for every case and N. No per-case tuning. Candidate N=8,16,32,64,128; reference N=256,512,1024. Fixed packed moisture state uses8*N bytes per wall patch; descriptors, solver workspace and flux accumulator excluded, no RSS/speed claim. Nonlinear reference shares governing equation and discretization family; independent constant-D analytic/spectral evidence checks implementation only in beta0. Nonlinear evidence is refinement, not independent physical validation.

## Cases, sampling and gates

Wet0.2day; optional externally owned pulse theta +=0.25*(theta_s-theta), recording exact added water. Interrupt for0.01 or0.5day under each dry boundary, then renew wet contact. Sample all phase endpoints and renewed times0.00025,0.001,0.01day. Three beta laws x two pulse choices x two dry boundaries x two gaps =24 cases per mesh. Preserve initial wet and dry endpoints, cumulative wall receipt, storage, external receipt, boundary loss and theta averaged over fixed lateral bands[0,0.1],[0.1,1],[1,5],[5,10]cm. Use cell overlap integration, not point interpolation.

Internal candidate screens against1024: max absolute storage/cumulative-wall-receipt error<=0.01cm; each band-theta error<=0.001 over all sampled endpoints. These deliberately reuse A27 research scale screens; they are not production E1 or field validity criteria. Report both gates independently and every failing case.

Reference gate512/1024: max storage/receipt difference<=0.0001cm and max band-theta difference<=0.0001. Also show256/512. If reference fails, retain all results and extend prospectively without loosening thresholds. Continuous beta0 wetting uptake at0.2day must agree with analytic finite-slab series within0.0001cm at1024. Temporal check: rerun all1024 cases with rtol1e-10/atol1e-12 versus nominal1e-9/1e-11; same0.0001cm and0.0001theta limits.

Use SciPy BDF with analytic sparse Jacobian and integrated wall flux, not a production solver. Ledger storage-initial-wall-external within1e-9cm for every sample. Preserve input arrays during trial, replay deterministically and reject unaccepted trial results in a small research-state semantics check. This is not production restart qualification. Persist exact code SHA, source hashes, package versions, raw results, all failures, refinement/case tables and reproduction script. Do not interpret single-run counters/timing as RFM speedup.

## Decision boundary

A pass supports only a bounded moisture-profile research representation for the declared fixed full-wall slab. Moving wetted contact geometry, nonlinear retention/conductivity mapping, actual matrix feedback coupling, signed pressure exchange, vertical fluxes and full A/B/C remain separate open gates. Existing top-input ownership, MB deep receipt, no passage exchange for leading MB, A26 first-order split and canonical admission ownership are untouched.
