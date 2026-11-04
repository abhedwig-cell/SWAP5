"""Replay typed pressure owner on every actual original accepted day584 MICRO input."""
import argparse,json,subprocess,hashlib,math
from pathlib import Path
import micro_pressure_probe as probe
ROOT=probe.ROOT
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def run(capture,out,compiler):
 assert json.loads((capture/'COMPLETE.json').read_text())['exact_original_controls']
 out.mkdir()
 table,process=probe.sources('pressure')
 assert process.count(probe.TRACE)==1
 process=process.replace(probe.TRACE,'')
 assert process==(ROOT/probe.PROCESS).read_text().replace(probe.OLD,probe.NEW)
 for opt in ('O0','O2'):
  build=out/opt;build.mkdir()
  (build/'table.f90').write_text(table,encoding='utf-8',newline='\n')
  (build/'process.f90').write_text(process,encoding='utf-8',newline='\n')
  exe=build/'compare.exe'
  cmd=[str(compiler),'-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
       '-ffpe-trap=invalid,zero,overflow','-I'+str(build),'-J'+str(build),str(build/'table.f90'),
       str(build/'process.f90'),str(ROOT/'tests/dataqual15_hupsel/original_micro_comparison.f90'),'-o',str(exe)]
  p=subprocess.run(cmd,cwd=build,capture_output=True,timeout=120)
  (build/'compile.stdout').write_bytes(p.stdout);(build/'compile.stderr').write_bytes(p.stderr)
  assert p.returncode==0,p.stderr
  frame=capture/'case/original_micro_inputs.dat';tables=capture/'case/original_micro_tables.dat'
  p=subprocess.run([str(exe),str(frame),str(tables)],cwd=build,capture_output=True,timeout=300)
  (build/'comparison.stdout').write_bytes(p.stdout);(build/'comparison.stderr').write_bytes(p.stderr)
  assert p.returncode==0,p.stderr
  rows=[list(map(float,l.split())) for l in p.stdout.splitlines()]
  assert rows and all(len(r)==8 and all(map(math.isfinite,r)) for r in rows)
  assert [int(r[0]) for r in rows]==list(range(1,len(rows)+1))
  record=dict(command=cmd,compiler=subprocess.check_output([str(compiler),'--version'],text=True).splitlines()[0],
   executable_sha256=sha(exe),inputs_sha256={str(x):sha(x) for x in (frame,tables)},
   table_source_sha256=sha(build/'table.f90'),process_source_sha256=sha(build/'process.f90'),
   actual_accepted_steps=len(rows),maximum_node_sink_error=max(r[3] for r in rows),
   maximum_total_sink_error=max(abs(r[5]-r[4]) for r in rows),
   integrated_total_sink_delta_cm=math.fsum(r[2]*(r[5]-r[4]) for r in rows),
   maximum_root_pressure_difference_cm=max(abs(r[6]) for r in rows),production_admission=False)
  (build/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True)
 p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args()
 run(a.capture.resolve(),a.output.resolve(),a.compiler.resolve())
