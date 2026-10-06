# PPA-MICRO04 source horizon table binding

Status: proposed additive standalone adapter. Parent: MICRO02 MvG table
sampling; MICRO03 bounded normal uptake runtime remains limited to homogeneous
rooted hydraulics. No canonical or heterogeneous production admission.

B1.11 `get_MFLP_K` initializes one table per soil horizon by sampling
`nod1lay(lay)`, then uses `layer(jLayer)` to select that horizon's table for a
rooted node. The typed adapter accepts an optional `horizon_first_node(:)` of
length `active_nodes`. Its value at each node is the first node of that node's
contiguous horizon. The map must start with 1, be nondecreasing, point no
deeper than its node, and each new representative must point to itself.
Invalid maps publish no tables. With no map, the existing per-node behavior
and MICRO03 production restriction remain unchanged.

The adapter samples MvG conductivity at each horizon's first node on the
MICRO01 corrected 430-point grid, dry endpoint and saturated endpoint. It
copies that immutable table to all nodes of the horizon. This maps the
source's *selection* semantics; it does not establish a literal MvG source
numerical equivalence, including the separate B1.11 `ksatfit(lay)` wet
extension. A later work unit must compare that source path and wire an
explicit horizon map into the production parameter owner before allowing
heterogeneous rooted profiles.
