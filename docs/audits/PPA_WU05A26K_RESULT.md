# PPA-WU05-A26K result — IC hydrostatic macropore head

Date: 2026-10-01
Status: QUALIFIED
Qualified postimage: c6a8f1ee680f7e6f919bb3651a582bf2c1cbfb37
Qualification run: 36895639027 — SUCCESS

Focused gate:

    PPA_WU05A26K_IC_HYDROSTATIC_HEAD=PASS

## Qualified mapping

Using positive-downward depths and the A26J stored-water column height H:

    d_water = d_endpoint_bottom - H
    h_mp(node) = d_node - d_water
    Delta h = max(0, h_mp - h_matrix)

This is the depth-coordinate form of the source-backed hydrostatic relation h_mp = phi_mp - z.

The matrix node must lie inside the represented endpoint contact segment; otherwise the mapping fails closed.

Qualification oracle:
- endpoint segment 80..100 cm;
- H = 10 cm -> water level depth 90 cm;
- matrix node depth 95 cm -> h_mp = +5 cm;
- matrix pressure head -30 cm -> Delta h = 35 cm.

No zero-head shortcut is used.
