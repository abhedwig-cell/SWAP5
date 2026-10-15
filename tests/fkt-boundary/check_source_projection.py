"""Bounded source-preservation check, not a Fortran compiler or physics test."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[2]
PATH='src/kernel/mod_kernel_transactions.f90'
BASE='47b652248420ba7c49df7e063c64ff749ce6253f'
baseline=subprocess.check_output(['git','show',BASE+':'+PATH],cwd=ROOT)
current=(ROOT/PATH).read_bytes()
projected=current
for kind in ['DECLARATIONS','IMPLEMENTATION']:
    pattern=rb'  ! FKT_BOUNDARY_DRAFT_'+kind.encode()+rb'_BEGIN\n.*?  ! FKT_BOUNDARY_DRAFT_'+kind.encode()+rb'_END\n\n'
    projected,n=re.subn(pattern,b'',projected,flags=re.S)
    if n!=1:raise ValueError('missing/duplicate draft addition '+kind)
if projected!=baseline:raise ValueError('incumbent kernel source changed')
print(json.dumps(dict(status='SOURCE_PROJECTION_PASS_ONLY',baseline=BASE,path=PATH,
    baseline_sha256=hashlib.sha256(baseline).hexdigest(),
    postimage_sha256=hashlib.sha256(current).hexdigest(),
    compiler_checked=False,native_checked=False,canonical_admission=False),indent=2))
