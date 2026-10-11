# PPA-WU05-E restricted live FMR envelope

Status: implementation contract and local prototype verification, not qualification
or canonical admission. Base: `fe574db8ca657b173d8badc79a8d4eb2d6e848a8`.

The recovered live binding advances conservative mobile matrix and per-domain
macropore salt in the same cloned physical candidate as Richards water. Jarvis
reads concentration from matching salt mass and water. It owns no salt state.
The full/half metric includes each salt compartment with an explicit positive
mass tolerance; water and salt tolerances retain their own units.

The supported numerical route is Reference Richards with external full/half
acceptance and macropore continuation. Matrix storage is theta times node
thickness times the immutable matrix area fraction, matching canonical water
storage. Initialization, root concentration and transport all use this same
effective thickness. Static fractions must be finite, positive and at most one.
Dynamic shrinkage remains rejected until geometry-driven salt transfers have
their own owner. Snow, frost,
soil temperature, evaporation continuations, drainage-response scheduling,
RFM, and fixed-weir surface-water combinations are outside this live envelope.
Macropore top/return, covering and rapid external outflow remain rejected by
the salt step. Boundary concentrations are prescribed upstream soil-interface
values, not a surface or dynamic aquifer mixing model.

Fresh initialization shall call a typed FMR profile initializer with explicit
node and domain concentration arrays in mg/cm3 and the matching water state.
It creates the optional salt component only after the process initializer
validates all shapes, finite/nonnegative inputs and inventories. Failure must
leave the original physical state unchanged. An existing salt component causes
rejection, including after restart: restarting never reapplies initial profiles.

Verification must force salt-driven temporal rejection after successful water
and salt candidate advancement, verify unchanged committed water/salt, and
exercise adaptive retry as well as discard/replay/commit and Restart v4.
An opt-in accepted-substep trace shall carry each salt receipt with its water
substep. The existing attempt-context snapshot/restore must roll these receipts
back with the water trace, so rejected full/half attempts cannot enter the
interval ledger. Summing accepted external and root receipts must reproduce
the candidate inventory change independently of the last-substep diagnostic.
Independent reference/stability qualification remains required before admission.

Affected invariants: 3, 4, 7, 8, 13, 23, 27. No new commit owner or second
root-water receipt is introduced.
