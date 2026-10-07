#!/usr/bin/env python3
import pathlib,re,subprocess,tempfile,os,shlex
R=pathlib.Path(__file__).resolve().parents[2]
FC=shlex.split(os.environ.get('FC','gfortran'))
component=R/'tests/fmig431/test_swap431_root_lrv_constant.f90'
base=(R/'tests/physics/test_ppa_micro03_runtime.f90').read_text()
base=base.replace(
"  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &\n       fmr_restore_committed_restart, FMR_RESTART_OK\n",
"  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &\n       fmr_restore_committed_restart, FMR_RESTART_OK\n  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK\n  use mod_fmr_micro_constant_lrv_binding, only: fmr_bind_constant_lrv_to_micro_forcing, FMR_MICRO_CONSTANT_LRV_OK\n",1)
base=base.replace("  logical :: ok\n","  logical :: ok\n  type(wofost_rate_table_t) :: lrv_table\n  integer :: lrv_status\n",1)
base=base.replace("  call initialize_parameters(parameters)\n",
"""  call construct_wofost_rate_table([0.0_real64,1.0_real64],[0.5_real64,0.5_real64],lrv_table,lrv_status)
  call require(lrv_status==WOFOST_RATE_TABLE_OK,'constant LRV table')
  call initialize_parameters(parameters)
""",1)
old="""  forcing%root_potential_transpiration=1.0e-4_real64
  forcing%micro_rooted_nodes=2
  allocate(forcing%micro_root_length_density(numnod))
  forcing%micro_root_length_density=[0.5_real64,0.5_real64,0.0_real64,0.0_real64]
"""
new="""  forcing%root_potential_transpiration=1.0e-4_real64
  call fmr_bind_constant_lrv_to_micro_forcing(parameters,lrv_table,2,-20.0_real64,forcing,lrv_status)
  call require(lrv_status==FMR_MICRO_CONSTANT_LRV_OK,'constant LRV production forcing binding')
  call require(all(forcing%micro_root_length_density==[0.5_real64,0.5_real64,0.0_real64,0.0_real64]), &
       'constant LRV production forcing values')
  print '(a)','SW431_ROOT_LRV_CONSTANT_BINDING=PASS'
"""
if old not in base: raise SystemExit('MICRO03 forcing anchor not found')
base=base.replace(old,new,1)

mods={}
extra=[R/'tests/fsi/fsi04_real_headcalc_stubs.f90']
for p in list((R/'src').rglob('*.f90'))+extra:
    for n in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.M|re.I):
        mods[n.lower()]=p
intr={'iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'}

def closure(text_path, generated=None):
    order=[];seen=set();vis=set()
    def visit(p,text=None):
        key=str(p)
        if key in seen:return
        if key in vis:raise RuntimeError('cycle '+key)
        vis.add(key)
        src=text if text is not None else pathlib.Path(p).read_text()
        for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',src,re.M|re.I):
            q=mods.get(n.lower())
            if q is not None: visit(q)
            elif n.lower() not in intr: raise RuntimeError('missing '+n+' from '+key)
        vis.remove(key);seen.add(key);order.append(pathlib.Path(p))
    if generated is None: visit(text_path)
    else:
        for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',generated,re.M|re.I):
            q=mods.get(n.lower())
            if q is not None: visit(q)
            elif n.lower() not in intr: raise RuntimeError('missing '+n+' from generated')
    return order

with tempfile.TemporaryDirectory(prefix='swap431-lrv-') as td:
    td=pathlib.Path(td)
    generated=td/'micro03_lrv.f90'; generated.write_text(base)
    for opt in ('O0','O2'):
        b=td/opt;b.mkdir()
        flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
               '-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
        # component
        objs=[]
        for p in closure(component):
            o=b/(p.stem+'_c.o');subprocess.run(FC+flags+['-c',str(p),'-o',str(o)],check=True);objs.append(str(o))
        co=b/'component.o';subprocess.run(FC+flags+['-c',str(component),'-o',str(co)],check=True);objs.append(str(co))
        exe=b/'component';subprocess.run(FC+flags+objs+['-o',str(exe)],check=True)
        x=subprocess.run([str(exe)],capture_output=True,text=True);print(x.stdout,end='');print(x.stderr,end='')
        if x.returncode or 'SW431_ROOT_LRV_CONSTANT_COMPONENT=PASS' not in x.stdout: raise SystemExit(1)
        # full production MICRO closure
        objs=[]
        order=closure(generated,base)
        # legacy headcalc is an external routine required by backend closure
        hp=R/'src/legacy/b1_10_port/headcalc.f90'
        if hp not in order: order.append(hp)
        for i,p in enumerate(order):
            o=b/(str(i)+'_'+p.stem+'.o');subprocess.run(FC+flags+['-c',str(p),'-o',str(o)],check=True);objs.append(str(o))
        go=b/'micro03_lrv.o';subprocess.run(FC+flags+['-c',str(generated),'-o',str(go)],check=True);objs.append(str(go))
        exe=b/'runtime';subprocess.run(FC+flags+objs+['-o',str(exe)],check=True)
        x=subprocess.run([str(exe)],capture_output=True,text=True);print(x.stdout,end='');print(x.stderr,end='')
        if x.returncode: raise SystemExit(x.returncode)
        for marker in ('SW431_ROOT_LRV_CONSTANT_BINDING=PASS','MICRO03_TRIAL_MASS_RESTART_REJECTION=PASS',
                       'MICRO05_HETEROGENEOUS_APP_TRIAL=PASS','MICRO06_COMMITTED_RESTART_CHANGED_FORCING=PASS'):
            if marker not in x.stdout: raise SystemExit('missing '+marker)
print('SW431_ROOT_LRV_CONSTANT_O0_O2=PASS')
