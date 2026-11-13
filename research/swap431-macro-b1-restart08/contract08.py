"""Source-bound contract analysis of existing evidence; executes no model."""
from pathlib import Path
import hashlib,json,re
R=Path(__file__).resolve().parent
P=R.parent/'swap431-macro-b1-retry07'
S=Path('C:/Users/Veldh012/swap431-state02-work/audit/build/swap-selected')
def save(name,x):(R/name).write_text(json.dumps(x,indent=2)+'\n')
def fields(p):return {s.split()[0]:list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
sources={n:(S/n).read_text(encoding='cp1252') for n in ['macropore.f90','macrorate.f90','variables.f90','swap.f90','swapoutput.f90','readswap.f90','timecontrol.f90','MOD_meteo.f90','headcalc.f90','soilwater.f90','temperature.f90','Boundtop.f90']}
spans={
 'native_matrix_writer':('swapoutput.f90',270,666),
 'native_unsupported_warning':('readswap.f90',1150,1161),
 'host_cold_init':('swap.f90',225,280),
 'host_daystart':('swap.f90',338,388),
 'host_commit_boundary':('swap.f90',440,454),
 'macro_cold_init':('macropore.f90',155,178),
 'macro_stock_seed':('macropore.f90',728,757),
 'macro_commit':('macropore.f90',1318,1484),
 'macro_rollback_seed':('macropore.f90',1669,1682),
 'crack_history_and_surface':('macropore.f90',1722,1885),
 'rates_reset_then_geometry':('macrorate.f90',67,132),
 'absorption_event_history':('macrorate.f90',1673,1744),
 'time_init':('timecontrol.f90',72,166),
 'daystart_dt_raise':('timecontrol.f90',168,222),
 'time_commit_next_dt':('timecontrol.f90',233,282),
 'forcing_clock_event_seek':('timecontrol.f90',425,493),
 'rain_window_daily_aggregation':('MOD_meteo.f90',1095,1147),
 'meteo_daily_and_step':('MOD_meteo.f90',1162,1395),
 'ET_context_and_event':('MOD_meteo.f90',1399,1484),
 'evap_reservoir_step':('MOD_meteo.f90',1497,1563),
 'Rutter_event':('MOD_meteo.f90',2202,2304),
 'reduction_hidden_counter':('headcalc.f90',376,393),
 'integral_shadow_wetwall':('macropore.f90',1184,1245),
 'native_heat_init':('temperature.f90',195,220),
}
maps={}
for key,(name,first,last) in spans.items():
    lines=sources[name].splitlines();assert len(lines)>=last
    maps[key]=dict(file=name,first=first,last=last,excerpt='\n'.join(f'{i}: {lines[i-1]}' for i in range(first,last+1)))
assert 'not implemented yet!' in maps['native_unsupported_warning']['excerpt']
assert 'call MACROSTATE' in maps['macro_cold_init']['excerpt']
assert 'WaSrMpDm(id) = WaSrMpDm(id) +' in maps['macro_commit']['excerpt']
assert 'TimAbsCumDmCp(id,ic) = TimAbsCumDmCp(id,ic) + DT' in maps['macro_commit']['excerpt']
assert 'VlMpDyCp(ic) > 0.d0' in maps['crack_history_and_surface']['excerpt']
assert 'dt = max(dt, dsqrt(dtmin*dtmax))' in maps['daystart_dt_raise']['excerpt']
native=maps['native_matrix_writer']['excerpt']
assert all(name.lower() not in native.lower() for name in ['WaSrMpDm','TimAbsCumDmCp','ThtSrpRefDmCp','VlMpDyCp'])
save('SOURCE_MAP.json',dict(source_identity={n:dict(sha256=hashlib.sha256((S/n).read_bytes()).hexdigest(),bytes=(S/n).stat().st_size) for n in sources},witnesses=maps))

groups=[
 dict(id='stocks',action='SERIALIZE_AUTHORITATIVE',fields=['WaSrMpDm'],shape='NumDm',why='swmbf1 rate availability and next commit depend on stored domain water, independent of matrix H',source=['macro_commit','macro_stock_seed']),
 dict(id='sorption_history',action='SERIALIZE_AUTHORITATIVE',fields=['TimAbsCumDmCp','ThtSrpRefDmCp','SorpDmCp'],shape='NumDm x NumNod',why='Clock/reference and event-start sorptivity are consumed across accepted steps; current H/theta cannot reconstruct them',source=['absorption_event_history','macro_commit']),
 dict(id='crack_history',action='SERIALIZE_ACCEPTED_GEOMETRY_AND_RETAIN_BRANCH_CACHE',fields=['VlMpDyCp','VlMpDmCp'],shape='NumNod; NumDm x NumNod',why='Wetting/drying crack branch reads prior dynamic crack volume; accepted volume may be stock-limited per domain by MPVOLUME2. VlMpDyCp may instead be reconstructed in exactly the original max(0,-VlMpStCp+sum domains) operation order from saved accepted VlMpDmCp, never from current H alone; retaining both is the smaller initial code change, not a proven byte-minimum.',source=['crack_history_and_surface']),
 dict(id='committed_geometry_caches',action='RESTORE_OR_PROVE_PURE_RECONSTRUCTION',fields=['ICpBtDm','ICpTpWaSrDm','ZBtDm','ZWaLevDm','FrMpWalWet','AwlCorFac','VlMpDm','VlMp','WaUnMpDm','WaUnMpDmCp','WaSrMp'],why='Must be coherent before MacroStateVar1 and first rate. For swmbf1 totals equal/sum domain stock; wet wall and heads derive from accepted geometry and stock. Pure reconstruction must retain original ordering/thresholds. Directly storing these small caches is the least invasive initial implementation.',source=['macro_commit','macro_rollback_seed']),
 dict(id='surface_geometry_phase',action='SERIALIZE_PHASE_CACHE_UNTIL_PROVEN_RECONSTRUCTIBLE',fields=['ArMpTp','ArMpTpDm','ArMpSs','KsMpSs','SubsidCp'],why='MPVOLUME2 explicitly does not update ArMpTp after stock-limited geometry; do not replace committed surface phase by a fresh MPVOLUME1 call. These caches may be reduced only after first BoundTop/vector_F ordering is qualified.',source=['crack_history_and_surface']),
 dict(id='rollback_snapshot',action='RESEED_AT_NEXT_TRIAL_NOT_OLD_STEP_HISTORY',fields=['ICpBtDmM1','VlMpDmCpM1','WaUnMpDmCpM1','hm1','thetm1','pondm1','gwlm1'],why='Next SoilWater2 saves current accepted state before headcalc. Do not serialize prior-step M1 and then override the new trial base with it. Hysteresis modes excluded.',source=['macro_rollback_seed']),
 dict(id='rates_and_event_flags',action='RECOMPUTE_BEFORE_USE',fields=['QExcMtxDmCp','QExcMpMtx','QInTopLatDm','QInTopVrtDm','QOutDrRapCp','dFdhMp','FlEndSrpEvt','FlSorp','DelHDmCp'],why='MACRORATE clears rates, ABSORPTION1 resets/recomputes event flags and derivative caches before ABSORPTION2; never run commit before this real sequence',source=['rates_reset_then_geometry','absorption_event_history']),
 dict(id='configuration',action='REREAD_AND_VALIDATE_IDENTITY',fields=['NumDm','NumNod','PpDmCp','VlMpStCp','FrArMtrx','CDarcy','DiPoCp','ICpBtDmPot','soil_hydraulic_parameters','macro_options'],why='Identical case/forcing/physical-patch signature required; configuration is not restart history',source=['macro_cold_init']),
 dict(id='numerical_policy',action='RESTORE_OR_EXPLICITLY_RESTRICT',fields=['IDecMpRat','dtold','headcalc::NStep','fldtmin','FlDecMpRat'],why='Next iteration budget and future reduction recovery depend on policy. Minimal v1 file supports only clean accepted unscaled boundary, IDec0/FlDecfalse, with exact next dt and fldtmin. Any IDec>0 needs explicit NStep access and separate qualification.',source=['reduction_hidden_counter','time_init']),
 dict(id='host_resume',action='RESTORE_EXACT_PHASE_AND_FORCING',fields=['t1900','tstart_origin','t','tcum','timjan1','dt_next','dtold','flDayStart','flDayEnd','isteps','date/daynr/daycum','daily_forcing_state','rain/meteo_cursor','daily_interception_and_crop_context'],why='Existing subday startup resets tcum, reruns daystart and raises dt; timestamps/cursors alone do not restore daily ET/interception and crop context',source=['time_init','daystart_dt_raise','host_daystart','forcing_clock_event_seek','rain_window_daily_aggregation']),
 dict(id='daily_forcing_details',action='RESTORE_OR_SIDE_EFFECT_FREE_REBUILD_BEFORE_METEO3',fields=['meteo_rec','rain_rec','i_metdetail','fl_update_meteo','tmn','tmx','tav','tavd','rad','hum','win','etr','grai','fprecnosnow','epond','peva','ptra_dry','ptra_wet','eintc','aintc','wfrac','lai','rd','vcover','siccap','sicact','dt_interc_event','crsflx_in','crsflx_out'],why='Current simple crop has SWINTER3 Rutter. Native SICACT is already stored (key SIACT), but current daily ET/canopy context must exist before Rutter. Preserve native evaporation reservoirs SPEV/SAEV and run reduceva only once in next real meteo3. Compare rebuilt context; do not serialize transient nraidt/qrot as a substitute for correct forcing.',source=['meteo_daily_and_step','ET_context_and_event','Rutter_event','evap_reservoir_step']),
 dict(id='diagnostic_ledgers',action='SEPARATE_CONTINUITY_GATE',fields=['FrMpWalWetOld(module)','MacroIntegral::FrMpWalWetOld(local)','I*/cQ* macro accumulators','WaSrDm1Ini','WaSrDm2Ini','IWa*Beg'],why='Not a first-physics-step state substitute. MacroIntegral shadows module wet-wall history with a local array lacking explicit SAVE; current module dump does not observe that local history. Exact cumulative/PEARL/output continuation needs its own scoped gate; no silent output-PASS.',source=['integral_shadow_wetwall']),
]
contract=dict(work_unit='SWAP431-MACRO-B1-RESTART08',status='PROPOSED_SOURCE_BOUND_CONTRACT_NOT_IMPLEMENTED',
    boundary='Committed full-host boundary immediately after TimeControl3, before next integral2/meteo3/boundary/drain/SoilWater2 sequence; no pending rejected trial',
    initial_supported_scope=dict(context='RETRY07 original B',swmacro=1,swmbf=1,swabs=1,swdra=1,swfrost=0,swhyst=0,swsolu=0,swhea=1,swcrop=1,croptype=1,swinter=3,swsnow=0,swirfix=0,shrinkage='Original clay layers; dynamic crack history required',IDecMpRat=0),
    file_extension=dict(proposed_tag='SWAP431_MACRO_RESTART_V1',format='Native full binary SWEND1/SWENDTYPE2; typed fixed-order versioned trailer, Fortran domain-fast order; same toolchain ABI initially',
        identity=['exact real8 checkpoint time','checkpoint phase','NumNod/NumDm','grid/domain/configuration/forcing/candidate signature','unscaled clean-boundary flags','payload version and completeness'],
        old_file_policy='Old macro file without trailer must fail explicit exact-macro-resume request; legacy matrix initialization remains separately labelled. No macro-free format change.',
        precision='Binary real8 time is authoritative; text TSTART only bootstrap, not precise checkpoint. Keep original forcing loading/calendar origin separate from resume time.',
        validation='Read/stage entire payload, reject malformed/mismatched/out-of-range/nonfinite/inconsistent inventory before installation; never silently clamp stocks or restart clocks'),
    groups=groups,
    minimal_change_set=['One versioned native macro state trailer and local staged read/write helper, not a general serializer',
        'Restart-aware macro initialization: constants then install accepted state/coherent caches; bypass cold stock seeding and time-advancing MACROSTATE',
        'One explicit accepted-subday host resume path: exact time/next-dt/day phase and daily forcing, without repeating daystart side effects'],
    sufficiency='Necessary state and smallest defensible change surface identified. Exact field-byte minimum and sufficiency require implementation plus first-use comparison; no restart implementation or new PASS in this work unit.',
    qualification_gates=['Writer noninterference and version/identity/missing-payload rejection',
        'Own-file fresh-process initialization equals checkpoint for physical/history fields; coherent caches and inventories; exact time/nextdt',
        'First pre-head boundary matches continuous forcing, heat/crop context, dt, geometry and rollback snapshots',
        'One full original host step at identical dt/end time equals continuous reference; independent water inventory and paired exchange; O0/O2',
        'Repeat genuine rejection/rollback/direct smaller retry only if restart changes the affected state seam',
        'No claim for reduced state, KWT, swabs2, other hysteresis/frost/modes or full cumulative output until separately qualified'],
    next_model_selection='If implemented: existing B checkpoint only; one continuous and one fresh own resume per O0/O2, 20s cap each, reuse unchanged evidence. No model selected for this contract-only analysis.')
save('CONTRACT.json',contract)
measure=[]
for opt in ['O0','O2']:
    a=fields(P/'data'/opt/'B_TRIAL/checkpoint.txt');b=fields(P/'data'/opt/'B_RESTART_FINAL/restart_initialized.txt')
    assert a['h']==b['h'] and a['theta']==b['theta']
    assert max(b['clock'])==0 and max(a['clock'])>.02
    # Real original native file contains matrix H/DT but none of the proposed macro primary state.
    native_keys=re.findall(r'^([A-Za-z0-9_]+)\s*=',(P/'data'/opt/'B_TRIAL/candidate_text.end').read_text(),re.M)
    assert 'H' in native_keys and 'DT' in native_keys
    assert not any(x.upper() in native_keys for g in groups[:3] for x in g['fields'])
    measure.append(dict(optimization=opt,matrix_H_theta_restored_exact=True,active_clock_cells=sum(x>0 for x in a['clock']),
        max_clock_lost_days=max(a['clock']),domain_stock_max_difference_cm=max(abs(x-y) for x,y in zip(a['macro_domain'],b['macro_domain'])),
        total_stock_difference_cm=abs(a['macro_total'][0]-b['macro_total'][0]),native_field_names=native_keys,
        source_explained_first_dt=max(1e-5,(1e-5*.002)**.5),actual_first_dt=b['controls'][1]))
    assert abs(measure[-1]['source_explained_first_dt']-b['controls'][1])<1e-18
result=dict(work_unit=contract['work_unit'],decision='NATIVE_MACRO_RESTART_CONTRACT_BOUNDED_NOT_IMPLEMENTED',
    baseline='fd5f1065a6c7673f871526a2042f3ed6e3428660',canonical_reconciled='a6720a0e8d7de6541069bdbdfd407fb1f41d3614',
    evidence='RETRY07 evidence hash '+json.loads((P/'EVIDENCE.json').read_text())['sha256'],
    models_launched=0,source_witnesses_checked=len(spans),field_groups=len(groups),measurements=measure,
    native_restart_gate='FAIL_INHERITED_UNCHANGED',new_restart_PASS=False,Fortran_changed=False,
    production_changed=False,physical_patch_changed=False,official_reference_promoted=False,
    conclusion='Missing committed macro inventory, sorption and crack history plus incompatible subday initialization. A macro-only array append cannot establish valid own restart.',
    minimum_addition=contract['minimal_change_set'],next_safe_step='Implement only the scoped trailer, deferred accepted-state install and bounded same-phase host resume, then qualify existing B own restart under 20s/route; retain output-ledger and other-mode exclusions.')
save('RESULT.json',result)
print(json.dumps({k:v for k,v in result.items() if k!='measurements'},indent=2))
