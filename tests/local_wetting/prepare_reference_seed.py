"""Materialize the original-readable saved362 seed for its own platform grid."""
import argparse,csv,json,re,shutil,zipfile,hashlib
from pathlib import Path
def main():
 p=argparse.ArgumentParser();p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);original=a.capture/'candidate/original'
 rows=list(csv.DictReader(s for s in (original/'result_output.csv').read_text(encoding='cp1252').splitlines() if s and not s.startswith('*')));assert len(rows)==366 and all(float(r['IRRIG'])==0 for r in rows[363:366])
 for f in original.iterdir():
  if f.is_file() and f.suffix.lower() in ('.swp','.met','.crp','.dra','.ru','.cmd','.inp'):shutil.copy2(f,out/f.name)
 source=a.capture/'candidate/accepted-column-1-day-362.zip'
 with zipfile.ZipFile(source) as z:
  (out/'restart.end').write_bytes(z.read('result.end'));(out/'macro.bin').write_bytes(z.read('macro.bin'))
 p=out/'swap.swp';s=p.read_text(encoding='cp1252')
 for key,value in [('TSTART','2002-12-29'),('TEND','2002-12-31'),('SWINCO','3'),('INIFIL',"'restart.end'"),('SWIRFIX','0')]:
  s,n=re.subn(r'(?m)^([ \t]*'+key+r'[ \t]*=[ \t]*)(?:\x27[^\x27]*\x27|[^\s!]+)',lambda m:m[1]+value,s);assert n==1,key
 s+='\nSWINITYPE = 2\n';p.write_text(s,encoding='cp1252');shutil.copy2(original/'accepted-grid.txt',out.parent/'own-grid.txt')
 record={'actual_no_irrigation_interval':True,'literal_executed_input_equality':False,'original_capsule_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'initial':rows[362],'nominal_day364':rows[364],'source_capture':json.loads((a.capture/'RESULT.json').read_text())};(out.parent/'OWN_TARGET.json').write_text(json.dumps(record,indent=2));print(record['nominal_day364']['GWL'])
if __name__=='__main__':main()
