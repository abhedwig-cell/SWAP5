"""Re-execute the sealed small original/corrected-source corpus with $FC."""
from pathlib import Path
import argparse,os,subprocess,sys
sys.dont_write_bytecode=True
from verify import unpack,validate
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
data=unpack();validate(data);inputs=a.output/'inputs';inputs.mkdir()
for n,b in data.items():
 if n.startswith('inputs/'):(inputs/Path(n).name).write_bytes(b)
env=os.environ.copy();env['LEAF_ADMISSION_OUT']=str((a.output/'run').resolve())
subprocess.run([sys.executable,'-B',str(inputs/'run_admission.py')],env=env,check=True)
