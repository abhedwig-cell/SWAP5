# Rational retention storage across saturation

HIST-INTEGRATION01, baseline `3f1b2e5eca5881e5e6739686aa1338dc9ebd5267`.
The original112-node/eight-layer Andelst matrix projection is the owning
counterexample. At day9.276596662442488, pond drydown crosses saturation.
The default provider's rational near-saturation retention branch previously
used theta_new-theta_old across h=0. Cancellation injects pressure corrections
of order1e-11cm while the unchanged solver requires1e-12cm. Compartment and
total balances already satisfy their gates; retries do not remove this noise.

The existing provider evaluates exactly the same rational retention difference:
c42*(min(h_new,0)-min(h_old,0))/((1+c41*min(h_new,0))*(1+c41*min(h_old,0))).
Admission is limited to continuous-conductivity mode, no elastic storage,
c9<=H_CRIT, both heads in the existing rational branch, at least one head>=0.
All other provider arithmetic is byte unchanged. No retention/conductivity law,
solver, time-step/pressure/mass tolerance, physical selector, public interface,
state/restart schema or default changes. Invariants7/13/21/23 are preserved.
Earlier private consistent-Jacobian, damping and seed probes fail and are kept
as failed evidence; none is production implementation.

Select the real production provider against independent real128 retention
subtraction, eight literal source soil rows, drying/wetting/zero/positive and
branch guards at checked O0/O2. Prove old rounded subtraction loses increments
while the repaired value remains accurate. Preserve default/OFF, elastic and
out-of-domain branches. Public .mod identity must remain exact; compile only
the changed provider and relink actual consumers using source/compiler/flags/
artifact-bound predecessor objects. Retain compilation, native and check costs.

Select the original matrix481-day route at O0/O2 and independent day365 restart;
expected up to1800s per native process, explicitly selected for the historical
crop/year lifecycle missed by the old12-node profile. Bounded execution must
retain failed/censored results; do not repeat completed unchanged commands.
Check exact endpoints/temperature/SPEV/SAEV/restart and resumed budget tail,
water and solute1e-10, independent gross water1e-10, roots1e-12 and existing
per-step energy1e-9. Original macro/Rutter remain explicitly excluded; chemical
input is the supplied fixture, not historical SWSOLU0 equivalence. Do not claim
full original equivalence or migration if this repaired subset passes.
Retain admitted old component/application evidence on unchanged branches;
run affected current source/raw owners and proportional selected controls.
No broad FCI, new1e-6, heavy low-air, RossFast or new process/framework campaign.
