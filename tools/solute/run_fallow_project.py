#!/usr/bin/env python3
"""Execute original direct-PM pre-emergence physics through the shared project runtime."""
import argparse,base64,hashlib,json,re,subprocess,sys,tempfile
from pathlib import Path
from run_project import resolve_file
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('swp',type=Path)
 p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--prepare-days',type=int,default=120);p.add_argument('--stop-at-day',type=float,required=True)
 p.add_argument('--restart',type=Path);p.add_argument('--timeout-seconds',type=float,default=120);a=p.parse_args()
 swp=a.swp.resolve();raw=swp.read_bytes();bundle=json.loads((a.bundle/'bundle.json').read_text())
 assert not bundle.get('native_water')and 'fallow_reader'in bundle
 reader=Path(bundle['fallow_reader']);assert sha(reader.read_bytes())==bundle['executable_sha256'][str(reader)]
 meta=json.loads((reader.parent/'build-complete.json').read_text())
 for name,h in meta['input_sha256'].items():assert sha((ROOT/name).read_bytes())==h,name
 lines='\n'.join(l for l in raw.decode('latin-1').splitlines()if not l.lstrip().startswith('*'))
 def original_ref(key,default=None):
  matches=re.findall(r'^\s*'+key+r'\s*=\s*[\"\']([^\"\']*)[\"\']',lines,re.M|re.I)
  if not matches:
   if default is None:raise ValueError('original reference missing: '+key)
   return default
  if len(matches)!=1:raise ValueError('ambiguous original reference '+key)
  return matches[0].replace('\\','/').strip()
 met=original_ref('metfil');assert met.lower().endswith('.met'),'single original MET file required'
 weather=resolve_file(swp.parent,str(Path(original_ref('pathatm',''))/met))
 drain=resolve_file(swp.parent,str(Path(original_ref('pathdrain',''))/(original_ref('drfil')+'.dra')))
 sources=dict(original_swp=raw,original_weather=weather.read_bytes(),original_drainage=drain.read_bytes())
 with tempfile.TemporaryDirectory(prefix='swap5-original-fallow-')as tmp:
  stage=Path(tmp)
  for name,key in [('input.swp','original_swp'),('input.met','original_weather'),('input.dra','original_drainage')]:
   (stage/name).write_bytes(sources[key])
  r=subprocess.run([str(reader),'input.swp','input.met','input.dra',str(a.prepare_days)],cwd=stage,stdin=subprocess.DEVNULL,capture_output=True,timeout=30)
  if r.returncode:raise ValueError(r.stdout.decode(errors='replace')+r.stderr.decode(errors='replace'))
  document=(stage/'input.nml').read_text()
  ends=[float(x)for x in re.search(r'^ends_day=(.*)$',document,re.M)[1].split(',')if x.strip()]
  selected=[i+1 for i,t in enumerate(ends)if abs(t-a.stop_at_day)<=1e-10]
  if len(selected)!=1:raise ValueError('stop-at-day must be an original forcing boundary')
  comments=[]
  for name,b in sources.items():
   comments.append('! '+name+'_sha256='+sha(b));encoded=base64.b64encode(b).decode()
   comments+=['! '+name+'_base64='+encoded[i:i+76]for i in range(0,len(encoded),76)]
  comments+=['! fallow_reader_sha256='+sha(reader.read_bytes())]
  (stage/'input.nml').write_text('\n'.join(comments)+'\n'+document)
  cmd=[sys.executable,ROOT/'tools/solute/run_column.py','--exe',bundle['exe'],'--input',stage/'input.nml',
    '--swp',stage/'input.swp','--output',a.output.resolve(),'--stop-after',str(selected[0]),'--timeout-seconds',str(a.timeout_seconds)]
  if a.restart:cmd+=['--restart',a.restart.resolve()]
  subprocess.run(list(map(str,cmd)),check=True)
if __name__=='__main__':main()
