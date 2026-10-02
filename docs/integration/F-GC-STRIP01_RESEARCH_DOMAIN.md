# STRIP01 isolated experimental domain contract

Status: research specification within the user's STRIP01 experimental mandate.
Not production admission and not a revision of the fixed-interface authority.
Production bootstrap, shared interfaces, solver equations, ledger and restart
schemas remain unchanged. Research code lives only under tests/fgc/strip01.

The earlier prerequisite overstated the need to stop all experiments. Central
review is required to widen shared production ownership; an explicitly isolated
test harness may falsify this declared alternative without using or weakening
the restricted production bootstrap. No inference to a supported application
route follows merely from a successful harness.

## Disjoint physical ownership before coupled output

SWAP occupies land elevation 0 to -6 m. MODFLOW occupies -6 to -10 m. The
interface elevation is -6 m and initial head is -4.5 m. MODFLOW is confined,
with Kx=0.5 m/d, thickness 4 m, Ss=1e-5 1/m and no Sy. This Ss describes only
compressive storage below SWAP. All water-table storage above -6 m belongs to
SWAP. No standalone phase-A Sy is transferred into the overlapping domain.
This is a different conceptual model from phase A's whole-aquifer Dupuit case;
its lateral transmissivity is 2 m2/d, not the phase-A thickness-dependent T.

One MODFLOW DRN at the first cell owns the only lateral drainage route, stage
-5 m and conductance 100 m2/d. SWAP drainage, roots, ET, runoff, macropores,
temperature and snow are off for the first test. A top flux of -0.1 cm/d is
positive inward rainfall of 1 mm/d. First geometry is 30 uniform SWAP cells
of 20 cm. B01 hydraulic row is copied from the pinned qualified testbank.

Existing FMR Reference backend performs real Richards trials and existing
head materializer maps the fixed-plane head. Each corrector starts from a
captured committed origin. No prescribed-GWL shortcut or lateral SWAP drain.
The initial profile is hydrostatic at -4.5 m. The groundwater head must remain
above -6 m; leaving this domain fails the research gate.

Freeze before results: native column mass tolerance 1e-12 cm, coupled volume
residual 1e-8 m3 per accepted window, interface source/exchange difference
1e-10 m3/d per cell, maximum 40 outer evaluations. Interface rates derive
from integrated accepted-trajectory exchanges divided by window duration.
First component panel uses windows 1e-4, 1e-3, 1e-2 d without loosening the
existing 1e-5 cm temporal head budget. Failure is diagnostic, not permission
to increase that budget. Qualified window selection precedes coupled output.

The phase-C balance is rain minus DRN equals SWAP storage change plus disjoint
compressive MODFLOW storage change. The interface ledger, if used later, is
transfer accounting only. Native storage terms are checked separately.
Replay uses the same physical accepted origin and must not mutate it.
Only after C has passed may a longer weather/Hupsel sequence be interpreted.
