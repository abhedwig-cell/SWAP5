"""Measured hydrological fixture alternatives with immutable production providers.

The existing accepted-step proposal is selected; every strict full/half and
mass gate remains active. No production source changes. A result is exploratory and never an admission or full-rotation PASS.
"""
from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
BASE=Path(os.environ['N_SURFACE_PROVIDERS']).resolve()
OUT=Path(os.environ['N_SURFACE_PROBE_DIR']).resolve();OUT.mkdir(exist_ok=False)
OPT=os.environ.get('N_SURFACE_PROBE_OPT','O2');assert OPT in ['O0','O2']
VARIANT='field-loam'
DAYS=int(os.environ.get('N_SURFACE_PROBE_DAYS','8'));assert 1<=DAYS<=730
SUBSTEP_CAP=int(os.environ.get('N_SURFACE_SUBSTEP_CAP','4096'));assert SUBSTEP_CAP in [4096,10000]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();self_sha=sha(Path(__file__))
prior=json.loads((BASE/'result.json').read_text());assert prior['status']=='SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED'
LEAF='src/process/mod_b111_pond_solute_exchange.f90'
assert prior['input_sha256'][LEAF]=='7c4c12b2f643d0562bc1c07244ce428271298e1b7635d736fc8a270de16b11af'
for p,h in prior['input_sha256'].items():
 if p!=LEAF:assert sha(ROOT/p)==h,p
assert sha(BASE/'generated_driver.f90')==prior['generated_driver_sha256']
NEW_LEAF_SHA=sha(ROOT/LEAF)
events=json.loads((BASE/'events.json').read_text());assert all(e['returncode']==0 for e in events)
text=(BASE/'generated_driver.f90').read_text()
if VARIANT=='field-loam':
 for i in [3,10,12]:
  line=f'  cfg%tiles(1)%parameters%cofgen({i},:)=cfg%tiles(1)%parameters%cofgen({i},:)*1d-3\n'
  assert text.count(line)==1;text=text.replace(line,'')
 old='  cfg%tiles(1)%initial_state%ponding_depth=.2d0';assert text.count(old)==1
 text=text.replace(old,'  cfg%tiles(1)%initial_state%ponding_depth=0d0')
 old='     forcing%pond_input%rain_rate_cm_day=.05d0*(1d0+.4d0*season)';assert text.count(old)==1
 text=text.replace(old,'     forcing%pond_input%rain_rate_cm_day=merge(.5d0,.05d0,mod(d,7)==6)*(1d0+.4d0*season)')
old='  cfg%numerical%transaction%temporal_tolerance=1d-6';assert text.count(old)==1
text=text.replace(old,old+'\n  cfg%numerical%retain_accepted_step_proposal=.true.')
cap='cfg%numerical%max_committed_substeps=4096';assert text.count(cap)==1
text=text.replace(cap,f'cfg%numerical%max_committed_substeps={SUBSTEP_CAP}')
needle="    call require(r%status==0,'rotation actual daily Richards crop Soil-N')"
assert text.count(needle)==1
text=text.replace(needle,"\n    print *,'SURFACE_DAY_NUMERICS',d+1,r%joint%joint%diagnostics%accepted_substeps, &\n      r%joint%joint%diagnostics%attempts,r%joint%joint%diagnostics%temporal_rejections, &\n      r%joint%joint%diagnostics%solver_rejections,r%joint%joint%diagnostics%max_abs_step_mass_residual, &\n      r%joint%joint%water%completed_t\n"+needle)
driver=OUT/'test_surface_n_hydrology.f90';driver.write_text(text)
b=BASE/OPT;ce=[e for e in events if e['category']=='compile'and '-'+OPT in e['command']]
driver_event=next(e for e in ce if Path(e['command'][e['command'].index('-c')+1]).name=='test_surface_n_rotation.f90')
command=driver_event['command'].copy();command[command.index('-c')+1]=str(driver);command[command.index('-o')+1]=str(OUT/'driver.o')
command=[('-J'+str(OUT)if x.startswith('-J')else x)for x in command]
link=next(e['command']for e in events if e['category']=='link'and str(b/'hist')in e['command']).copy()
oldobj=driver_event['command'][-1];assert link.count(oldobj)==1
link=[str(OUT/'driver.o')if x==oldobj else x for x in link];link[link.index('-o')+1]=str(OUT/'hist')
artifacts={str(p):sha(p)for p in b.iterdir()if p.is_file()and p.suffix in ['.o','.mod','.smod']}
records=[]
def run(c,kind):
 t=time.perf_counter()
 with (OUT/(kind+'.stdout')).open('wb')as so,(OUT/(kind+'.stderr')).open('wb')as se:
  r=subprocess.run(c,cwd=OUT,stdout=so,stderr=se,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'1','OMP_NUM_THREADS':'1'})
 records.append(dict(command=c,category=kind,seconds=time.perf_counter()-t,returncode=r.returncode))
 (OUT/'events.json').write_text(json.dumps(records,indent=2)+'\n');assert r.returncode==0,(kind,r.returncode)
leaf_event=next(e for e in ce if e['command'][e['command'].index('-c')+1]==str(ROOT/LEAF))
leaf_command=leaf_event['command'].copy();leaf_command[leaf_command.index('-o')+1]=str(OUT/'leaf.o')
leaf_command=[('-J'+str(OUT)if x.startswith('-J')else x)for x in leaf_command]
old_leaf_object=leaf_event['command'][-1];assert link.count(old_leaf_object)==1
link=[str(OUT/'leaf.o')if x==old_leaf_object else x for x in link]
run(leaf_command,'provider_compile')
assert(OUT/'mod_b111_pond_solute_exchange.mod').read_bytes()==(b/'mod_b111_pond_solute_exchange.mod').read_bytes(),'changed leaf public ABI'
run(command,'driver_compile');run(link,'link');run([str(OUT/'hist'),'write',str(OUT/'state.restart'),str(OUT/'endpoint'),'surface-profile','0',str(DAYS)],'native')
for p,h in artifacts.items():assert sha(Path(p))==h,p
for p,h in prior['input_sha256'].items():
 if p!=LEAF:assert sha(ROOT/p)==h,p
assert sha(ROOT/LEAF)==NEW_LEAF_SHA
assert sha(Path(__file__))==self_sha
r=dict(status='EXPLORATORY_SURFACE_HYDROLOGY_PASS_NOT_QUALIFIED',variant=VARIANT,opt=OPT,days=DAYS,max_committed_substeps=SUBSTEP_CAP,events=records,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256={**prior['input_sha256'],LEAF:NEW_LEAF_SHA},provider_artifacts=artifacts,provider_result_sha256=sha(BASE/'result.json'),recompiled_leaf_sha256=sha(OUT/'leaf.o'),original_leaf_sha256=prior['input_sha256'][LEAF],driver_sha256=sha(driver),runner_sha256=self_sha)
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
