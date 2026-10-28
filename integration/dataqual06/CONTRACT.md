# DATAQUAL06: variable surface macropore conductivity

Baseline cba2117d679fe1165cc03c60e86e67943a777466, RT/HY/VQ, issues1458/1386.
DATAQUAL03–05 already integrated; retain their evidence unchanged.

Implement original MPVOLUME(case1) KsMpSs law from the raw B1.11 source:
min(1000,max(1e-14,2*7.2e8*(diameter*(1-sqrt(1-area)))**3/diameter)).
Use the already residual-synchronous candidate surface area supplied by the
macropore geometry owner. No saved conductivity, new restart payload, inferred
combination whitelist or numerical tolerance changes. Diameter is immutable
physical configuration. Default zero diameter selects the unchanged fixed-K law.
Source import and direct native consumer require explicit experimental execution
for variable conductivity. Production Reference retains its fixed-cap restriction.

Invariants2/3/7/13/21/23/25: kernel remains IO-free; candidate geometry is never
committed by boundary evaluation; original physical law and numerical policy remain
separate; budget, rollback, restart and source binding remain mandatory.

Qualification: checked GNU13.3 O0/O2 real dynamic-top/adapter law and head derivative,
independent source arithmetic, unchanged fixed-K branch, invalid inputs; actual
low-volume original-derived storms and short selected parameter batch; selected
full/split restarts and O0/O2. Compare unchanged production physical streams against
baseline. Independent water certificates <=1e-10cm as inherited owner criterion,
finite state/temperature and exact target/restart. No full energy/solute/N/parity
claim. Scientific comparison variants require actual matching431 inputs/output.

Expected builds1–3min each, four isolated workers at most1GiB each, native timeouts
30s short cases/120s selected storms; preserve failures and checkpoints. No unchanged
2.848675 probe, seasonal run, highest low-air or full F-CI selected. Changed top
provider/adapter require focused FCI93 oracles before any canonical admission.
