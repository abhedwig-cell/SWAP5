"""Build explicit RFM bridge with bounds checks and test-only sorptivity telemetry."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
subprocess.run(['git','rev-parse','HEAD'],cwd=root,check=True)
base=(root/'tests/fpm/run_ppa_wu05a26_backend_compile.sh').read_text().split('MODULE_SRC=(')[1].split('\n)')[0].split()
extra=[
'src/runtime/mod_groundwater_coupling_contract.f90',
'src/runtime/mod_groundwater_swap_forcing_adapter.f90',
'src/runtime/mod_groundwater_swap_transaction_participant.f90',
'src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90',
'src/runtime/mod_fmr_groundwater_swap_participant.f90',
'src/runtime/mod_groundwater_interface_mass_ledger.f90',
'src/runtime/mod_groundwater_tile_aggregation.f90',
'src/runtime/mod_groundwater_multiswap_types.f90',
'src/runtime/mod_modflow6_swap_predictor_response.f90',
'src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90',
'src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90',
'src/runtime/mod_modflow6_swap_predictor_origin.f90',
'src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90',
'src/runtime/mod_modflow6_multiswap_cell_response.f90',
'src/runtime/mod_modflow6_linear_response_backend.f90',
'src/runtime/mod_modflow6_api_binding.f90',
'src/adapter/mod_modflow6_fgc34_c_bridge.f90',
 'tests/fpe/support/mod_fpe_a28_fgc45_rfm_bridge.f90']
sources=subprocess.check_output(['python3','tests/support/augment_bartholomeus_backend_sources.py',*(base+extra)],cwd=root,text=True).split()
# Bounded test-only instrumentation: only successful quadrature loops count.
source=root/'src/process/macropore/mod_rfm_surface_sorptivity.f90'
s=source.read_text().replace('  implicit none','  use, intrinsic :: iso_c_binding, only: c_int, c_double\n  implicit none',1)
s=s.replace('contains\n','''  integer,save::eval_counts(3)=0,panels_evaluated=0
  real(real64),save::head_min=huge(0._real64),head_max=-huge(0._real64),eval_seconds=0
contains
  subroutine a28_sorptivity_stats_c(counts,npanels,hmin,hmax,seconds) bind(C,name="a28_sorptivity_stats_c")
    integer(c_int),intent(out)::counts(3),npanels
    real(c_double),intent(out)::hmin,hmax,seconds
    counts=eval_counts;npanels=panels_evaluated;hmin=head_min;hmax=head_max;seconds=eval_seconds
  end subroutine
  subroutine a28_sorptivity_stats_reset_c() bind(C,name="a28_sorptivity_stats_reset_c")
    eval_counts=0;panels_evaluated=0;head_min=huge(0._real64);head_max=-huge(0._real64);eval_seconds=0
  end subroutine
  subroutine record_eval(panels,head)
    integer,intent(in)::panels
    real(real64),intent(in)::head
    integer::idx
    select case(panels)
    case(64);idx=1
    case(32);idx=2
    case(16);idx=3
    case default;error stop 'unexpected sorptivity panels'
    end select
    eval_counts(idx)=eval_counts(idx)+1;panels_evaluated=panels_evaluated+panels
    head_min=min(head_min,head);head_max=max(head_max,head)
  end subroutine
''',1)
assert s.count('real(real64) :: h_initial')==2
s=s.replace('real(real64) :: h_initial','real(real64) :: clock0,clock1\n    real(real64) :: h_initial')
assert s.count('    do i=1,panels')==2
s=s.replace('    do i=1,panels','    call cpu_time(clock0)\n    call record_eval(panels,h_initial)\n    do i=1,panels')
assert s.count('    sorptivity = sqrt')==1 and s.count('    sorptivity=sqrt')==1
for anchor in ['    sorptivity = sqrt','    sorptivity=sqrt']:
 s=s.replace(anchor,'    call cpu_time(clock1)\n    eval_seconds=eval_seconds+clock1-clock0\n'+anchor,1)
instrumented=out/source.name;instrumented.write_text(s)
objs=[]
for name in sources:
 src=instrumented if name==str(source.relative_to(root)) else root/name
 obj=out/(src.stem+'.o')
 subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-fPIC','-fopenmp','-fcheck=all','-fbacktrace','-O2','-J',str(out),'-I',str(out),'-c',str(src),'-o',str(obj)],check=True)
 objs.append(str(obj))
subprocess.run(['gfortran','-shared','-fopenmp',*objs,'-o',str(out/'libfgc45_multiswap.so')],check=True)
print('A28_BUILD=PASS')
