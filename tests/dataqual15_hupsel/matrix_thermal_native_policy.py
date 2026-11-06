"""Private exact S5MT logical-decoding/native-publication candidate; no admission."""
import hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='52a9513b7975dbe7f922f635f771d2d781da8a3d'
SOURCE='src/adapter/mod_matrix_thermal_restart_file.f90'
sha=lambda b:hashlib.sha256(b).hexdigest()
def before(n):return subprocess.check_output(['git','show',BASE+':'+n],cwd=ROOT).decode()

def candidate(validate=True):
 s=before(SOURCE).replace('one POSIX generation','one native generation')
 s=s.replace("function rename_c(a,b)bind(C,name='rename')", "function rename_c(a,b)bind(C,name='swap5_restart_publish')")
 for name in ('open_c','sync_c','close_c'):
  s,count=re.subn(r'^  integer\(c_int\) function '+name+r'\(.*?^  end function\n','',s,flags=re.M|re.S);assert count==1,name
 a=s.index(' integer function synchronize(');z=s.index(' subroutine bytes(',a);s=s[:a]+s[z:]
 s=s.replace('   if(synchronize(pending)/=0)exit writing\n','')
 a=s.index("   slash=index(path,'/',back=.true.)");z=s.index('   status=0',a);s=s[:a]+s[z:]
 if not validate:return s
 # Never evaluate malformed host logicals, including before a history branch.
 s=s.replace('  integer(int8)::extra','  integer(int8)::extra\n  integer(int8)::bound_raw(storage_size(.true.)/8),history_raw(storage_size(.true.)/8)')
 old='r%committed_time,r%time_bound, &\n     n,history,physical_id,count';assert s.count(old)==1
 s=s.replace(old,'r%committed_time,bound_raw, &\n     n,history_raw,physical_id,count',1)
 anchor='    io=1\n    if(tag/=';assert s.count(anchor)==1
 s=s.replace(anchor,"    io=1\n    if(.not.logical_raw_valid(bound_raw).or..not.logical_raw_valid(history_raw))exit decoding\n    r%time_bound=all(bound_raw==transfer(.true.,bound_raw))\n    history=all(history_raw==transfer(.true.,history_raw))\n    if(tag/=",1)
 anchor='   associate(r=>b%records(1))\n    write';assert s.count(anchor)==1
 s=s.replace(anchor,'   associate(r=>b%records(1))\n    if(.not.logical_value_valid(r%time_bound).or..not.logical_value_valid(history))exit writing\n    write',1)
 addition=''' logical function logical_raw_valid(raw)result(ok)
  integer(int8),intent(in)::raw(:)
  integer(int8)::yes(storage_size(.true.)/8),no(storage_size(.false.)/8)
  yes=transfer(.true.,yes);no=transfer(.false.,no)
  ok=.false.;if(size(raw)/=size(yes))return
  ok=all(raw==yes).or.all(raw==no)
 end function
 logical function logical_value_valid(value)result(ok)
  logical,intent(in)::value
  integer(int8)::raw(storage_size(value)/8)
  raw=transfer(value,raw);ok=logical_raw_valid(raw)
 end function
'''
 assert s.count('contains\n')==1;s=s.replace('contains\n','contains\n'+addition,1)
 return s

def guard():
 assert not subprocess.check_output(['git','diff',BASE,'--','src','app','reference'],cwd=ROOT)
 assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','src','app','reference'],cwd=ROOT)
 r=json.loads((ROOT/'integration/dataqual15_hupsel/MATRIX_THERMAL_NATIVE_PREREGISTRATION_20261106.json').read_text());assert r['baseline']==BASE and r['production_delta']==[]
 for n,h in r['source_sha256'].items():assert sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n'))==h,n
 return r
