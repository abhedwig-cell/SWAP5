"""Full original B1 counterfactual: remove only the inherited early-Ksat shortcut."""
import argparse,csv,hashlib,json,shutil,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--donor',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);p.add_argument('--profiles',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args()
donor=a.donor.resolve();ref=a.reference.resolve();profile=a.profiles.resolve();out=a.output.resolve();out.mkdir();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();b=json.loads((donor/'BUILD.json').read_text());fc=str(a.compiler.resolve())
original=donor/'providers/selected/MOD_MvG_functions.f90';assert sha(original)==b['original_provider_build']['source_sha256']['source/SWAP/MOD_MvG_functions.f90']
s=original.read_text();old='relsat > (1.0d0-1.0d-6)';assert s.count(old)==2;source=out/'MOD_MvG_continuous_reference.f90';source.write_text(s.replace(old,'relsat >= 1.0d0'))
report=dict(scope='B1_CONFIRMED_LEGACY_SHORTCUT_CORRECTION_NOT_UNMODIFIED_B0',physical_input_changes=False,source_change='Exactly two early-Ksat tests: threshold1-1e-6 replaced by saturation1. No retention, Mualem parameters, KSATEXM, solver controls or crop change.',original_source_sha256=sha(original),corrected_source_sha256=sha(source),original_build_sha256=sha(donor/'BUILD.json'),events=[])
def run(cmd,label,cwd=out,timeout=120):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=timeout);(out/(label+'.stdout')).write_bytes(r.stdout);(out/(label+'.stderr')).write_bytes(r.stderr);report['events'].append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-t));(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');return r.returncode
obj=out/'MOD_MvG_continuous_reference.o';flags=['-O2','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none','-I'+str(donor/'providers/swobj'),'-I'+str(donor/'providers/ttobj'),'-J'+str(out)]
assert run([fc,*flags,'-c',source,'-o',obj],'compile')==0
link=list(b['commands'][-1]);link[0]=fc
for i,v in enumerate(link):
 if v.endswith('/MOD_MvG_functions.o'):link[i]=str(obj)
 if v.endswith('/swapoutput.o'):link[i]=str(profile/'swapoutput_profiles.o')
exe=out/'swap431_continuous_reference';link[-1]=str(exe);report['reused_artifacts_sha256']={v:sha(Path(v))for v in link if v.endswith(('.o','.a'))and v!=str(obj)}
assert run(link,'link')==0;report['executable_sha256']=sha(exe)
case=out/'original';case.mkdir()
for n in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']:shutil.copyfile(ref/n,case/n)
report['inputs_sha256']={n:sha(case/n)for n in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']}
assert run([exe],'native',cwd=case)==100 and(case/'swap.ok').exists()
read=lambda p:list(csv.DictReader(l for l in p.read_text().splitlines()if l.strip()and not l.startswith('*')))
new=read(case/'result_output.csv');oldrows=read(ref/'result_output.csv');assert len(new)==len(oldrows)==1828 and new[-1]['DATE']==oldrows[-1]['DATE']
report.update(status='B1_ORIGINAL1827_COMPLETE',original_days=1827,rows=len(new),maximum_B1_minus_B0_differences={k:max(abs(float(x[k])-float(y[k]))for x,y in zip(new,oldrows))for k in ['WTOT','TACT','TPOT','GWL','WRT','WLV','WST','HRVDM','PHRVDM']},maximum_source_reported_BALDEV_cm=max(abs(float(x['BALDEV']))for x in new),scientific_equivalence=False,arithmetic_limit='Original B1 reference retains its ordinary arithmetic; SWAP5 uses the existing stable log1p/expm1 implementation of the same continuous Mualem relation.')
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k not in ['events','reused_artifacts_sha256']},indent=2))
