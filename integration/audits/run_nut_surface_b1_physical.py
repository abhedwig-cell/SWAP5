"""Actual current shared production closure plus generated surface-N scenario.

Existing HIST fixture and immutable legacy science providers are retained.
Generated driver and executed runner prefix are hashed and archived explicitly.
"""
from pathlib import Path
import base64,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_SURFACE_PHYSICAL_DIR']).resolve()
DAYS=int(os.environ.get('N_SURFACE_DAYS','2'));assert 1<=DAYS<=730
INCUMBENT=os.environ.get('N_SURFACE_INCUMBENT','0')=='1'
HYDROLOGY=os.environ.get('N_SURFACE_HYDROLOGY','clay');assert HYDROLOGY in ['clay','field-loam']
SUBSTEP_CAP=int(os.environ.get('N_SURFACE_SUBSTEP_CAP','4096'));assert SUBSTEP_CAP in [4096,10000]
WRAPPER_SHA=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
original=ROOT/'tests/nut-crop/test_b112_retained_joint.f90';text=original.read_text()
def replace(a,b,count=1):
 global text
 assert text.count(a)==count,(a,text.count(a));text=text.replace(a,b)
# The added profile follows the already qualified humus rotation, with explicit
# islands for real dynamic pond hydrology. All old profile branches stay selected
# only by their original names.
text=text.replace("trim(selected)=='humus-profile'","(trim(selected)=='humus-profile'.or.trim(selected)=='surface-profile')")
replace(' use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE',' use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE,TX_TEMPORAL_EXTERNAL_FULL_HALF')
replace(' call parameters(sp);call materials(items,split);',' call parameters(sp)\n if(trim(selected)==\'surface-profile\')sp%mineral%surface_n_enabled=.true.\n call materials(items,split);')
needle=' column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id'
replace(needle,''' if(trim(selected)=='surface-profile')then
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
  cfg%tiles(1)%initial_state%ponding_depth=.2d0
  cfg%tiles(1)%parameters%cofgen(3,:)=cfg%tiles(1)%parameters%cofgen(3,:)*1d-3
  cfg%tiles(1)%parameters%cofgen(10,:)=cfg%tiles(1)%parameters%cofgen(10,:)*1d-3
  cfg%tiles(1)%parameters%cofgen(12,:)=cfg%tiles(1)%parameters%cofgen(12,:)*1d-3
  cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  cfg%numerical%model_temporal_indicator_budget_available=.false.
  cfg%numerical%transaction%temporal_tolerance=1d-6
  cfg%numerical%retain_accepted_step_proposal=.true.
 end if
'''+needle)
needle='   call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id, &\n      cfg%tiles(1)%initial_state,base_day,ok,spread(0d0,1,numnod))'
replace(needle,'''   if(trim(selected)=='surface-profile')then
    call fmr_new_b110_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,base_day,ok)
   else
'''+needle+'\n   end if')
replace('   integer::d,first,code','   integer::d,first,code,last')
replace('   first=0','''   last=730
   if(trim(selected)=='surface-profile')then
    call get_command_argument(6,arg);if(len_trim(arg)>0)read(arg,*)last
    call require(last>=1.and.last<=730,'bounded surface scenario length')
   end if
   call get_command_argument(5,arg)
   first=0''')
replace('   do d=first,729','   do d=first,last-1')
needle='    forcing%bottom_flux=sum(forcing%root_extraction_sink)+.002d0*season'
replace(needle,needle+'''
    if(trim(selected)=='surface-profile')then
     forcing%top_flux=0d0
     forcing%bottom_flux=sum(forcing%root_extraction_sink)-.003d0
     allocate(forcing%pond_input)
     forcing%pond_input%rain_rate_cm_day=.05d0*(1d0+.4d0*season)
     forcing%pond_input%irrigation_rate_cm_day=.005d0
     forcing%pond_input%runon_rate_cm_day=.01d0
     forcing%pond_input%potential_pond_evaporation_cm_day=.01d0*(1d0+.4d0*season)
     forcing%pond_input%ponding_max_cm=.2d0;forcing%pond_input%runoff_resistance_day=.1d0
    end if''')
needle="    call require(r%status==0,'rotation actual daily Richards crop Soil-N')"
replace(needle,"""    print *,'SURFACE_DAY_NUMERICS',d+1,r%joint%joint%diagnostics%accepted_substeps, &
      r%joint%joint%diagnostics%attempts,r%joint%joint%diagnostics%temporal_rejections, &
      r%joint%joint%diagnostics%solver_rejections,r%joint%joint%diagnostics%max_abs_step_mass_residual
"""+needle)
replace('   type is(fmr_b110_temporal_indicator_state_t)','   class is(fmr_b110_physical_state_t)')
needle="   print *,'ROTATION_730_DAYS_PASS',first,uptake,max_n,max_w"
replace(needle,"   if(trim(selected)=='surface-profile')print *,'SURFACE_N_B1_PHYSICAL_DAYS',last\n"+needle)
# Mode identity is verified by the same existing native decoder; omission must
# reject even when both top concentrations and old crop identities agree.
needle="    if(atmospheric)then\n     bad_sp=sp;bad_sp%mineral%c_top=0d0"
replace(needle,"""    if(trim(selected)=='surface-profile')then
     bad_sp=sp;bad_sp%mineral%surface_n_enabled=.false.
     call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template, &
      670001_int64,9001_int64,merge(9102_int64,9101_int64,first>=365),bad_sp,cp,other_water,other_state,code)
     call require(code/=0.and..not.other_water%ready().and..not.other_state%ready(),'surface restart mode identity rejects atomically')
    end if
"""+needle)
# Explicit fixture selection; original profile branches remain unchanged.
if HYDROLOGY=='field-loam':
 for i in [3,10,12]:
  line=f'  cfg%tiles(1)%parameters%cofgen({i},:)=cfg%tiles(1)%parameters%cofgen({i},:)*1d-3\n'
  replace(line,'')
 replace('  cfg%tiles(1)%initial_state%ponding_depth=.2d0','  cfg%tiles(1)%initial_state%ponding_depth=0d0')
 replace('     forcing%pond_input%rain_rate_cm_day=.05d0*(1d0+.4d0*season)',
         '     forcing%pond_input%rain_rate_cm_day=merge(.5d0,.05d0,mod(d,7)==6)*(1d0+.4d0*season)')
# Select only inside the new profile: old incumbent resource settings stay exact.
replace('  cfg%numerical%retain_accepted_step_proposal=.true.',
        f'  cfg%numerical%retain_accepted_step_proposal=.true.\n  cfg%numerical%max_committed_substeps={SUBSTEP_CAP}')
generation=OUT.parent/(OUT.name+'-generation');generation.mkdir(exist_ok=False)
driver=generation/'test_surface_n_rotation.f90';driver.write_text(text)
runner=ROOT/'tests/nut-crop/run_hist_complete.py';prefix=runner.read_text().split(' # Original two-day owner')[0]
assert "driver=ROOT/'tests/nut-crop/test_b112_retained_joint.f90'" in prefix
prefix=prefix.replace("driver=ROOT/'tests/nut-crop/test_b112_retained_joint.f90'",'driver=Path('+repr(str(driver))+')')
# Prefix contains imports, immutable original-source extraction, full provider
# ordering and actual compilation/link at O0/O2. Its for-loop is completed here.
body='''
 profiles=['surface-profile']
 if INCUMBENT:profiles=['source-profile','rotation-profile','atmospheric-profile','humus-profile']+profiles
 rows={}
 for profile in profiles:
  restart=b/(profile+'.restart');endpoint=b/(profile+'.endpoint')
  extra=['surface-profile','0',str(DAYS)]if profile=='surface-profile'else[profile]
  stdout=run([exe,'write',restart,endpoint,*extra],b,'native')
  fresh_days=[1,120,121,365,366,500]if profile!='source-profile'else[1]
  if profile=='surface-profile':fresh_days=[d for d in fresh_days if d<=DAYS]
  for day in fresh_days:
   fresh=b/(profile+'-fresh-'+str(day))
   start=Path(str(restart)+'.'+str(day))if profile!='source-profile'else restart
   args=[exe,'resume',start,fresh,profile,str(day)]
   if profile=='surface-profile':args+=[str(DAYS)]
   run(args,b,'restart_native');assert endpoint.read_bytes()==fresh.read_bytes(),('fresh endpoint mismatch',profile,day)
  if profile!='source-profile':
   for day in [120,366]:
    if profile=='surface-profile'and day>=DAYS:continue
    before=Path(str(restart)+'.reject-before-'+str(day));after=Path(str(restart)+'.reject-after-'+str(day))
    assert before.read_bytes()==after.read_bytes()
  rows[profile]=dict(stdout=stdout,endpoint=sha(endpoint),fresh_days=fresh_days)
 results[opt]=rows
 assert all(sha(ROOT/p)==v for p,v in inputs.items()),'compiled source changed during execution'
'''
executed=prefix+body
os.environ['N_HIST_RESULT_DIR']=str(OUT)
sys.path.insert(0,str(ROOT/'tests/nut-crop'))
namespace={'__file__':str(runner),'__name__':'surface_physical','INCUMBENT':INCUMBENT,'DAYS':DAYS}
exec(compile(executed,str(generation/'executed_runner.py'),'exec'),namespace)
assert namespace['results']['O0']==namespace['results']['O2'],'physical optimization drift'
assert hashlib.sha256(Path(__file__).read_bytes()).hexdigest()==WRAPPER_SHA,'wrapper changed during execution'
for name,data in [('generated_driver.f90',text),('executed_runner.py',executed)]: (OUT/name).write_text(data)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=namespace['inputs'];inputs.update({str(p.relative_to(ROOT)):sha(p)for p in [Path(__file__),original,runner]})
r=dict(status='SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED',days=DAYS,incumbent=INCUMBENT,hydrology=HYDROLOGY,max_committed_substeps=SUBSTEP_CAP,execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=inputs,results=namespace['results'],generated_driver_sha256=sha(OUT/'generated_driver.f90'),executed_runner_sha256=sha(OUT/'executed_runner.py'),providers=len(namespace['ordered'])-1,literal_sha256=sha(namespace['LITERAL']),authority_sha256={n:hashlib.sha256(v).hexdigest()for n,v in namespace['raws'].items()},authority_archive_sha256=sha(ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'),cost_seconds={k:sum(e['seconds']for e in namespace['events']if e['category']==k)for k in ['compile','link','native','restart_native']})
if INCUMBENT:
 s=json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/s['historical_guard']['physical_evidence']['path']).read_bytes())))as t:
  for opt in ['O0','O2']:
   for profile in ['source-profile','rotation-profile','atmospheric-profile','humus-profile']:
    assert (OUT/opt/(profile+'.endpoint')).read_bytes()==t.extractfile('nut-hist-capacity-qualified/'+opt+'/'+profile+'.endpoint').read(),'incumbent endpoint drift'
 r['incumbent_endpoints']='EXACT_ADMITTED_BYTES'
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'],DAYS)
