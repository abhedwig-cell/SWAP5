"""Actual kernel-reader decimal-word identity and receive boundary/error contract."""
from pathlib import Path
import argparse,ast,hashlib,io,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'));import daily_host as h
p=argparse.ArgumentParser();p.add_argument('--qualification',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--candidate-source',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
node=next(n for n in ast.parse(a.candidate_source.read_text()).body if isinstance(n,ast.FunctionDef) and n.name=='receive');ns=dict(h.__dict__);exec(compile(ast.Module(body=[node],type_ignores=[]),'private-rejected-receiver','exec'),ns);receive=ns['receive']
class Transcript(io.StringIO):
 def __init__(self):super().__init__();self.flushes=0
 def flush(self):self.flushes+=1;super().flush()
class Process:
 def __init__(self,lines):self.stdout=iter(lines)
 def wait(self):return 7
lines=['diagnostic\n','HYBRID_HYDRAULIC 1 2 -0.00000000000000000e0 3\n','HYBRID_DAY_RETURN 2 3\n'];t=Transcript();key,values=receive(Process(lines),t,{'HYBRID_DAY_RETURN'});assert key=='HYBRID_DAY_RETURN' and values['HYBRID_HYDRAULIC'][2]=='-0.00000000000000000e0';assert t.getvalue()==''.join(lines) and t.flushes==1
t=Transcript()
try:receive(Process(lines[:-1]),t,{'HYBRID_DAY_RETURN'})
except RuntimeError:pass
else:raise AssertionError('Missing reply accepted')
assert t.getvalue()==''.join(lines[:-1]) and t.flushes==1
def broken():
 yield 'diagnostic\n'
 raise OSError('broken pipe')
t=Transcript()
try:receive(Process(broken()),t,{'HYBRID_DAY_RETURN'})
except OSError:pass
else:raise AssertionError('Broken pipe accepted')
assert t.getvalue()=='diagnostic\n' and t.flushes==1
payload=[];count=0
for name in ('grass','hupsel','saltfarm'):
 f=a.qualification/(name+'-O2-candidate-full/original/donor.stdout')
 for line in f.read_text().splitlines():
  if line.startswith('HYBRID_HYDRAULIC '):
   words=line.split()[3:];payload.extend([str(len(words)),' '.join(str(float(s)) for s in words),' '.join(words)]);count+=len(words)
special=[0.,-0.,5e-324,-5e-324,1.7976931348623157e308,-1.7976931348623157e308,1e-300,-1e-300,1.,-1.,1e20,-1e20];payload.extend([str(len(special)),' '.join(map(str,special)),' '.join(format(v,'.17E') for v in special)]);count+=len(special);data=('\n'.join(payload)+'\n').encode();results={}
for opt in ('O0','O2'):
 exe=a.output/(opt+'.exe');cmd=['gfortran','-'+opt,'-ffree-line-length-none','-fcheck=all','-ffp-contract=off',str(Path(__file__).with_name('decimal_words.f90')),'-o',str(exe)];r=subprocess.run(cmd,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
 r=subprocess.run([str(exe)],input=data,capture_output=True,timeout=15);assert r.returncode==0,r.stderr;assert int(r.stdout.split()[-1])==count
 results[opt]=dict(words=count,stdout=r.stdout.decode(),commands=[cmd,[str(exe)]],executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest())
result=dict(status='REPLY_ERROR_TRANSCRIPT_AND_REAL_FORTRAN_DECIMAL_BITS_PASS',receive_return_flushes=1,eof_flushes=1,broken_read_flushes=1,actual_full_trajectory_words_and_edges=count,profiles=results,physical_tolerances_changed=False)
(a.output/'RESULT.json').write_text(json.dumps(result,indent=2));print(result['status'],count)
