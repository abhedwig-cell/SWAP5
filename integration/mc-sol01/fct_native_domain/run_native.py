"""Execute actual native caller and independent process restart, bounded forcing."""
import argparse,base64,csv,hashlib,io,itertools,json,re,stat,struct,subprocess,tarfile,time,zlib
from pathlib import Path
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--build',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--positive-pond-prefix',action='store_true');ap.add_argument('--historical-zero',action='store_true');ap.add_argument('--case-limit',type=int,default=12);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);exe=a.build.resolve()/'native_fct'
 build=json.loads((a.build/'build.json').read_text());assert build['status']=='BUILT_RESEARCH_NATIVE' and hashlib.sha256(exe.read_bytes()).hexdigest()==build['executable_sha256']
 r=dict(status='RUNNING',build=build,cases=[],events=[],native_application=True,original_SWP_project=False,production_activated=False)
 root=Path(__file__).resolve().parents[3]
 raw=base64.b64decode((root/'integration/mc-sol01/evidence/MC_SOL01_REFINED_YEAR_20261023.tar.xz.b64').read_bytes())
 assert hashlib.sha256(raw).hexdigest()=='7dfe7a6cee6666484ebbbc8614a979d8ea86b240f7a46ddb3b66358d27303b4e'
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:swp=t.extractfile('annual-O2/O2/annual1998/Project.SWP').read().decode()
 for exp,uptake,grid in list(itertools.product([.5,1.,2.],[0.,1.],['uniform','unequal']))[:a.case_limit]:
  case=out/f'{exp}-{uptake}-{grid}';case.mkdir();water=swp
  water=re.sub(r'(?im)^FREXP\s*=.*$',f'FREXP={exp}',water)
  water=re.sub(r'(?im)^TSCF\s*=.*$',f'TSCF={uptake}',water)
  if grid=='uniform':
   assert water.count('3 2 78.0 20')==1;water=water.replace('3 2 78.0 20','3 2 78.0 39')
  source=case/'project.swp';source.write_text(water);n=60 if grid=='uniform' else 41
  text=f'''&column
 schema=2,nodes=0,swp_water_bootstrap=.true.,
 initial_head=-75,initial_pond_cm=.1,initial_pond_mass_mg_cm2=.02,
 concentration_mg_cm3={n}*.1,solute_transport_scheme=1,
 drain_cm_day={n}*.00005,tscf={uptake},
 freundlich_exponent={exp},temporal_tolerance=.001,
 pond_max_cm=.2,runoff_resistance_day=1,
/
&surface
 windows=4,ends_day=.1,.2,.3,.4,rain_cm_day=4*.003,
 irrigation_cm_day=4*.001,runon_cm_day=4*.001,
 rain_c=.1,irrigation_c=.2,runon_c=.3,
/
&crop
 root_table_points=3,upper_layer_bottom_node=20,maximum_root_depth_cm=40,
 root_relative_depth=0,.5,1,root_density=2,1,0,
 hlim3l=-1000,hlim3h=-500,hlim4=-16000,adcrl=.1,adcrh=.5,
 crop_active=4*.true.,root_depth_cm=4*20,potential_transpiration_cm_day=4*.001,
/
&rotation
 profile_count=1,profile_index=4*1,
 profiles(1)%points=3,profiles(1)%relative_depth=0,.5,1,profiles(1)%density=2,1,0,
 profiles(1)%parameters%upper_layer_bottom_node=20,
 profiles(1)%parameters%hlim3l=-1000,profiles(1)%parameters%hlim3h=-500,
 profiles(1)%parameters%hlim4=-16000,profiles(1)%parameters%adcrl=.1,profiles(1)%parameters%adcrh=.5,
/
'''
  if a.positive_pond_prefix:text=text.replace('ends_day=.1,.2,.3,.4','ends_day=.000001,.000002,.000003,.000004')
  if a.historical_zero:text=text.replace('solute_transport_scheme=1,','solute_transport_scheme=1,historical_zero_solute_exfiltration=.true.,')
  inp=case/'input.nml';inp.write_text(text);events={}
  for label,restart,stop in [('full','-',4),('split','-',2),('resume',str(case/'split/restart.bin'),4)]:
   folder=case/label;folder.mkdir();exe.chmod(exe.stat().st_mode|stat.S_IXUSR);cmd=[str(exe),str(inp),restart,str(stop),str(source)];t=time.monotonic();cp=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=180)
   e=dict(command=cmd,returncode=cp.returncode,seconds=time.monotonic()-t,stdout=cp.stdout.decode(),stderr=cp.stderr.decode());r['events'].append(e);events[label]=e
   (out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');assert cp.returncode==0,e
  for name in ['restart.bin','state.csv','endpoint.csv']:assert (case/'full'/name).read_bytes()==(case/'resume'/name).read_bytes(),(case,name)
  read=lambda path:list(csv.DictReader(path.open()))
  full=read(case/'full/budget.csv');resume=read(case/'resume/budget.csv');assert len(full)==4 and full[2:]==resume
  wrong=bytearray((case/'split/restart.bin').read_bytes());assert struct.unpack_from('<q',wrong,12)[0]==1670001
  struct.pack_into('<q',wrong,12,670001);wrong[-4:]=struct.pack('<I',zlib.crc32(wrong[:-4]));foreign=case/'wrong-policy.bin';foreign.write_bytes(wrong)
  rejected=case/'wrong-policy';rejected.mkdir();exe.chmod(exe.stat().st_mode|stat.S_IXUSR)
  cmd=[str(exe),str(inp),str(foreign),'4',str(source)];t=time.monotonic();cp=subprocess.run(cmd,cwd=rejected,capture_output=True,timeout=180)
  e=dict(command=cmd,returncode=cp.returncode,seconds=time.monotonic()-t,stdout=cp.stdout.decode(),stderr=cp.stderr.decode(),expected='REJECT')
  r['events'].append(e);assert cp.returncode!=0 and 'restart rejected' in e['stdout'] and not (rejected/'restart.bin').exists(),e
  maxima={s:0. for s in ['water','solute']}
  for row in full:
   for substance,unit in [('water','cm'),('solute','mg_cm2')]:
    residual=float(row[f'{substance}_end_{unit}'])-float(row[f'{substance}_start_{unit}'])-float(row[f'{substance}_in_{unit}'])+float(row[f'{substance}_out_{unit}'])
    maxima[substance]=max(maxima[substance],abs(residual));assert abs(residual)<1e-10
  r['cases'].append(dict(exponent=exp,uptake=uptake,grid=grid,exact_endpoint=True,exact_continued_budgets=True,CRC_valid_wrong_policy_rejected=True,maxima=maxima));(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
 r['status']='BOUNDED_NATIVE_CALLER_AND_PROCESS_RESTART_PASS';(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(dict(status=r['status'],cases=len(r['cases']),processes=len(r['events']))))
if __name__=='__main__':main()
