# Reconnect complete original WOFOST accepted-rate interface

Read-only43821758579 exactly reproduces ownD warm/cold531 mismatch with original
executable relinkSHA exact and121componentfields. Plant CO2/ET/current states are
reconstructed by original crop initialization before Meteo3, but exported grrt,
drlv, grrtpot and some inactive leftover parameters remain different. No hydraulic
or thermal vector/cache difference is present in this snapshot except the known
public top cache and prior q0. The two prior isolated cache repairs remain rejected.

Original update_rootextension reads plant_interface grrt/grrtpot to enable and
limit root extension; update_rootdistribution uses complete exported root rates.
Existing hybrid_apply_wofost restores both whole original25-field WOFOST_rates
objects after original crop initialization, but never calls the original
update_wofost_interface(s_pot,r_pot)/(...s_act,r_act) owner. That routine assigns
all exported WOFOST states/root rates and updates assimilation output counters.

Revised complete-component composition hypothesis: after restoring both original
rate objects at the existing conditional emerged/pending seam, call BOTH original
interface-owner routines, unchanged. No new copied assignments, physical formula,
rate recomputation, isolated cached grrt field, time policy or tolerance. No new
serialized physical state is needed if the existing complete rate objects suffice.
Preserve the original helper's counter behavior and record it rather than silently
skip its updates. Its source remains original; warm pendingfalse path must remain
physically exact. This is a larger original interface connection strategy, not a
third local coefficient-cache repair.

First only a pinned sourceD PRIVATE diagnostic variant: rename BUILD, verify
all carrier/source/object/compiler/native identities and unmodified relinkSHA,
modify only private hybrid_apply_wofost to call both original owners. Recompile
wofost/main/trace/swap, publish no accepted checkpoint. Compare original warm531
exactly and cold531 against that actual warm; record result BEFORE asserting so
any new failure is retained. A private one-day PASS does not activate current
public water-only history. If supported, implement only explicit new experimental
water-history scope with a documented build-bound interface strategy and fresh
current full/native O0/O2, transactions/corruption and unchanged predecessor checks.
No mixed old/native bundle rebinding or whole-science/energy promotion.
