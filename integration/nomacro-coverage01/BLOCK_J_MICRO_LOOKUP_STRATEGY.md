# Complete initialized original microscopic lookup context

Read-only43825562534 exactly reproduces sourceD mismatch and inventories all165
implicitly saved numeric Variables fields. BEFORE_DRAIN2 root profile qrot already
differs by3.721794846617277e-7cm/day, before SoilWater/headcalc. Drain module itself
is exact after Drain2. Retained physical mismatch is not repaired by the complete
WOFOST interface replay; public implementation remains unchanged.

Original RWU_micro.do_RWU_micro(Init)->RWU_micro(Init)->get_MFLP_K(1) allocates
M_table/K_table801 x numlay and preprocesses current original watcon/hconduc for
each horizon. It is called only at crop/root initialization. Hysteresis then
changes original scanning state, but continuous execution retains that crop's
initial M/K tables. Native cold initialization reconstructs them using later
accepted scanning curves. The original Rate branch reconstructs its numerical
work vectors/guesses each call. Thus tables are candidate historical physical
preprocessing context, not a new formula or a numerical tolerance proposal.

Preserve BOTH complete initialized arrays owned by get_MFLP_K, with dimensions,
accepted clock, crop identity, drought selector and microscopic model context.
Original initialized domains: M_table1..start, K_table1..start-1, where original
start=int(100log10(20000))=430; allocated capacity801. Rows above that are undefined
original allocation, never physical accepted data. Do not serialize/zero/validate
undefined tails as if they were physical. Original dry-edge reads near wiltpoint
can touch undefined cells; that original reference limitation stays separate and
is NOT repaired here. No original lookup formula, interpolation or solver changes.

First private sourceD three-way discriminator: verify original carrier/pinned
source/compiler/noop relink. Recompile original RWU component at ORIGINAL PROVIDER
O2+sameFP (other touched donor/controller staysO0), adding only diagnostic capture
and replay. Warm531 must exactly reproduce retained warm. Baseline cold531 must
exactly reproduce retained cold. Capture initialized full M/K context at actual
warm530 with clock/crop/mode/shape binding; replay only AFTER original cold crop
and root initialization and BEFORE first root-water-rate calculation. Reader
validates all metadata and finite nonnegative defined cells in temporary arrays
before assignment. No accepted checkpoint publication or old-build rebinding.
Then compare restored cold531 to actual warm, including all physical receipt
fields. Record a failed discriminator before asserting so evidence is retained.

This is a complete original preprocessor state-block strategy, not a third
isolated coefficient-cache tweak. If supported, a separate public contract must
handle crop transitions/absence, distinct native schema/policy binding, malformed
state and fresh current-source complete O0/O2/native/transaction preservation.
A private one-day PASS alone neither activates water-only history nor promotes
scientific equivalence, arbitrary history or complete physical energy.
