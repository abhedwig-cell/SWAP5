"""Four actual wet-cut windows: controlled incumbent/current pair and restart.

The measured native prefix uses the registered DTMAX0.01 diagnostic variant.
Every run retains original input bytes and normal CRC/owner/source validation;
no predecessor override, checkpoint editing or whole-scientific promotion.
"""
import argparse,csv,hashlib,json,os,re,shutil,struct,subprocess,sys,time
from pathlib import Path
from qualify_rotation_restart_guards import locations
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,required=True);p.add_argument('--exe',type=Path,required=True);p.add_argument('--baseline-exe',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();case=a.case.resolve();exe=a.exe.resolve();oldexe=a.baseline_exe.resolve();out=a.output.resolve();out.mkdir();events=[];observations=[]
prefix=json.loads((case/'RESULT.json').read_text());assert prefix['returncode']==0 and prefix['from_start']
assert all((case/f'checkpoint-{i}.bin').is_file()for i in (929,930,931,955,956,957,988,989,990,1032,1033,1034))
original=ROOT/'reference/swap-4.3.1/projects/1.hupselbrook';pattern=rb'(?im)^(\s*DTMAX\s*=\s*)[\d.eE+\-]+'
normalize=lambda raw:re.sub(pattern,lambda m:m[1]+b'REGISTERED_DTMAX',raw)
assert normalize((case/'swap.swp').read_bytes())==normalize((original/'swap.swp').read_bytes())
for n in ('maize.crp','potato.crp','grass.crp','283.met','swap.dra'):assert (case/n).read_bytes()==(original/n).read_bytes(),n
def run_window(name,program,restart,end):
 folder=out/name
 command=[sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/run_canopy_observation.py'),'--exe',str(program),'--predecessor',str(case),'--strict-restart',str(restart),'--compatibility-control','--output',str(folder),'--end',str(end),'--timeout','120']
 start=time.monotonic();r=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=150);events.append(dict(command=command,returncode=r.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,(r.stdout,r.stderr)
 report=json.loads((folder/'RESULT.json').read_text());assert report['returncode']==0,folder
 return folder
def decode_control(name,checkpoint,expected,program=exe):
 folder=out/name;folder.mkdir()
 for f in case.iterdir():
  if f.suffix in ('.swp','.crp','.met','.dra','.nml'):shutil.copyfile(f,folder/f.name)
 raw=checkpoint.read_bytes();clock=struct.unpack_from('=d',raw,8)[0];nml=(case/'input.nml').read_text();ends=[float(v)for v in re.search('^ends_day=(.*)$',nml,re.M)[1].split(',')if v.strip()];stop=next(i+1 for i,v in enumerate(ends)if v==clock)
 env=os.environ.copy();env.pop('SWAP5_DIAG_PREDECESSOR',None)
 r=subprocess.run([str(program),'input.nml',str(checkpoint.resolve()),str(stop),'swap.swp','maize.crp'],cwd=folder,env=env,capture_output=True,timeout=30)
 (folder/'stdout').write_bytes(r.stdout);(folder/'stderr').write_bytes(r.stderr)
 decoded=b'no requested windows remain'in r.stdout+r.stderr
 rejected=any(marker in r.stdout for marker in (b'source rotation envelope rejected before publication',b'restart rejected'))
 assert r.returncode==1 and decoded==expected and (decoded or rejected),(folder,r.stdout,r.stderr)
 assert not any((folder/n).exists()for n in ('budget.csv','crop.csv','checkpoint.bin','germination.csv'))
 return dict(name=name,returncode=r.returncode,decoded=decoded,checkpoint_sha256=sha(checkpoint))
for cut in (930,956,989,1033):
 seed=case/f'checkpoint-{cut-1}.bin';current=run_window(f'{cut}-current',exe,seed,cut);incumbent=run_window(f'{cut}-incumbent',oldexe,seed,cut)
 continuous=run_window(f'{cut}-continuous',exe,seed,cut+1);resumed=run_window(f'{cut}-resumed',exe,current/'checkpoint.bin',cut+1)
 assert (continuous/'checkpoint.bin').read_bytes()==(resumed/'checkpoint.bin').read_bytes(),'same-build restart must be exact'
 # This second leg's checkpoint was produced by precisely this executable.
 rr=json.loads((resumed/'RESULT.json').read_text());assert rr['executable_sha256']==json.loads((current/'RESULT.json').read_text())['executable_sha256'];rr['scope']='STRICT_SAME_BUILD_RESTART_MEASUREMENT';(resumed/'RESULT.json').write_text(json.dumps(rr,indent=2)+'\n')
 new=(current/'checkpoint.bin').read_bytes();old=(incumbent/'checkpoint.bin').read_bytes();loc=locations(new);assert locations(old)==loc
 assert new==(case/f'checkpoint-{cut}.bin').read_bytes(),'coherent current codec must preserve measured physical prefix endpoint'
 assert struct.unpack_from('=q',new,loc['physical']+128)[0]==struct.unpack_from('=q',old,loc['physical']+128)[0]+1
 stock0=struct.unpack_from('=d',old,loc['rutter']+4)[0];stock1=struct.unpack_from('=d',new,loc['rutter']+4)[0]
 left=bytearray(old);right=bytearray(new)
 for off,n in [(loc['physical']+128,8),(loc['rutter']+4,8),(loc['physical_end']-4,4),(loc['maize_end']-4,4),(len(new)-4,4)]:left[off:off+n]=right[off:off+n]=bytes(n)
 assert left==right,'unreviewed soil/pond/thermal/chemical/crop/source-input change'
 budget=list(csv.DictReader((current/'budget.csv').open()))[-1];crop=list(csv.DictReader((current/'crop.csv').open()))[-1];following=list(csv.DictReader((continuous/'budget.csv').open()))[-1]
 loss=float(budget['canopy_capacity_export_cm']);capacity=float(crop['post_management_capacity_cm'])
 assert stock0>capacity and stock1==capacity and abs(loss-(stock0-stock1))<1e-14
 assert abs(float(budget['water_residual_cm']))<=1e-10 and abs(float(budget['solute_residual_mg_cm2']))<=1e-10
 assert float(following['canopy_capacity_export_cm'])==0.0,'following day must not export the same cut again'
 controls=[decode_control(f'{cut}-valid-current-read',current/'checkpoint.bin',True),decode_control(f'{cut}-incumbent-accepts-old-state',incumbent/'checkpoint.bin',True,oldexe),decode_control(f'{cut}-refuse-uncorrected-state',incumbent/'checkpoint.bin',False)]
 observations.append(dict(cut=cut,stock_before=stock0,stock_after=stock1,accepted_capacity=capacity,export_cm=loss,next_day_capacity_export_cm=0.0,water_residual_cm=float(budget['water_residual_cm']),solute_residual_mg_cm2=float(budget['solute_residual_mg_cm2']),same_build_restart_exact=True,all_other_typed_owner_bytes_exact=True,coherence_controls=controls))
 (out/'OBSERVATIONS.json').write_text(json.dumps(observations,indent=2)+'\n')
report=dict(status='FOUR_ACTUAL_WET_CUTS_MASS_OWNER_ISOLATION_EXACT_RESTART_AND_COHERENT_CHECKPOINT_PASS',current_executable_sha256=sha(exe),incumbent_executable_sha256=sha(oldexe),prefix_executable_sha256=prefix['executable_sha256'],inputs=prefix['inputs'],observations=observations,full_scientific_qualification=False,scope='Actual same-input window pairs on original-source diagnostic DTMAX0.01 trajectory; separate scalar capacity physics correction, no whole-project envelope retuning')
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
