# Contact memory and macro liquid thermal transport

Status: proposed explicit research model; baseline `65d881cc9`.

The original binary sorptivity-history branches remain immutable. For the
research sliding-contact completion, a positive fraction uses the active
sorptivity seed and advances an equivalent action clock. Let r=sqrt(tau),
d=sqrt(tau+dt)-sqrt(tau), and lambda be the full-column contact fraction.
The completed clock is (r+lambda*d)^2; the reference-water increment uses
lambda*d with the existing wall/wet/domain/diameter and seed factors. This
matches the convex sorptivity action, rather than assuming the fraction is
elapsed physical time. Zero resets exactly as the off branch; one delegates
exactly to the legacy on branch. Darcy-ended histories remain reset. Other
cells retain identical branch histories; disagreement there is refused.
This is an explicit corrected research policy, not original-model equivalence.

Macro liquid energy is a separate finite-volume inventory with explicit initial
temperatures. The accepted hydraulic ledger supplies water stocks, oriented
faces and matrix exchanges. A conservative implicit upwind temperature solve
advances liquid enthalpy on refined time slices using interpolated water stocks
and explicitly declared donor-temperature paths. Dry through-flow cells are
algebraic mixing cells; isolated dry cells have no thermal inventory. Signed
matrix heat exchange and external enthalpy are returned independently. Missing
nonzero inflow donors, incompatible water ledgers, and invalid initial states
must refuse without modifying input state. Constant heat capacity is explicit;
no macro solid/gas heat or matrix conductive feedback is silently added.

Native initial thermal equilibrium and prescribed external donor scenarios must
be explicitly labeled model inputs, not historical measurements. Refinement and
manufactured mixing/closed transfer tests qualify the numerical transport rule.
Full physical energy still needs matrix feedback, gas/latent/radiation and
phase-specific top receipts. Native contact continuation may be promoted only
through the owning existing transaction gates. Counts remain2/3 and0/3.
