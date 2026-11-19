"""Current nonselected weather seam against immutable admitted actual evidence."""
import argparse,json,subprocess,sys,zipfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as prior
m=prior.m;ROOT=prior.ROOT

def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--case',choices=['pulsed','hourly'],required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True)
 a=p.parse_args()
 command=[sys.executable,'-B',str(ROOT/'tests/nomacro_scheduled_subsurface/weather_surface_runtime.py'),'--case',a.case,'--days','5','--optimization',a.optimization,'--reference-work',str(a.reference_work),'--build-root',str(a.build_root),'--output',str(a.output)]
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240)
 (a.output/'preservation.stdout').write_text(r.stdout,encoding='utf8');(a.output/'preservation.stderr').write_text(r.stderr,encoding='utf8');r.check_returncode()
 q=json.loads((a.output/'RESULT.json').read_text());build=Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text());data=m.rows(a.output/'trajectory')
 archive=ROOT/f'integration/f-ci/nomacro-complete01/WEATHER_TERMINAL_WINDOWS_{a.optimization}_RAW_ARCHIVE.zip'
 with zipfile.ZipFile(archive) as z:
  prefix=a.case+'-build/';old=json.loads(z.read(prefix+'BUILD.json'))
  sources={name[len(prefix):]:z.read(name) for name in z.namelist() if name.startswith(prefix) and '/' not in name[len(prefix):] and name.endswith('.f90')}
  assert {f.name:f.read_bytes() for f in build.glob('*.f90')}==sources,'Changed actual nonselected generated Fortran'
  assert meta['inputs']==old['inputs'] and meta['identity']['kernel_sources']==old['identity']['kernel_sources'],'Changed actual nonselected inputs/kernel'
  previous=[json.loads(line) for line in z.read(a.case+'/trajectory/daily.jsonl').splitlines()][:5]
  assert m.physical(data)==m.physical(previous),'Changed nonselected physical5day prefix'
  for day in (2,4):
   import io
   with zipfile.ZipFile(a.output/f'trajectory/accepted-column-1-day-{day}.zip') as current,zipfile.ZipFile(io.BytesIO(z.read(a.case+f'/trajectory/accepted-column-1-day-{day}.zip'))) as gold:
    assert all(current.read(n)==gold.read(n) for n in ('result.end','macro.bin')),'Changed nonselected complete native prefix'
 record=dict(status='ACTUAL_CURRENT_NONSELECTED_WEATHER_INPUT_FORTRAN_KERNEL_PHYSICAL_NATIVE_PRESERVATION_PASS',case=a.case,optimization=a.optimization,current_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actual_days=5,old_archive=archive.name,old_archive_sha256=m.sha(archive),exact_inputs=True,exact_generated_fortran=True,exact_kernel_sources=True,exact_physical_prefix=True,exact_prior_complete_native_days=[2,4],current_exact_cold_window=[2,4],fresh_unaffected_full_periods=0)
 (a.output/'PRESERVATION.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8');print(record['status'],a.case,a.optimization)

if __name__=='__main__':main()
