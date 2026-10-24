"""Execute all original HIST assertions with the current N partition providers."""
from pathlib import Path
import argparse,os,resource,runpy
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--literal',type=Path,required=True);a=p.parse_args()
os.environ['REPRODUCTIVE_PROCESS_RESULT_DIR']=str(a.literal.resolve())
path=ROOT/'tests/nut-crop/run_reproductive_process.py';text=path.read_text()
# Exact owning oracle construction, stopping before its independent native suite.
exec(compile(text[:text.index("for opt in ('O0','O2'):")],str(path),'exec'),{'__file__':str(path)})
os.environ['N_HIST_RESULT_DIR']=str(a.output.resolve());os.environ['REPRODUCTIVE_LITERAL_FILE']=str(a.literal.resolve()/'literal.f90')
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
import sys
sys.path.insert(0,str(ROOT/'tests/nut-crop'))
runpy.run_path(str(ROOT/'tests/nut-crop/run_hist_complete.py'),run_name='__main__')
