"""Private explicit separate-operation compilation with complete call journal.

Only the selected diagnostic child process is changed. This is not a supported
provider/profile contract and must not rebind any pre-existing checkpoint.
"""
import json,os,runpy,subprocess,sys
from pathlib import Path
original_run=subprocess.run
def compile_without_contraction(command,*args,**kwargs):
    if isinstance(command,(list,tuple)) and Path(str(command[0])).name.lower() in ('gfortran','gfortran.exe'):
        if any(str(v).lower().endswith(('.f90','.for','.f')) for v in command[1:]):
            flags=['-ffp-contract=off']
            if os.environ.get('SWAP5_PRIVATE_FP_COMMON_ISA')=='1':
                flags+=['-march=x86-64','-mtune=generic']
            command=[*command,*flags]
            with Path(os.environ['SWAP5_PRIVATE_FP_JOURNAL']).open('a',encoding='utf-8') as stream:
                stream.write(json.dumps(dict(command=list(map(str,command)),cwd=str(kwargs.get('cwd',Path.cwd()))))+'\n')
    return original_run(command,*args,**kwargs)
subprocess.run=compile_without_contraction
script=sys.argv[1];sys.argv=sys.argv[1:]
runpy.run_path(script,run_name='__main__')
