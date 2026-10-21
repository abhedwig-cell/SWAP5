"""Compare the diagnostic adapter with exact original task6 source fragments."""
import argparse,base64,hashlib,io,json,os,pathlib,shlex,subprocess,tarfile,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
raw=base64.b64decode(archive.read_bytes())
with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz')as t:
 source=t.extractfile('SWAP/management_soil.f90').read()
 caller=t.extractfile('SWAP/swap.f90').read()
assert sha(source)=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
s=source.decode('cp1252').replace('\r\n','\n')
assert s.index('      Ntotuptake = Ntotuptake +')<s.index('         idwrt_1 = idwrt')<s.index('      if (flCropExt .AND.  floutput) then')
c=caller.decode('cp1252').lower()
assert c.index('call soilmanagement(5)')<c.index('call cropdevelopment (3)')<c.index('call soilmanagement(6)')
# Header literals are copied exactly; no full-file rewrite is claimed.
provider=(ROOT/'src/adapter/mod_soil_n_crop_extended_output.f90').read_text()
for value in ['    nishmi     nishma     niromi     niroma     poshmi     poshma     poromi     poroma',' to be replaced','year-mo-da,Ntotuptake,Ptotuptake,DMcressurf,N-cressurf,P-cressurf,DMcresbott,N-cresbott,P-cresbott']:
 assert value in s and value in provider
fragments={
 'original_initial.inc':('      Ntotuptake = 0.0d0;','\n\n      call Wofost_SoilParameters'),
 'original_accumulate.inc':('      Ntotuptake = Ntotuptake +','\n\n      Ntotuptake_s'),
 'original_report.inc':('      if (flCropExt .AND.  floutput) then','\n\n      return\n\n      case (7)')}
for name,(start,end)in fragments.items():
 assert s.count(start)==1 and s.count(end)==1
 (OUT/name).write_text(s[s.index(start):s.index(end,s.index(start))]+'\n')
inputs=[archive,ROOT/'src/adapter/mod_soil_n_crop_extended_output.f90',ROOT/'tests/nut-output/test_crop_extended_output.f90',pathlib.Path(__file__).resolve()]
events=[];results={}
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();exe=b/'test'
 commands=[('compile_link',shlex.split(os.environ.get('FC','gfortran'))+['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(OUT),str(inputs[1]),str(inputs[2]),'-o',str(exe)]),('native',[str(exe)])]
 for category,cmd in commands:
  t0=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True)
  e=dict(optimization=opt,category=category,command=cmd,returncode=r.returncode,seconds=time.perf_counter()-t0)
  for k in ['stdout','stderr']:
   name=f'{opt}-{category}.{k}';v=getattr(r,k);(OUT/name).write_bytes(v);e[k]=name;e[k+'_sha256']=sha(v)
  events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
  if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 results[opt]=r.stdout.decode().strip()
assert results['O0']==results['O2']and results['O0'].startswith('CROP_EXT_SOURCE_EXACT_PASS')
result=dict(status='BOUNDED_CROP_EXT_COMPONENT_SOURCE_EXACT_PASS',results=results,input_sha256={str(f.relative_to(ROOT)):sha(f.read_bytes())for f in inputs},original_management_sha256=sha(source),original_caller_sha256=sha(caller),source_call_order_checked=True,fragment_sha256={f.name:sha(f.read_bytes())for f in OUT.glob('*.inc')},physical_integration=False,native_true_enabled=False,full_work_unit_closed=False)
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
