"""Actual dirty and committed tolerance corruption in a private Git image."""
from pathlib import Path
import argparse,importlib.util,json,subprocess
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
root=Path(__file__).resolve().parents[2];spec=importlib.util.spec_from_file_location('newton',Path(__file__).with_name('verify_successor.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def run(cwd,*args,stdin=None):return subprocess.check_output(['git',*args],cwd=cwd,input=stdin)
head=run(root,'rev-parse','HEAD').decode().strip();common=Path(run(root,'rev-parse','--git-common-dir').decode().strip());common=(root/common).resolve() if not common.is_absolute() else common
image=a.output/'image';image.mkdir();run(image,'init');alt=image/'.git/objects/info/alternates';alt.write_text((common/'objects').as_posix()+'\n',encoding='utf8',newline='\n');run(image,'update-ref','HEAD',head);run(image,'read-tree','HEAD');paths=run(image,'ls-files','-z');run(image,'update-index','--skip-worktree','-z','--stdin',stdin=paths)
target='app/hybrid_water/daily_host.py'
for name in (target,m.ENTRY):
 path=image/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(run(root,'show',head+':'+name))
run(image,'update-index','--no-skip-worktree','--',target)
path=image/target;original=path.read_bytes();anchor=b'\n         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.\n';assert original.count(anchor)==1;path.write_bytes(original.replace(anchor,anchor.replace(b'1d-10',b'2d-10')))
m.ROOT=image;checks=[]
def refuse(stage):
 try:m.source_guard()
 except ValueError as ex:checks.append(dict(stage=stage,refused=True,reason=str(ex)))
 else:raise AssertionError('Actual relaxed guard admitted')
refuse('actual_dirty_2e-10_water_guard');run(image,'add','--',target);tree=run(image,'write-tree').decode().strip();bad=run(image,'-c','user.name=Source verification','-c','user.email=verification@invalid.test','commit-tree',tree,'-p',head,'-m','Private unadmitted relaxed Newton water guard').decode().strip();run(image,'update-ref','HEAD',bad);refuse('actual_committed_2e-10_water_guard')
assert run(image,'diff','--name-only',head,bad).decode().splitlines()==[target]
result=dict(status='ACTUAL_DIRTY_AND_COMMITTED_RELAXED_WATER_GUARD_REFUSED',base=head,unadmitted_private_commit=bad,private_image=str(image),checks=checks);(a.output/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
