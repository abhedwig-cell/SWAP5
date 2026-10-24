# Proposed organic-first daily composition

Research successor to PR1432, baseline9d888c03643427bd7f5426a3bbf470fb5fbf5c4a.
Compose the bounded multi-pool organic proposal with real production rate,
storage, daily mineral exchange and final inventory-owner interfaces. No
production source, caller or default is changed. Invariants7 and13 remain hard.

Explicit proposed splitting policy: advance organic kinetics over the day
using the initial NH4 supply, then advance mineral transport/reactions/crop/top
exchange over that same day from the organic candidate. Do not count two days.
Organic immobilisation has access before crop and top sinks. Use the actual
constrained carbon receipt in the production reaction-rate environment. Set
the later mineralisation source to zero, preventing double counting. Preserve
nitrate until the mineral substep. Compose final organic/mineral endpoints and
the exchange's external ledger against the original daily committed state.
Any later failure returns the entire original state. Partial receipts are
diagnostic and never an accepted state.

This is an operator-split scientific proposal, not simultaneous kinetics or a
recovered historical identity. It deliberately postpones mineral boundary
input until after organic limitation, and prioritises organic use of initial
NH4. It is not a generally accepted allocation policy. Uniform C fraction0.45
and the multi-pool arithmetic domain still apply. No persisted runtime/restart
or Full Richards composition is claimed by the direct daily seam.

Selection:24 initial configurations, each six successive days, at O0/O2.
Vary initial NH4/NO3, crop demand and chemical reaction activation. Use actual
juvenile NH4-first demand and the admitted proportional crop/top option; root
and lateral/bottom transport are zero in this fixture. Compare all organic and
mineral endpoints, carbon/rates, nitrification, denitrification, crop/top actual
and unmet receipts with independent event-driven ODE suboperators. Validate
whole C/N budgets. Inject invalid temperature after completed organic work
each day and assert exact whole-state rollback. Expect under60s; preserve raw
commands and measured cost. Replay previous proof/source/docs gates. No new
production delta selects Richards/HIST/broad FCI.
