# A27 real constitutive domain gate

Date:2026-10-02. Status: PREREGISTERED_RESEARCH_ONLY.
Branch baseline:51ef1fc8b42eaa163804b23ab447a3d2d9cdfaa4. Canonical:7a629a10cabb3553ff77474423e6ccac81b29aec. Delta since0d44f0195 is LOW03 prerequisite documentation/control only; no AGENTS, Status-A or production dependency change. Current A26 first-order split and production ownership stay unchanged.

## Prospective dependency gate before moving-contact implementation

The previous fixed-wall profile stores theta alone and uses a synthetic positive finite D(theta). Before making it a general wet-wall representation, check whether the actual SWAP constitutive domain admits a unique inverse h(theta) and a physical, timestep-independent D=K*dh/dtheta. A negative result is a representation-domain falsifier, not a failure of all RFM routes or a universal need for monolithic nonlinear coupling. Do not implement later moving-contact/receiver phases using a known invalid closure.

Read actual b110_default_mvg_provider, especially watcon/moiscap/hconduc; compile it with its actual contract, without production edits. Use all36 repository Staringreeks2018 catalog rows (wcr,wcs,alpha,n,lambda,ksfit). Unlike the previous A27 Ks1/5 ablations, these runs use the catalog ksfit without adjustment. This is existing parameter authority, not new measured-soil validation. Set cofgen9=0, no KSATEXM, no physical elastic storage, matching the default-MvG branch; retain the source near-saturation continuation and capacity floors.

Sample heads[-2000,-200,-20,-1,-0.1,-0.02,0,1,5]cm at dt[0.1,0.01,0.001,0.0001]day. Export theta,K,actual provider capacity,K/capacity and independent central finite-difference derivative of the **actual retention output** at unsaturated heads, epsilon=max(1e-7,abs(h)*1e-5). For h>=0 report derivative0 from the actual retention plateau, not from a symmetric derivative across h0. Check bounds, nonnegative K/C, unsaturated capacity versus retention derivative where no numerical floor is active. O0/O2 output must agree byte-for-byte. Persist all raw rows, source hashes at their run SHA and negative findings.

Prospective representation falsifiers:

1. If theta(h0)=theta(h1) at distinct saturated pressures while saturated signed Darcy differs, reject theta-only state as a **general** unsaturated+saturated wall closure. It may remain suitable in a restricted unsaturated domain or with additional pressure/physical-storage authority.
2. If provider K/C changes with dt at fixed physical state because C is a numerical capacity floor, reject treating that ratio as a timestep-independent physical diffusivity. Do not remove the floor from the production solver or introduce an arbitrary physical storage to hide this result.

For each catalog row, independently calculate steady saturated horizontal Darcy q=Ks*(h_wall-h_matrix)/10cm for h_wall5cm and h_matrix[0,1,5,9]cm. All matrix theta and K remain identical at these pressures with elastic storage disabled. Positive, zero and reverse flux must survive. This is an analytic source-backed steady-flow counterexample, not a production runtime or an actual receiver evolution. A theta-only diffusion law with the same saturated theta at both boundaries yields zero flux; record its discrepancy.

Adjudication must distinguish active-source/numerical regularization, physical retention derivative, unsaturated diffusion applicability and saturated pressure exchange. If either gate fails, stop the general theta-only implementation route and write a concrete replacement design boundary: mixed moisture/pressure representation or restricted unsaturated profile plus separately owned saturated pressure exchange. Moving-contact, closed receiver feedback, full production A/B/C and timing remain OPEN until that boundary is explicit and tested. Do not reinterpret the earlier128-cell diagnostic pass as production validity. No source ABI, restart, top receipt, MB routing or canonical admission changes are authorized by this experiment.
