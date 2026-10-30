import os,argparse,csv,hashlib,json,re,shutil,subprocess,time,struct,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--rotation',action='store_true');p.add_argument('--diagnostic-predecessor',action='store_true');p.add_argument('--reactive',action='store_true');p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--end',type=int,default=365);p.add_argument('--prepare-days',type=int,default=365);p.add_argument('--restart',type=Path);p.add_argument('--capture',type=int,nargs='*',default=[]);p.add_argument('--timeout',type=int,default=900);a=p.parse_args();b=a.bundle.resolve();o=a.output.resolve();o.mkdir();build=json.loads((b/'BUILD.json').read_text());assert all(sha(Path(s))==h for s,h in build['source_sha256'].items());assert sha(b/'swap5_hupsel_germination')==build['executable_sha256']
source=ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'
original_inputs=['swap.swp','283.met','swap.dra']+sorted(f.name for f in source.glob('*.crp'))
for n in original_inputs:shutil.copyfile(source/n,o/n)
r=subprocess.run([str(b/'read_fallow'),'swap.swp','283.met','swap.dra',str(a.prepare_days),'original-germination'],cwd=o,capture_output=True);(o/'prepare.stdout').write_bytes(r.stdout);(o/'prepare.stderr').write_bytes(r.stderr);assert r.returncode==0
nml=(o/'input.nml').read_text()
if a.rotation:
 nml=nml.replace('&column ','&column original_hupsel_rotation=.true.,reactive_substep_chemistry=.true.,',1);(o/'input.nml').write_text(nml)
elif a.reactive:
 nml=nml.replace('&column ','&column reactive_substep_chemistry=.true.,',1);(o/'input.nml').write_text(nml)
ends=[float(v)for v in re.search('^ends_day=(.*)$',nml,re.M)[1].split(',')if v.strip()];stop=next(i+1 for i,v in enumerate(ends)if v==a.end)
cmd=[str(b/'swap5_hupsel_germination'),'input.nml',str(a.restart.resolve())if a.restart else'-',str(stop),'swap.swp','maize.crp'];t=time.monotonic()
captured=set();censored=False
with(o/'stdout').open('wb')as so,(o/'stderr').open('wb')as se:
 env=os.environ.copy()
 if a.diagnostic_predecessor:
  assert a.rotation and a.restart;env['SWAP5_DIAG_PREDECESSOR']='1'
 r=subprocess.Popen(cmd,cwd=o,stdout=so,stderr=se,env=env)
 while r.poll()is None:
  try:
   raw=(o/'checkpoint.bin').read_bytes();assert raw[:8]in[b'S5HG0002',b'S5HR0002',b'S5HR0003']and zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
   clock=struct.unpack_from('=d',raw,8 if raw[:8]in[b'S5HR0002',b'S5HR0003']else 12)[0]
   if clock in a.capture and clock not in captured:(o/f'checkpoint-{int(clock)}.bin').write_bytes(raw);captured.add(clock)
  except (OSError,AssertionError,struct.error):pass
  if time.monotonic()-t>a.timeout:r.kill();r.wait();censored=True;break
  time.sleep(.03)
rows=list(csv.DictReader((o/'budget.csv').open()))if(o/'budget.csv').exists()else[];report=dict(original_rotation=a.rotation,diagnostic_predecessor=a.diagnostic_predecessor,restart_qualification=not a.diagnostic_predecessor,returncode=r.returncode,censored=censored,captured=sorted(captured),completed_days=float(rows[-1]['t1_day'])if rows else 0,requested_days=a.end,seconds=time.monotonic()-t,command=cmd,maximum_water_residual_cm=max((abs(float(r['water_residual_cm']))for r in rows),default=None),maximum_solute_residual_mg_cm2=max((abs(float(r['solute_residual_mg_cm2']))for r in rows),default=None),source_sha256=build['source_sha256'],original_inputs_sha256={n:sha(source/n)for n in original_inputs},files={f.name:sha(f)for f in o.iterdir()if f.is_file()},reason=((o/'stdout').read_text().splitlines()or['NO_STDOUT_SEE_STDERR'])[-1]);(o/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k not in ['source_sha256','files','original_inputs_sha256']}))
