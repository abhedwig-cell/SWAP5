"""Execute only newly selected CDE9 calendar contexts; never replay other cohorts."""
import argparse,json,subprocess,sys
from pathlib import Path
from explicit_bottom9_cde_calendar_inputs import CASES,prepare
from explicit_bottom9_source_inverse import ROOT,git,complete_inverse
from explicit_bottom9_cde_calendar_science import audit
from analytical_hydraulic_archives import SHA


def execute(case,opt,inputs,reference,primary_build,counter_build,profile,post):
 assert case in CASES and opt in ('O0','O2')
 source=git('rev-parse','HEAD').decode().strip();complete_inverse()
 distributed=case=='cde-distributed-subdaily';initial=2 if distributed else 1
 primary=inputs/(case+'-initial'+str(initial));counter=inputs/(case+'-initial'+str(3-initial))
 for selector,target in [(initial,primary),(3-initial,counter)]:
  assert not target.exists();prepare(case,target,selector)
 def run(name,args):
  assert git('rev-parse','HEAD').decode().strip()==source
  subprocess.run([sys.executable,'-B',str(ROOT/'tests/nomacro_drainage'/name),*map(str,args)],cwd=ROOT,check=True)
 run('explicit_bottom9_runtime.py',['--case',case,'--input',primary,'--reference-work',reference,'--build-root',primary_build,'--output',profile,'--optimization',opt])
 run('explicit_bottom9_drain_postimage.py' if distributed else 'explicit_bottom9_postimage.py',['--profile',profile,'--input',counter,'--reference-work',reference,'--build-root',counter_build,'--output',post])
 result=audit(profile,reference,post)
 output=profile.with_name(profile.name+'-INDEPENDENT.json')
 with output.open('x',encoding='utf-8') as out:json.dump(result,out,indent=2);out.write('\n')
 return dict(case=case,optimization=opt,source=source,profile=str(profile),postimage=str(post),independent=str(output),independent_sha256=SHA(output.read_bytes()),whole_compiled=result['whole_compiled_binary'],status=result['status'])


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',choices=CASES,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True)
 for key in ('inputs','reference-work','primary-build','counter-build','profile','postimage','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();result=execute(a.case,a.optimization,a.inputs,a.reference_work,a.primary_build,a.counter_build,a.profile,a.postimage)
 with a.output.open('x',encoding='utf-8') as out:json.dump(result,out,indent=2);out.write('\n')
 print(result['status'],a.case,a.optimization,flush=True)
