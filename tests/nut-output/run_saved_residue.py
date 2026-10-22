"""Two real diagnostic providers versus unchanged literal original task6 slices."""
import argparse,base64,hashlib,io,json,os,pathlib,shlex,subprocess,tarfile,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())),mode='r:gz')as t:
 source=t.extractfile('SWAP/management_soil.f90').read()
assert sha(source)=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
s=source.decode('cp1252').replace('\r\n','\n')
fragments={
 'original_initial.inc':('      Ntotuptake = 0.0d0;','\n\n      call Wofost_SoilParameters'),
 'original_accumulate.inc':('      Ntotuptake = Ntotuptake +','\n\n      Ntotuptake_s'),
 'original_saved.inc':('         idwrt_1 = idwrt','\n\n! outout to CROP_EXT file'),
 'original_report.inc':('      if (flCropExt .AND.  floutput) then','\n\n      return\n\n      case (7)')}
positions=[]
for name,(start,end)in fragments.items():
 assert s.count(start)==1 and s.count(end)==1
 start_at=s.index(start);end_at=s.index(end,start_at)
 (OUT/name).write_text(s[start_at:end_at]+'\n');positions.append(start_at)
assert positions==sorted(positions),'original accumulate/save/report ordering'
inputs=[archive,ROOT/'src/adapter/mod_soil_n_crop_extended_output.f90',ROOT/'src/adapter/mod_crop_ext_saved_residue.f90',ROOT/'tests/nut-output/test_saved_residue.f90',pathlib.Path(__file__).resolve()]
events=[];results={}
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();exe=b/'test'
 commands=[('compile_link',shlex.split(os.environ.get('FC','gfortran'))+['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(OUT),*[str(f)for f in inputs[1:4]],'-o',str(exe)]),('native',[str(exe)])]
 for category,cmd in commands:
  started=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True)
  e=dict(optimization=opt,category=category,command=cmd,returncode=r.returncode,seconds=time.perf_counter()-started)
  for k in ['stdout','stderr']:
   name=f'{opt}-{category}.{k}';data=getattr(r,k);(OUT/name).write_bytes(data);e[k]=name;e[k+'_sha256']=sha(data)
  events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
  if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 results[opt]=r.stdout.decode().strip()
assert results['O0']==results['O2']and results['O0'].startswith('SAVED_RESIDUE_SOURCE_EXACT_PASS')
result=dict(status='SAVED_RESIDUE_COMPONENT_SOURCE_EXACT_O0_O2_PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),results=results,input_sha256={str(f.relative_to(ROOT)):sha(f.read_bytes())for f in inputs},fragment_sha256={f.name:sha(f.read_bytes())for f in OUT.glob('*.inc')},physical_integration=False,combined_generation=False,full_work_unit_closed=False,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['compile_link','native']})
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
