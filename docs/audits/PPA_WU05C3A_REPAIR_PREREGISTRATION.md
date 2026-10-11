# C3A source-bound boundary repair preregistration

Date: 2026-10-02
Baseline: 91534e7be40f9d1d234ff62cc531c45906283472
Canonical: 828df126e0c0d70f5cbfae51614bfc3b53e832a4
Status: IMPLEMENTED / QUALIFICATION_PENDING

Exact B0 distribution was recovered and verified. tools/vq/b1_11_reconstruct.py
completed qualified_reconstruction=true: 63 members, 1886519 bytes, manifest
24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2.
oxygenstress.f90 is 8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87.

Source rules (corrected oxygenstress lines 172-188):
- gas_filled_porosity=max(0,theta_sat-theta).
- h>=0 forces gas_filled_porosity=0.
- GFP<1e-4 returns RWU=0, C_macro=0, C_top(node+1)=0 before waterfilm/SOLVE.

Repair keeps these rules in ordered profile-call scratch, not accepted state.
Immutable dataset and dynamic runtime view receive finite/shape validation.
REFERENCE-only admission policy is unchanged. No new mass booking is introduced.
No-root/zero-root-extraction execution preserves the incoming sink without accessing
unneeded current views, after fail-closed configuration selection.

Required gates: original boundary falsification test now PASS; dynamic runtime seam
OFF/active/unsupported/no-root/zero-extraction/non-rooted preservation; NaN/Inf/shape;
saturated, pressure-head saturation, threshold neighborhood and vertical propagation;
existing C3Q/C3P focused gates. Current application binding is still a separate
incomplete action. Passing these repairs alone does not authorize canonical admission.
