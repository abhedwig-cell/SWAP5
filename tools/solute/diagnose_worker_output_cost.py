"""Two bounded output-only coherent-worker controls; original physics unchanged."""
import argparse,json,shutil,subprocess,time,zipfile
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle',type=Path,required=True);p.add_argument('--reference',type=Path,required=True)
p.add_argument('--full',type=Path,required=True);p.add_argument('--terminal',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();bundle=a.bundle.resolve();reference=a.reference.resolve();meta=json.loads((bundle/'BUILD.json').read_text())
rows=[json.loads(s) for s in (a.full/'daily.jsonl').read_text().splitlines()];last=rows[-1]['day']
from datetime import date
clock=(date.fromisoformat(meta['project']['start_date'])-date(1900,1,1)).days+last+1
payload=''.join(f'{d} {clock if d==last else -1}\n' for d in range(1,last+1))+'0 -1\n'
records=lambda q:[s for s in q.read_text().splitlines() if s.strip() and not s.startswith('*')]
report=[]
for mode in ('no-hydraulic-output','hex-hydraulic'):
 out=a.output/mode;out.mkdir();source=(bundle/'swap_main.f90').read_text(encoding='cp1252')
 line="write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)"
 assert source.count(line)==2
 if mode=='no-hydraulic-output':source=source.replace(line,'continue ! diagnostic removes only output formatting')
 else:
  source=source.replace('only: output_unit','only: output_unit, int64')
  source=source.replace(line,"write(*,'(a,*(1x,z16.16))') 'HYBRID_HYDRAULIC_HEX', transfer([gwl,qbot,h(1:numnod)],[0_int64])")
 (out/'swap_main.f90').write_text(source,encoding='cp1252')
 command=['gfortran',*meta['identity']['donor_flags'],'-I',str(bundle),'-I',str(reference/'build/swap-obj'),'-I',str(reference/'build/ttutil-obj'),'-c','swap_main.f90']
 compile=subprocess.run(command,cwd=out,capture_output=True,text=True,timeout=60);assert compile.returncode==0,compile.stderr
 objects=[]
 for original in sorted((reference/'build/swap-obj').glob('*.o')):
  selected=out/original.name if original.name=='swap_main.o' else bundle/original.name
  objects.append(str(selected if selected.exists() else original))
 exe=out/'diagnostic.exe'
 link=subprocess.run(['gfortran','-o',str(exe),*objects,str(bundle/'hybrid_step_budget.o'),str(reference/'build/ttutil-obj/libttutil.a')],capture_output=True,text=True,timeout=60);assert link.returncode==0,link.stderr
 case=out/'case';case.mkdir()
 for n in meta['inputs']:
  (case/n).parent.mkdir(exist_ok=True,parents=True);shutil.copyfile(a.full/'original'/n,case/n)
 started=time.perf_counter()
 with (out/'stdout').open('wb') as stdout,(out/'stderr').open('wb') as stderr:
  run=subprocess.run([str(exe),'./swap.swp'],cwd=case,input=payload.encode(),stdout=stdout,stderr=stderr,timeout=60)
 seconds=time.perf_counter()-started;assert run.returncode==100
 assert records(case/'result_output.csv')==records(a.full/'original/result_output.csv')
 with zipfile.ZipFile(a.terminal) as z:
  for n in ('result.end','macro.bin'):assert (case/n).read_bytes()==z.read(n),(mode,n)
 if mode=='hex-hydraulic':
  import struct
  headers=[]
  for s in (out/'stdout').read_text(encoding='cp1252').splitlines():
   if s.startswith('HYBRID_HYDRAULIC_HEX '):headers.append([struct.unpack('>d',bytes.fromhex(v))[0] for v in s.split()[1:]])
  assert len(headers)==last+1
  for row,head in zip(rows,headers[1:],strict=True):assert head[0]==row['groundwater_cm'] and head[2:]==row['pressure_head_cm']
 item=dict(mode=mode,seconds=seconds,exact_printed_csv=True,exact_terminal_native_auxiliary=True,exact_all_daily_hydraulic=mode=='hex-hydraulic')
 report.append(item);(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(item),flush=True)
