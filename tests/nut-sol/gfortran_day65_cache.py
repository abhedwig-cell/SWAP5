"""Exact object/module reuse for the day65 private-backend-body successor.

The cache is an FC wrapper, not a numerical test replacement. Changed source,
flags, objects or module interfaces force real compilation. Native/link commands
always execute. Every hit/miss is recorded beside the new build artifacts.
"""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def flags(args,source,obj):
 values=[];skip=False;folder=str(obj.parent)
 for i,v in enumerate(args):
  if skip:skip=False;continue
  if v in ['-c','-o']:
   if v=='-o':skip=True
   continue
  if v==str(source):continue
  values.append(v.replace(folder,'@BUILD@'))
 return values
def prepare(a):
 records=[];seeds={};compiler=[str(a.compiler.resolve())]
 version=subprocess.check_output(compiler+['--version'],text=True).splitlines()[0]
 for base in a.project_base:
  meta=json.loads((base/'build-complete.json').read_text())
  assert meta['status']=='BUILT' and meta['compiler']==version
  records.append((meta['events'],meta['input_sha256'],base))
 if a.cold_base:
  meta=json.loads((a.cold_base/'result.json').read_text())
  assert meta['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'
  events=json.loads((a.cold_base/'events.json').read_text())
  records.append((events,meta['input_sha256'],a.cold_base))
 entries=[]
 for events,inputs,base in records:
  for e in events:
   cmd=e['command']
   if e['category']!='compile' or '-c'not in cmd or '-o'not in cmd:continue
   assert e.get('returncode',e.get('exit'))==0
   src=Path(cmd[cmd.index('-c')+1]);obj=Path(cmd[cmd.index('-o')+1])
   if src.is_relative_to(ROOT):
    key=str(src.relative_to(ROOT));expected=inputs.get(key)
    # A genuine baseline source hash is required for repository sources.
    assert expected is not None,('missing original source receipt',key)
   else:expected=sha(src)
   normalized=flags(cmd[1:],src,obj)
   modules={str(p.name):sha(p)for p in obj.parent.iterdir()if p.suffix in ['.mod','.smod']}
   seeds[str(obj.parent)]=modules
   entries.append(dict(source_sha256=expected,object=str(obj),object_sha256=sha(obj),
    flags=normalized,directory=str(obj.parent)))
 data=dict(schema=1,compiler=compiler,compiler_version=version,entries=entries,seeds=seeds,
  source_receipts={str(base):sha(base/('result.json'if(base/'result.json').exists()else'build-complete.json'))for _,_,base in records})
 a.manifest.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps(dict(objects=len(entries),manifest=str(a.manifest))))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--manifest',type=Path,required=True)
 ap.add_argument('--prepare',action='store_true');ap.add_argument('--project-base',type=Path,action='append',default=[])
 ap.add_argument('--cold-base',type=Path);ap.add_argument('--compiler',type=Path)
 a,args=ap.parse_known_args()
 if a.prepare:prepare(a);return
 data=json.loads(a.manifest.read_text());compiler=data['compiler']
 if '-c'not in args or '-o'not in args:
  raise SystemExit(subprocess.run(compiler+args).returncode)
 src=Path(args[args.index('-c')+1]).resolve();obj=Path(args[args.index('-o')+1]).resolve()
 folder=obj.parent;normalized=flags(args,src,obj);digest=sha(src)
 matches=[e for e in data['entries']if e['source_sha256']==digest and e['flags']==normalized]
 marker=folder/'.day65-cache-seeded.json'
 if not marker.exists():
  # Choose only a flag-compatible optimization/profile for module seeding.
  candidates=[e for e in data['entries']if e['flags']==normalized]
  if candidates:
   old=Path(candidates[0]['directory']);expected=data['seeds'][str(old)]
   for name,h in expected.items():
    p=old/name;assert sha(p)==h
    if not(folder/name).exists():shutil.copyfile(p,folder/name)
   marker.write_text(json.dumps(dict(directory=str(old),module_sha256=expected))+'\n')
 reusable=bool(matches)and marker.exists()
 if reusable:
  expected=json.loads(marker.read_text())['module_sha256']
  reusable=all((folder/name).is_file()and sha(folder/name)==h for name,h in expected.items())
 event=dict(source=str(src),source_sha256=digest,object=str(obj),reused=False)
 if reusable:
  old=matches[0];assert sha(Path(old['object']))==old['object_sha256']
  shutil.copyfile(old['object'],obj);event.update(reused=True,from_object=old['object'],object_sha256=sha(obj));code=0
 else:
  code=subprocess.run(compiler+args).returncode
  if code==0:event['object_sha256']=sha(obj)
 event['returncode']=code
 with(folder/'day65-cache-events.jsonl').open('a')as stream:stream.write(json.dumps(event)+'\n')
 raise SystemExit(code)
if __name__=='__main__':main()
