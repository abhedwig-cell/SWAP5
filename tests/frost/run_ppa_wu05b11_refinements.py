#!/usr/bin/env python3
"""Additional O0 reference refinement for selected B11 trajectories."""
import pathlib, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
for route, counts in [('normal', [16384, 32768]), ('low_air', [131072])]:
    original = (ROOT / f'tests/frost/test_ppa_wu05b11_{route}_runtime.f90').read_text()
    for count in counts:
        source = original.replace('8192' if route == 'normal' else '65536', str(count))
        source = source.replace('do pattern=1,3', 'do pattern=1,2' if route == 'normal' else 'do pattern=1,1')
        source = source.replace('do signum=-1,1,2', 'do signum=-1,-1,2')
        begin = source.index('  columns(1)%column_id')
        end = source.index('\ncontains\n', begin)
        source = source[:begin] + "  print '(A)','PPA_WU05B11_ADDITIONAL_REFINEMENT=PASS'\n" + source[end:]
        path = pathlib.Path(f'/tmp/frost-b11-{route}-refinement-{count}.f90')
        path.write_text(source)
        build = pathlib.Path(f'/tmp/ppa-wu05b11-{route.replace("_", "-")}-runtime/o0')
        assert (build / 'mod_fmr_serialized_reference_backend.o').exists()
        flags = ['-std=f2008', '-ffree-line-length-none', '-w', '-fopenmp', '-fcheck=all', '-fbacktrace',
                 '-ffpe-trap=invalid,zero,overflow', '-O0', '-J'+str(build), '-I'+str(build)]
        base = pathlib.Path(f'/tmp/frost-b11-{route}-refinement-{count}')
        subprocess.run(['gfortran', *flags, '-c', str(path), '-o', str(base)+'.o'], check=True)
        objects = sorted(str(p) for p in build.glob('*.o') if p.name != 'test.o')
        subprocess.run(['gfortran', '-fopenmp', '-O0', *objects, str(base)+'.o', '-o', str(base)], check=True)
        with open(str(base)+'.log', 'w') as out, open(str(base)+'.err', 'w') as err:
            subprocess.run([str(base)], stdout=out, stderr=err, check=True)
        assert 'PPA_WU05B11_ADDITIONAL_REFINEMENT=PASS' in pathlib.Path(str(base)+'.log').read_text()
        print(route, count, 'PASS', flush=True)
