"""Run all frozen exact-only tolerance levels; retain failed levels and diagnostics."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
levels = ('1e-10', '1e-8', '1e-6', '1e-5')
rows = []
for tol in levels:
    env = dict(os.environ, A28_H0_CM='-45', A28_DT_DAY='.01',
               A28_RAIN_CM_DAY='1', A28_NONLINEAR_ITERATION_LIMIT='16',
               A28_SOLVER_BALANCE_TOL_CM=tol, PYTHONDONTWRITEBYTECODE='1')
    start = time.perf_counter()
    run = subprocess.run([sys.executable, str(ROOT/'tests/fpe/test_fpe_a28_fd_predictor_init.py')],
                         cwd=ROOT, env=env, capture_output=True, text=True)
    elapsed = time.perf_counter()-start
    log = run.stdout + run.stderr
    (out/(tol+'.log')).write_text(log)
    def parse(line):
        return dict(re.findall(r'(\w+)=\s*([^\s]+)', line))
    trials = [parse(x) for x in log.splitlines() if x.startswith('A28_FD_TRIAL')]
    work = [parse(x) for x in log.splitlines() if x.startswith('A28_FD_WORK')]
    responses = [parse(x) for x in log.splitlines() if x.startswith('A28_FD_RESPONSE')]
    row = dict(tolerance_cm=tol, returncode=run.returncode,
               predictor_pass='EXACT_RFM_FD_PREDICTOR_INIT=PASS' in log,
               elapsed_seconds=elapsed, trials=trials, work=work, responses=responses,
               log_sha256=hashlib.sha256(log.encode()).hexdigest())
    rows.append(row)
    print(json.dumps({k:v for k,v in row.items() if k not in ('trials','work','responses')}), flush=True)
result = dict(source_sha=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              library_sha256=hashlib.sha256(Path(os.environ['FGC45_MULTISWAP_LIB']).read_bytes()).hexdigest(),
              external_mass_gate_cm=1e-12, rows=rows,
              timing_scope='fresh-process predictor qualification including replay; not production timing')
(out/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
