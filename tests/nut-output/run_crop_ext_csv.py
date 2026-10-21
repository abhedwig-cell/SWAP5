"""Local real complete-file adapter checks, with raw compiler/native receipts."""
import argparse,hashlib,json,os,pathlib,shlex,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
paths=['src/adapter/mod_soil_n_crop_extended_output.f90','src/adapter/mod_crop_ext_csv_file.f90','tests/nut-output/test_crop_ext_csv.f90']
events=[];results={};sha=lambda b:hashlib.sha256(b).hexdigest()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();exe=b/'csv'
 commands=[('compile_link',shlex.split(os.environ.get('FC','gfortran'))+['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),*[str(ROOT/p)for p in paths],'-o',str(exe)]),('native',[str(exe)])]
 for category,cmd in commands:
  t=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True);e=dict(optimization=opt,category=category,command=cmd,returncode=r.returncode,seconds=time.perf_counter()-t)
  for k in ['stdout','stderr']:
   n=opt+'-'+category+'.'+k;v=getattr(r,k);(OUT/n).write_bytes(v);e[k]=n;e[k+'_sha256']=sha(v)
  events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
  if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 assert not list(b.glob('*.pending-*'))
 results[opt]=dict(stdout=r.stdout.decode(),csv_sha256=sha((b/'crop.csv').read_bytes()))
assert results['O0']==results['O2']
paths.append('tests/nut-output/run_crop_ext_csv.py')
(OUT/'result.json').write_text(json.dumps(dict(status='COMPLETE_CROP_EXT_CSV_O0_O2_PASS',results=results,input_sha256={p:sha((ROOT/p).read_bytes())for p in paths}),indent=2)+'\n')
print('COMPLETE_CROP_EXT_CSV_O0_O2_PASS')
