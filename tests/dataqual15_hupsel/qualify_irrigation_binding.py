"""Compile the original Hupsel irrigation input adapter and replay actual donor receipts.

This is component/input/restart qualification, never a SWAP5 project execution.
"""
import argparse,csv,hashlib,json,subprocess,time,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,required=True);p.add_argument('--reuse0',type=Path,required=True);p.add_argument('--reuse2',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();fc=a.compiler.resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();events=[]
ref=list(csv.DictReader(l for l in a.reference.read_text().splitlines()if l.strip()and not l.startswith('*')));assert len(ref)==1097
sources=[ROOT/'src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90',ROOT/'app/solute_project/hupsel_scheduled_irrigation.f90',ROOT/'tests/dataqual15_hupsel/irrigation_original.f90']
for opt,reuse in [('O0',a.reuse0.resolve()),('O2',a.reuse2.resolve())]:
 f=out/opt;f.mkdir();meta=json.loads((reuse/'BUILD.json').read_text());objects=[]
 for src,obj in zip(meta['source_sha256'],meta['object_sha256']):
  assert sha(Path(obj))==meta['object_sha256'][obj]
  if src.endswith('/app/solute_project/main.f90'):continue
  objects.append(obj)
 flags=['-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(f),'-J'+str(f),'-I'+str(reuse)]
 def run(cmd,label):
  t=time.monotonic();r=subprocess.run(list(map(str,cmd)),capture_output=True,cwd=f);n=len(events);(out/f'{n}.stdout').write_bytes(r.stdout);(out/f'{n}.stderr').write_bytes(r.stderr);events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-t,label=label));(out/'EVENTS.json').write_text(json.dumps(events,indent=2));assert r.returncode==0,r.stderr.decode()+r.stdout.decode();return r
 for i,src in enumerate(sources[:2]):
  obj=f/f'new{i}.o';run([fc,*flags,'-c',src,'-o',obj],'compile');objects.append(obj)
 archive=Path('/workspace/scratch/f29d9f3066a3/dq13-reference431/providers/ttobj/libttutil.a')
 exe=f/'irrigation_original';run([fc,*flags,sources[-1],*objects,archive,'-o',exe],'link')
 for name in ['swap.swp','potato.crp']:shutil.copyfile(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'/name,f/name)
 with(f/'source.txt').open('w')as stream:
  for day in range(730):
   today=ref[day+1];yesterday=ref[day]
   stream.write(' '.join(map(str,[day,float(yesterday['DVS']),int(float(today['LAI'])>0),float(today['RAIN']),float(today['IRRIG']),float(today['TPOT']),float(today['TREDDRY']),float(today['TREDSOL'])]))+'\n')
 result=run([exe],'native');(f/'stdout').write_bytes(result.stdout);print(opt,result.stdout.decode(),flush=True)
assert(out/'O0/stdout').read_bytes()==(out/'O2/stdout').read_bytes()
report=dict(status='ORIGINAL_POTATO_IRRIGATION_INPUT_AND_DONOR_RECEIPT_RESTART_PASS_NOT_WHOLE_MODEL_EXECUTION',O0_O2_exact=True,original_model_days_added=0,source_sha256={str(p.relative_to(ROOT)):sha(p)for p in sources},reference_sha256=sha(a.reference),archive_sha256=sha(archive),events=events)
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
