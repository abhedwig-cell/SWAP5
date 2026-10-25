"""Measured minimal object link closure for actual provider and real128 oracle."""
import argparse,gzip,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest();p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();m=json.loads((a.bundle/'column/build-complete.json').read_text());events=[]
def run(cmd,label):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True)
 for k in ['stdout','stderr']:(out/(label+'.'+k)).write_bytes(getattr(r,k))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-t));assert not r.returncode,r.stderr.decode()[-1800:];return r
src=ROOT/'tests/nut-sol/test_rational_saturation_storage.f90';flags=[f for f in m['flags']if not f.startswith('-J')];obj=out/'driver.o';run(m['compiler_command']+['-I'+str(a.bundle/'column')]+flags+['-J'+str(out),'-c',src,'-o',obj],'compile')
link=m['events'][0]['command'];objects=[x for x in link if x.endswith('.o')];symbols={};undefined={}
for o in [str(obj)]+objects:
 lines=subprocess.check_output(['nm','-g',o],text=True).splitlines();undefined[o]=[]
 for line in lines:
  fields=line.split()
  if len(fields)==2 and fields[0]=='U':undefined[o].append(fields[1])
  elif len(fields)==3 and fields[1].upper()not in ['U','W','V']:symbols[fields[2]]=o
selected={str(obj)};pending=[str(obj)]
while pending:
 for s in undefined[pending.pop()]:
  if s in symbols and symbols[s]not in selected:selected.add(symbols[s]);pending.append(symbols[s])
providers=[o for o in objects if o in selected];exe=out/'driver';run(m['compiler_command']+flags+[obj,*providers,'-o',exe],'link')
source=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-swap.swp.gz';raw=gzip.decompress(source.read_bytes()).decode();tail=raw[raw.index('ORES  OSAT   ALFA   NPAR    LEXP KSATFIT KSATEXM H_ENPR  BDENS'):].splitlines()[1:];data='\n'.join(tail[:8])+'\n';(out/'original-rows.dat').write_text(data);r=run([exe,out/'original-rows.dat'],'native');assert b'RATIONAL_SATURATION_REAL128_PASS'in r.stdout
inputs={p:sha((ROOT/p).read_bytes())for p in ['src/solver/mod_b110_default_mvg_provider.f90',str(src.relative_to(ROOT)),str(source.relative_to(ROOT)),str(Path(__file__).relative_to(ROOT))]};result=dict(status='RATIONAL_SATURATION_REAL128_PASS',optimization=m['reused_source_build']['source_build']['flags'][0],events=events,input_sha256=inputs,provider_objects=len(providers),object_hashes={o:sha(Path(o).read_bytes())for o in providers},independent_cases=864,raw_stdout=r.stdout.decode(),qualified=False);(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(status=result['status'],provider_objects=len(providers))))
