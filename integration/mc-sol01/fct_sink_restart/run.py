"""Source-bound successor of the actual PR1411 process/crash controller."""
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OLD=HERE.parent/'fct_pulse_restart'
def controller():
 replace=runpy.run_path(str(HERE.parent/'fct_sinks/generate.py'))['replace']
 s=(OLD/'run.py').read_text()
 s=replace(s,"str(HERE/'mod_research_restart_bridge.f90'),",'')
 s=replace(s,"        pulse,_=deps.strict_closure(ROOT,[str(HERE/'pulse_driver.f90')],extra)\n",'')
 s=replace(s,"[('pulse',pulse),('disk',disk)]","[('disk',disk)]")
 s=replace(s,"for category in ['pulse']+([] if a.pulse_only else ['disk']):","for category in ['disk']:")
 s=replace(s,"for n,factor,exponent in itertools.product([40,80],[.8,1.2],[.5,1.,2.]):","for n,factor,exponent,uptake in itertools.product([40,80],[.8,1.2],[.5,1.,2.],[0.,1.]):")
 s=replace(s,"f'case-{n}-{factor}-{exponent}'","f'case-{n}-{factor}-{exponent}-{uptake}'")
 s=replace(s,'context=dict(n=n,factor=factor,exponent=exponent)','context=dict(n=n,factor=factor,exponent=exponent,uptake=uptake)')
 s=replace(s,'exp,mode,payload,dest,stop]','exp,mode,payload,dest,stop,uptake]')
 for name in ['checkpoint.py','disk_body.inc']:
  s=s.replace("HERE/'"+name+"'","HERE.parent/'fct_pulse_restart/"+name+"'")
 s=replace(s,'    def run(cmd,cwd,expected=0):','''    def run(cmd,cwd,expected=0):
        executable=Path(cmd[0])
        if executable.is_relative_to(out) and executable.is_file():executable.chmod(executable.stat().st_mode|0o100)''')
 # Bind all transitive source-generating helpers, including their originals.
 s=replace(s,'    r=dict(status=', '''    inputs.update([HERE/'run.py',HERE/'generate.py',HERE.parent/'fct_sinks/generate.py',
        HERE.parent/'fct_reactive/generate.py',HERE.parent/'fct_reactive/mod_research_composed_fct.f90',
        HERE.parent/'fct_pulse_restart/run.py',HERE.parent/'fct_pulse_restart/mod_research_restart_bridge.f90'])
    r=dict(status=''')
 return s
if __name__=='__main__':
 ns=dict(__file__=__file__,__name__='sink_disk_controller');exec(compile(controller(),__file__,'exec'),ns);ns['main']()
