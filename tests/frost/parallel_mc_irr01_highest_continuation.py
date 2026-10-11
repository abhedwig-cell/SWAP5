#!/usr/bin/env python3
"""Continue the running sealed low-air runner without repeating scientific cases.

The original runner still compiles, checks every case and compares O0/O2.
Only its executable launch is cached per case under a process lock. Cases
already launched before installation continue untouched. Other cases run in
fresh concurrent processes using the identical linked executable.
"""
import concurrent.futures, hashlib, json, os, pathlib, shutil, subprocess, time

ROOT = pathlib.Path(__file__).resolve().parents[2]
BUILD = pathlib.Path('/tmp/ppa-wu05b15-low-air-runtime-managed-weather-current')
subprocess.run(['python3', str(ROOT/'tests/frost/run_mc_irr01_managed_weather_highest_successor.py'),
                '--verify-source-only'], check=True)

WRAPPER = '''#!/usr/bin/env python3
import fcntl,json,os,pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parent
case=int(sys.argv[1]);assert 1<=case<=6
cache=root/'parallel-cache';cache.mkdir(exist_ok=True)
with (cache/(str(case)+'.lock')).open('w')as lock:
 fcntl.flock(lock,fcntl.LOCK_EX)
 done=cache/(str(case)+'.json');out=cache/(str(case)+'.txt');err=cache/(str(case)+'.err')
 if not done.exists():
  with out.open('wb')as so,err.open('wb')as se:
   result=subprocess.run([str(root/'test-scientific'),str(case)],stdout=so,stderr=se,
      env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
  done.write_text(json.dumps({'returncode':result.returncode}))
 sys.stdout.buffer.write(out.read_bytes());sys.stderr.buffer.write(err.read_bytes())
 sys.exit(json.loads(done.read_text())['returncode'])
'''

def wait_for(predicate):
    while not predicate():
        time.sleep(.2)

for opt in [0, 2]:
    out = BUILD/f'o{opt}'
    binary = out/'test'
    # A first scientific child must already have started. O2 compilation and
    # the running O0 child remain owned by the original coordinator.
    wait_for(lambda: binary.exists() and (out/'configuration-1.txt').exists()
             and (out/'configuration-1.txt').stat().st_size > 0)
    assert not (out/'test-scientific').exists(), 'one continuation installation only'
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    replacement = out/'test-parallel-launch'
    replacement.write_text(WRAPPER)
    replacement.chmod(0o755)
    shutil.copy2(binary, out/'test-scientific')
    assert hashlib.sha256((out/'test-scientific').read_bytes()).hexdigest() == digest
    replacement.replace(binary)
    # The serial runner opens its result file before launching the child.
    # Existing files therefore identify completed/running original launches.
    held = [c for c in range(1, 7) if (out/f'configuration-{c}.txt').exists()]
    pending = [c for c in range(1, 7) if c not in held]
    receipt = {'opt': opt, 'scientific_executable_sha256': digest,
               'original_launched_cases': held, 'parallel_pending_cases': pending,
               'wrapper_sha256': hashlib.sha256(WRAPPER.encode()).hexdigest(),
               'science_changes': False, 'duplicate_scientific_launches': False}
    (out/'parallel-continuation.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print('MC_IRR01_HIGHEST_PARALLEL_CONTINUATION='+json.dumps(receipt), flush=True)
    def launch(case):
        with open(os.devnull, 'wb') as null:
            subprocess.run([str(binary), str(case)], stdout=null, stderr=null, check=True)
        print(f'MC_IRR01_LOW_AIR_O{opt}_PARALLEL_CASE_{case}=PASS', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        list(pool.map(launch, pending))
    # The original serial loop consumes the immutable outputs and performs
    # its unchanged per-case checks before it starts the next compiler pass.
    wait_for(lambda: (out/'output.txt').exists())
print('MC_IRR01_HIGHEST_PARALLEL_CONTINUATION=PASS', flush=True)
