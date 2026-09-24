# PPA storage-difference opt-in contract

Baseline: 4a8117e9f6c6a2cb49227cbc5218ab0a11d3352e.
Status: implementation contract for bounded candidate integration, not canonical admission.
Evidence basis: PPA_MVG_RESIDUAL_EXPERIMENT.md and PPA_MVG_STORAGE_DIFFERENCE_STATUS.json.

Owned surface: explicit numerical storage-difference service, reference residual
evaluation, serialized backend/application forwarding, candidate tests. Shared
interfaces allowed to change: append a default-null procedure pointer to the
hydraulic evaluation context and application configuration, a backend setter,
and an optional final argument to standalone serialized dispatch. Existing
constitutive evaluate ABI, HeadCalc argument list, physical state, restart payload,
mass accounting, temporal-indicator service and all tolerances remain fixed.

The service receives a read-only constitutive provider, base heads, base water and
trial heads; it returns a vector theta(trial)-theta(base) and availability. It must
return unavailable for incompatible providers, branches or inconsistent base
water, and must not mutate inputs. The MvG implementation preserves the existing
binding's exact base-water check and atomic vector result. Unavailable means the
original rounded subtraction, never a repair of state. A null service retains
the original reference route. Service binding is execution configuration, not
physical state and not serializable: a fresh backend must explicitly rebind.

HeadCalc consumes the service only for explicit fixed-flux top, bottom mode 7,
no active macropores and an explicit constitutive provider. Scratch is call-local
and allocated only when used. Only vector_F storage terms change; vertical-flux
reconstruction and independently rounded-state transaction ledger stay unchanged.
The application rejects the option for non-mode-7 profiles. No implicit activation
from the separate free-drainage temporal-indicator option is permitted.

Affected invariants: 3, 5, 7, 13, 23, 25, 27, 30. Review: no new state owner, no
physical option conflation, no relaxed mass gate, default reference retained.
Required gates: provider oracle/guards, direct opt-in versus qualified experiment,
unavailable/default preservation, mode-2/5 regression, owner configuration guards,
strong owner composition, restart/rebind and accepted source-window receipts.
Canonical admission is a subsequent integration/qualification decision, not
implied by local implementation. Local commits only per requested campaign scope.
