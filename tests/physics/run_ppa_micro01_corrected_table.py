"""Compare typed table with explicitly corrected literal B1.11 component."""
import ast
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
MEMBER = 'reference/swap-4.3.1/b1_11_frost_source/SWAP/RWU_micro.f90'
PIN = 'cac3d723cc11fb001878d53f2747bbff9fd53fb22949b682906df4361cb90477'
raw = (ROOT / MEMBER).read_bytes()
assert hashlib.sha256(raw).hexdigest() == PIN
start = raw.index(b'subroutine get_MFLP_K (iTask, H, jLayer, M, K)')
end = raw.index(b'end subroutine get_MFLP_K', start) + len(b'end subroutine get_MFLP_K')
original = raw[start:end]
block = original.decode().replace('\r\n', '\n')
patches = [
    ('      start = int(100.d0*dlog10(-wiltpoint))',
     '      M_table=0d0; K_table=0d0\n      start = int(100.d0*dlog10(-wiltpoint))'),
    ('         M_table(start,lay) = 0.0d0',
     '''         K_table(start,lay)=conduc1
         wcontent=watcon(i,wiltpoint)
         conduc2=hconduc(i,wiltpoint,wcontent,10d0)
         K_table(start+1,lay)=conduc2
         M_table(start,lay)=0.5d0*(conduc1+conduc2)*(phead1-wiltpoint)'''),
    ('      else if (H > -1.023293d0) then',
     '''      else if (H <= -10d0**(dble(int(100d0*dlog10(-wiltpoint)))/100d0)) then
         start=int(100d0*dlog10(-wiltpoint))
         phead1=-10d0**(dble(start)/100d0)
         c0=H-wiltpoint
         c1=c0/(phead1-wiltpoint)
         M=K_table(start+1,lay)*c0+0.5d0*(K_table(start,lay)-K_table(start+1,lay))*c0*c1
         if(Kpresent)K=K_table(start+1,lay)+(K_table(start,lay)-K_table(start+1,lay))*c1
      else if (H > -1.023293d0) then'''),
]
for before, after in patches:
    assert block.count(before) == 1
    block = block.replace(before, after)
tree = ast.parse((ROOT / 'tests/physics/run_ppa_micro01_dry_table.py').read_text())
header = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
              and any(isinstance(t, ast.Name) and t.id == 'HEADER' for t in n.targets))
header = header.replace('implicit none\ncontains\nreal(8) function watcon',
                        'implicit none\ninteger :: profile=1\ncontains\nreal(8) function watcon')
header = header.replace('hconduc=1d0', 'hconduc=1d0\nif(profile==2)hconduc=1d0/(1d0+(abs(h)/100d0)**2)')
footer = '''
end module
subroutine swap_error(where,message)
character(*),intent(in)::where,message
print *,where,message
error stop 99
end subroutine
'''
paths = [MEMBER, 'src/process/mod_root_micro_matric_flux_table.f90',
         'tests/physics/test_ppa_micro01_corrected_table.f90',
         'tests/physics/run_ppa_micro01_corrected_table.py',
         'tests/physics/run_ppa_micro01_dry_table.py']
outputs = {}
with tempfile.TemporaryDirectory(prefix='micro01-corrected-') as tmp:
    tmp = pathlib.Path(tmp)
    f = tmp / 'corrected_literal.f90'
    f.write_text(header + block + footer)
    for opt in ('O0', 'O2'):
        subprocess.run(['gfortran', '-' + opt, '-ffree-line-length-none', '-fcheck=all',
                        '-ffpe-trap=invalid,zero,overflow', str(f), str(ROOT / paths[1]),
                        str(ROOT / paths[2]), '-o', str(tmp / opt)], cwd=tmp, check=True)
        execution = subprocess.run([str(tmp / opt)], capture_output=True, text=True)
        print(execution.stdout, end='')
        if execution.returncode:
            print(execution.stderr, end='')
            execution.check_returncode()
        outputs[opt] = execution.stdout
assert outputs['O0'] == outputs['O2']
print('MICRO01_CORRECTED_TABLE_O0_O2_IDENTICAL=PASS')
sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
result = {'schema': 'swap5.micro01.corrected_table.v1', 'tested_postimage': sha,
          'reference_sha256': PIN, 'original_literal_sha256': hashlib.sha256(original).hexdigest(),
          'corrected_literal_sha256': hashlib.sha256(block.encode()).hexdigest(),
          'explicit_reference_patches': patches, 'runs': outputs,
          'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
          'claim_ceiling': 'Typed corrected table component with synthetic hydraulic owners only; '
                           'not complete MICRO uptake or runtime/restart admission.'}
if os.environ.get('C3A_RESULT'):
    pathlib.Path(os.environ['C3A_RESULT']).write_text(json.dumps(result, indent=2) + '\n')
