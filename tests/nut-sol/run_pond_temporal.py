#!/usr/bin/env python3
"""Small real production temporal-comparison contract, O0/O2 with traps."""
import hashlib,json,os,pathlib,shlex,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=pathlib.Path(os.environ['POND_TEMPORAL_RESULT_DIR']).resolve();OUT.mkdir(parents=True,exist_ok=False)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[]
providers=['src/process/mod_pond_water_temporal_difference.f90','tests/nut-sol/test_pond_water_temporal_difference.f90']
for opt in ('O0','O2'):
    b=OUT/opt;b.mkdir()
    flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
    commands=[FC+flags+['-c',ROOT/providers[0],'-o',b/'provider.o'],FC+flags+[ROOT/providers[1],b/'provider.o','-o',b/'test'],[b/'test']]
    for command in commands:
        command=list(map(str,command));t=time.perf_counter();p=subprocess.run(command,cwd=b,capture_output=True);i=len(events)
        (OUT/f'{i}.stdout').write_bytes(p.stdout);(OUT/f'{i}.stderr').write_bytes(p.stderr)
        events.append(dict(command=command,seconds=time.perf_counter()-t,returncode=p.returncode,stdout=f'{i}.stdout',stderr=f'{i}.stderr'))
        (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n');p.check_returncode()
    assert b'POND_WATER_TEMPORAL_23_COMPARISONS=PASS'in p.stdout
(OUT/'result.json').write_text(json.dumps(dict(status='LEAF_PASS_NOT_RUNTIME_ADMISSION',cases_per_opt=23,
    input_sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in providers+[str(pathlib.Path(__file__).relative_to(ROOT))]},
    compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0]),indent=2)+'\n')
print('POND_TEMPORAL_O0_O2_23=PASS')
