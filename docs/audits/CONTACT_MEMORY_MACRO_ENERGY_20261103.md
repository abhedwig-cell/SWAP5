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


The native hydraulic ledger has terminal dry-cell face residuals at roundoff
(maximum measured water amount about2.4e-16cm). The thermal solve uses the
algebraically equivalent incoming-storage form. It reports the predetermined
water-ledger defect times computed local liquid enthalpy separately from physical
external heat. This is not a heat residual fitted to close the energy gap.
The original strict input-water balance check is unchanged; dry inactive cells
retain unavailable temperature, and larger inconsistent water ledgers refuse.


Windows16.2 checked O0/O2 small and native gates pass. On the actual112-head
contact candidate, all three starts retain the full-column residual bound and
conservative macro lifecycle; the action-clock continuation is single-valued
and repeatable. The central fraction2.323069518e-4 gives an equivalent clock
3.242388493e-15day. The original off/on histories remain unequal as a retained
control; native rejected-state streams remain origin-byte-exact. This is private
candidate closure under the declared corrected rule, not a committed original
native interval or a full481-day qualification.

On194 actual hydraulic intervals (five domains,112 cells), independent macro
liquid temperature evolves from explicitly declared initial equilibrium. The
prescribed external donor is8+4*t C and the matrix donor path is explicitly
linear between archived endpoints. At64 slices per hydraulic interval the macro
stock change is-0.9454197402J/cm2, external net heat-2.5792600595J/cm2 and signed
heat delivered to matrix-1.6338403193J/cm2. Maximum interval energy residual is
1.219e-13J/cm2, with separately exposed total hydraulic-roundoff enthalpy about
-3.710e-13J/cm2. The macro/matrix temperature departure reaches1.8222C.
Matrix-transfer refinement differences contract approximately by four for each
fourfold refinement. These are modeled thermal replay results, not measured
historical macro/donor temperatures and not feedback into the legacy heat solve.

The independent production liquid-storage owner also verifies a closed two-owner
matrix/macro transfer. Missing actual nonzero top and matrix donors refuse;
invalid initial macro temperatures and inconsistent water ledgers refuse.
The small tests additionally cover time-dependent donor convergence, dry
through-flow and unavailable isolated-dry temperature. Full physical energy,
gas/latent/radiation and original native commit flags remain false.
