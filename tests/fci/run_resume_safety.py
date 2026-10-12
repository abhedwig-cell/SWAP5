#!/usr/bin/env python3
"""Real O0/O2 leaf mutation and interruption trial in a disposable checkout."""
import copy,hashlib,json,os,secrets,signal,subprocess,time,shutil
from pathlib import Path
import argparse,tempfile
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--toolchain-dirs',required=True)
args=parser.parse_args()
SOURCE=Path(__file__).resolve().parents[2]
OUT=args.output.resolve();OUT.mkdir(parents=True,exist_ok=True)
ROOT=OUT/'checkout'
subprocess.run(['git','worktree','add','--detach',str(ROOT),'HEAD'],cwd=SOURCE,check=True)
STORE=OUT/'receipts';KEY=OUT/'key';KEY.write_bytes(secrets.token_bytes(32));KEY.chmod(0o600)
PRIVATE=OUT/'private-build';PRIVATE.mkdir()
ENV=dict(os.environ,TMPDIR=str(PRIVATE),FCI_RESUME_MODE='SHADOW',FCI_RESUME_STORE=str(STORE),FCI_RESUME_KEY=str(KEY),FCI_RESUME_TOOLCHAIN_DIRS=args.toolchain_dirs)
CMD=['python','tools/fci/resume_group.py','frost-invalid','bash','tests/frost/run_frost_invalid_input_preservation.sh']
results=[]
def run(name,env=None,cmd=None,inherit=False,exit_code=0):
 t=time.monotonic();p=subprocess.run(cmd or CMD,cwd=ROOT,env=env or ENV,capture_output=True)
 b=p.stdout+p.stderr;(OUT/(name+'.log')).write_bytes(b)
 actual=b'FCI_RESUME_INHERITED frost-invalid' in b
 assert actual==inherit,(name,b)
 if (env or ENV)['FCI_RESUME_MODE']=='RESUME' and not inherit:
  assert b'\"decision\": \"RUN\"' in b or b'FCI_RESUME_RUN' in b,(name,b)
 results.append({'case':name,'exit_code':p.returncode,'inherited':actual,'wall_seconds':time.monotonic()-t,'log_sha256':hashlib.sha256(b).hexdigest()})
 if name=='between-groups':assert p.returncode==75
 elif exit_code is None:assert p.returncode in [0,1],(name,b)
 else:assert p.returncode==exit_code,(name,b)
 return b
run('original-off',dict(ENV,FCI_RESUME_MODE='OFF'))
run('uninterrupted-shadow')
snapshot={f.name:f.read_bytes() for f in STORE.iterdir() if f.suffix in ['.json','.log']}
def reset():
 for name,b in snapshot.items():(STORE/name).write_bytes(b)
resume=dict(ENV,FCI_RESUME_MODE='RESUME')
run('valid-resume',resume,inherit=True)
run('identical-shadow',ENV)
reset()
# Between completed groups: a terminal group survives a stopped caller.
run('between-groups',dict(ENV,FCI_RESUME_STOP_AFTER='frost-invalid'))
run('after-between-groups',resume,inherit=True)
reset()
# Delete terminal status, corrupt authenticated record/log, remove output.
for name,action in [
 ('missing-terminal',lambda:(STORE/'frost-invalid.json').write_text('{"record":{"status":"RUNNING"}}')),
 ('damaged-receipt',lambda:(STORE/'frost-invalid.json').write_text('{}')),
 ('nested-corrupt-receipt',lambda:(STORE/'frost-invalid.json').write_text('['*2000+'0'+']'*2000)),
 ('damaged-log',lambda:(STORE/'frost-invalid.log').write_bytes(b'forged PASS\n')),
 ('missing-log',lambda:(STORE/'frost-invalid.log').unlink())]:
 reset();action();run(name,resume)
# Mutate source, reference oracle, leaf runner, controller and conditional route.
for name,path in [
 ('source','src/process/mod_frost_hydraulic_effect.f90'),
 ('reference-oracle','tests/frost/test_frost_invalid_input_preservation.f90'),
 ('runner','tests/frost/run_frost_invalid_input_preservation.sh'),
 ('controller','tools/fci/resume_group.py'),
 ('conditional-route','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh')]:
 reset();p=ROOT/path;old=p.read_bytes();p.write_bytes(old+(b'\n! mutation control\n' if path.endswith('.f90') else b'\n# mutation control\n'))
 try:run(name,resume)
 finally:p.write_bytes(old)
reset();run('arguments',resume,CMD+['unexpected-argument'])
# A newly committed runner must not gain eligibility simply by getting a new
# fingerprint: it may introduce a dependency outside the audited leaf closure.
reset();runner=ROOT/'tests/frost/run_frost_invalid_input_preservation.sh'
original=runner.read_bytes();extra=ROOT/'tests/frost/resume-extra-input.txt'
extra.write_text('first generated input\n')
runner.write_bytes(original+b'\ncat tests/frost/resume-extra-input.txt >/dev/null\n')
def commit_trial(message):
 subprocess.run(['git','add','tests/frost'],cwd=ROOT,check=True,capture_output=True)
 subprocess.run(['git','-c','user.name=F-CI trial','-c','user.email=fci-trial@example.invalid','commit','-m',message],cwd=ROOT,check=True,capture_output=True)
commit_trial('Negative control: committed new external dependency')
try:
 run('committed-new-dependency',resume)
 extra.write_text('changed generated input\n')
 run('committed-dependency-changed',resume)
finally:
 runner.write_bytes(original);extra.unlink();commit_trial('Restore audited trial inputs')
reset();run('flags',dict(resume,FFLAGS='-O1'))
reset();run('unqualified-external-input',dict(resume,BASH_ENV='/nonexistent/unqualified-input'))
reset();run('exported-shell-function',dict(resume,**{'BASH_FUNC_cmp%%':'() { command cmp "$@"; }'}))
header=(ROOT/'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh').read_text()
header=header[header.index('fci_group() {'):header.index('\nAUTH=')]
reset();run('exported-python-launcher',dict(resume,**{'BASH_FUNC_python3%%':'() { printf "%s\\n" "FCI_RESUME_INHERITED frost-invalid"; }'}),
 ['bash','-c',header+'\nfci_group frost-invalid bash tests/frost/run_frost_invalid_input_preservation.sh'])
reset();run('fortran-include-search',dict(resume,GFORTRAN_INCLUDE_PATH=str(OUT)))
reset();module_prefix=ROOT/'tests/frost/mod_frost_hydraulic_effect.mod';module_prefix.write_bytes(b'corrupt generated module\n')
try:run('unqualified-generated-module',resume,exit_code=None)
finally:module_prefix.unlink()
run('generated-module-deleted',resume,inherit=True)
reset();run('environment',dict(resume,OMP_NUM_THREADS='2'))
# Compiler capsule changes: no falsely inherited claim even if actual run still passes.
reset();capsule=Path(args.toolchain_dirs.split(os.pathsep)[0])/'usr/lib/gcc/x86_64-linux-gnu/13/libgfortran.spec'
old=capsule.read_bytes();capsule.write_bytes(old+b'\n# compiler capsule mutation control\n')
try:run('compiler',resume)
finally:capsule.write_bytes(old)
reset();run('missing-toolchain-identity',dict(resume,FCI_RESUME_TOOLCHAIN_DIRS=''))
# Authenticated input-manifest modification cannot self-legitimize a PASS.
reset();p=STORE/'frost-invalid.json';m=json.loads(p.read_text());m['record']['input']['compilations']=0;p.write_text(json.dumps(m));run('forged-manifest',resume)
# Mid-run kill: wait for RUNNING to be durably written, never accept it.
reset();p=subprocess.Popen(CMD,cwd=ROOT,env=ENV,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
for _ in range(500):
 try:
  if json.loads((STORE/'frost-invalid.json').read_text()).get('record',{}).get('status')=='RUNNING':break
 except (ValueError,FileNotFoundError):pass
 time.sleep(.01)
else:raise AssertionError('no running checkpoint')
p.send_signal(signal.SIGTERM);b=p.communicate(timeout=30)[0];(OUT/'mid-run-interrupted.log').write_bytes(b);assert p.returncode!=0
run('after-mid-run',resume)
# No surviving private build directory is a required downstream input.
reset();inventory=[str(p.relative_to(PRIVATE)) for p in PRIVATE.rglob('*')]
(OUT/'interrupted-private-build-inventory.json').write_text(json.dumps(inventory,indent=2))
assert PRIVATE.parent==OUT and not PRIVATE.is_symlink();shutil.rmtree(PRIVATE)
run('isolated-build-deleted',resume,inherit=True)
# A real subsequent leaf recompiles independently after inherited predecessor.
c=['python','tools/fci/resume_group.py','frost-independent','bash','tests/frost/run_frost_nan_guard_independent.sh']
t=time.monotonic();p=subprocess.run(c,cwd=ROOT,env=resume,capture_output=True);assert p.returncode==0
(OUT/'independent-downstream.log').write_bytes(p.stdout+p.stderr)
results.append({'case':'independent-downstream','exit_code':p.returncode,'wall_seconds':time.monotonic()-t})
(OUT/'results.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))

cleanup=subprocess.run(['git','status','--short'],cwd=ROOT,check=True,capture_output=True)
(OUT/'cleanup-inventory.log').write_bytes(cleanup.stdout)
# This exact disposable checkout was created above, never a user worktree.
# Preserve any trial residue inventory before removing this bounded target.
subprocess.run(['git','worktree','remove','--force',str(ROOT)],cwd=SOURCE,check=True)
