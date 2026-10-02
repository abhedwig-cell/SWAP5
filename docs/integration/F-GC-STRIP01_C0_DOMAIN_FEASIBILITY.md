# F-GC-STRIP01 C0 domain feasibility and preregistration

Status: **preregistered domain, now groundwater-component qualified; real first window rejected; not production admitted**.

Current execution and recovery supersede the prospective statements below: [C0/C1 qualification and response findings](F-GC-STRIP01_C0_C1_QUALIFICATION_AND_RESPONSE_FINDINGS.md). Native C0 and local C1 component qualification passed; both real 50-column attempts rejected without committed-state change. F-GC-STRIP01-RESP01 is the immediate numerical/profile qualification prerequisite.

Canonical source pinned to `53059a5225fa45cd6121d4bc4c7310dcc4e0660c`. The A/B qualification remains unchanged. This document resolves the candidate domain choice for research, while preserving the production authority guard.

## Physical domain

The proposed C0 soil domain is surface 0 m to fixed plane -6 m. A confined, fully saturated MODFLOW layer occupies -10 to -6 m, with K=0.5 m/d and constant T=2 m²/d. These intervals share a face and no storage volume. Heads must remain above -5.999 m and below surface. The DRN stage is -5 m, conductance 100 m²/d, solely in the left MODFLOW cell. Right and base remain impermeable.

This differs explicitly from the A/B convertible aquifer. It cannot inherit its Sy=0.2 or its Dupuit squared-thickness law. For C0, MODFLOW has **no STO package**, no recharge package when coupled, and zero variable physical storage. The SWAP columns own all changing physical soil storage, including the freatic zone above the coupling plane. The lower layer's constant saturated water volume cancels from storage differences. No new independently additive regional storage authority is required for this limiting model.

The lower-domain continuum uniform-source oracle is
`H(L)-H(0)=R L²/(2T)=0.625 m`.
At cell centres, including finite DRN conductance, the right-cell rise above drain stage is 0.613 m. With a 0.001 m³/d source only in the far cell, all 49 internal faces convey that source toward the drain; the right-cell rise is 0.02451 m. A finite-volume matrix solve and independent cumulative-face-flow recurrence agree within 1.8e-13 m.

These are prescribed-source analytical results, not real SWAP or native MODFLOW results. The script also rejects net extraction, the nonunique no-source/inactive-DRN case, and surface emergence. An attempted fully dry forcing sequence must not be patched with artificial recharge or hidden head fixing.

## Executable authority check

Generic topology already represents `GW_DRAINAGE_OWNER_MODFLOW=3` and independent storage labels. Structural validity does not mean production admission. The current production bootstrap explicitly allows only `HEAD_STATE_CAPACITANCE` and drainage owner `NONE`.

The local O2 guard extends the existing PPA-WU01 bootstrap test. It proves:
- MODFLOW-drain topology materializes structurally;
- the production bootstrap returns `FMR_APP_BOOT_PROFILE_NOT_ADMITTED` with context handle zero for that topology;
- independent physical storage is likewise refused;
- restoring the existing NONE/head-capacitance profile still passes the existing production context, stale-origin and ownership gates.

All 309 recovered production source files matched Git blobs at the pinned canonical head before compilation; the compiled dependency manifest is persisted with the result. The qualified test fixture uses the existing four-node bootstrap grid: it qualifies the authority guard, **not** the proposed 6 m physical profile.

## Research seam and preservation

The user-authorized experimental workunit can preregister C0 and investigate it without changing the production bootstrap. A future explicit research driver may initialize the generic Fortran participant registry/application context, use the existing typed lower-face mode5 physics and Python prepared-solve service, and declare MODFLOW drainage ownership in its own research topology. Such a driver must be named and isolated as research; it cannot claim the ordinary production bootstrap admits active drainage.

The shared-authority prerequisite remains required for **production admission** of active drainage or independent physical aquifer storage. C0 narrows the immediate research problem: independent variable aquifer storage is eliminated; active drain ownership and a 6 m soil/application binding remain explicit research qualification requirements. No ABI or production source changes were made.

Per accepted window, interface exchange cancels exactly once:
`P-ET-runoff-Q_DRN = delta_S_SWAP`.
The coupling ledger owns no storage. The profile JSON freezes initial mass limits and saturated-domain bounds before a real coupled run. A groundwater head is still a fixed-face hydraulic head, not a demanded match to SWAP phreatic GWL.

## Reproduction and next gate

```bash
python tests/fgc/strip01/domain_oracle.py --output /tmp/strip01-domain.json
python tools/run_f_gc_strip01_domain_guard.py --build /tmp/strip01-domain-guard
```

The next meaningful numerical gate is a **native no-STO confined strip**, followed by the explicitly research-only real-SWAP context driver. C/D/E are not executed or qualified by this document. Source-backed sand/grid initialization, resolved ET/weather binding, real far-column transfer, reject/replay and committed restart remain open. The public Hupsel input candidate is available but its typed application binding remains unqualified.
