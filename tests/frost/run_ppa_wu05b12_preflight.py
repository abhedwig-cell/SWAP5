#!/usr/bin/env python3
"""All-family actual application admission/rejection on fresh B12 whole modules."""
import argparse,os,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--routes',nargs='+',default=['normal','low_air']);p.add_argument('--opts',nargs='+',type=int,default=[0,2]);args=p.parse_args()
for route in args.routes:
 original=(ROOT/f'tests/frost/test_ppa_wu05b12_{route}_runtime.f90').read_text()
 a=original.index('  do analytic_family=1,5');b=original.index('\ncontains\n',a)
 main='''  control_head=[-3._real64,-4._real64];case_temperature=-1._real64
  do analytic_family=1,5
  call initialize_parameters(parameters,2)
  call enable_bounded_frost(parameters)
  call initialize_physical_state(parameters,.true.,initial,1._real64)
  call initialize_soil_temperature_state([-4._real64,-4._real64,-1._real64,1._real64],initial%soil_temperature,status)
  columns(1)%column_id=column_id;columns(1)%template_id=440001_int64
  templates(1)%template_id=440001_int64;templates(1)%physics_topology_id=440002_int64
  templates(1)%vertical_layout_id=440003_int64;templates(1)%state_layout_id=440004_int64
  templates(1)%solver_interface_id=440005_int64
  templates(1)%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  templates(1)%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
'''
 if route=='low_air':
  main=main.replace(';case_temperature=-1._real64','')
  main+='  drain_depth=[-3._real64,-4._real64];initial%groundwater_level=-.25_real64\n'
 main+="  call verify_application(initial)\n  end do\n  print '(A)','PPA_WU05B12_ALL_FAMILY_APPLICATION_PREFLIGHT=PASS'\n"
 s=original[:a]+main+original[b:]
 s=s.replace('    integer::status\n','    integer::status,invalid_kind\n',1)
 extra='''    do invalid_kind=1,4
    bad=cfg
    select case(analytic_family)
    case(1)
      select case(invalid_kind)
      case(1);bad%tiles(1)%parameters%drainage_response_levels(1)%hooghoudt_ipos1%shape_factor=0._real64
      case(2);bad%tiles(1)%parameters%drainage_response_levels(1)%hooghoudt_ipos1%drain_spacing=-1._real64
      case(3);bad%tiles(1)%parameters%drainage_response_levels(1)%hooghoudt_ipos1%entry_resistance=-1._real64
      case(4);bad%tiles(1)%parameters%drainage_response_levels(1)%hooghoudt_ipos1%drain_bottom_level=ieee_value(0._real64,ieee_quiet_nan)
      end select
    case(2,3)
      select case(invalid_kind)
      case(1);bad%tiles(1)%parameters%drainage_response_levels(1)%hooghoudt_prepared%is_valid=.false.
      case(2);bad%tiles(1)%parameters%drainage_response_levels(1)%hooghoudt_prepared%equivalent_depth=-1._real64
      case(3)
        bad%tiles(1)%parameters%drainage_response_levels(1)%hooghoudt_ipos2%shape_factor=0._real64
        bad%tiles(1)%parameters%drainage_response_levels(1)%hooghoudt_ipos3%shape_factor=0._real64
      case(4);bad%tiles(1)%parameters%drainage_response_levels(1)%hooghoudt_prepared%drain_bottom_level=ieee_value(0._real64,ieee_quiet_nan)
      end select
    case(4)
      select case(invalid_kind)
      case(1);bad%tiles(1)%parameters%drainage_response_levels(1)%ernst_ipos4_prepared%is_valid=.false.
      case(2);bad%tiles(1)%parameters%drainage_response_levels(1)%ernst_ipos4_prepared%vertical_conductivity_top=0._real64
      case(3);bad%tiles(1)%parameters%drainage_response_levels(1)%ernst_ipos4_prepared%shape_factor=0._real64
      case(4);bad%tiles(1)%parameters%drainage_response_levels(1)%ernst_ipos4_prepared%drain_bottom_level=ieee_value(0._real64,ieee_quiet_nan)
      end select
    case(5)
      select case(invalid_kind)
      case(1);bad%tiles(1)%parameters%drainage_response_levels(1)%ernst_ipos5_prepared%is_valid=.false.
      case(2);bad%tiles(1)%parameters%drainage_response_levels(1)%ernst_ipos5_prepared%vertical_conductivity_top=0._real64
      case(3);bad%tiles(1)%parameters%drainage_response_levels(1)%ernst_ipos5_prepared%shape_factor=0._real64
      case(4);bad%tiles(1)%parameters%drainage_response_levels(1)%ernst_ipos5_prepared%drain_bottom_level=ieee_value(0._real64,ieee_quiet_nan)
      end select
    end select
    call rejected%initialize(bad,status)
    call require(status/=FMR_APP_BOOT_OK,'invalid selected analytic member rejected before solver')
    end do
'''
 marker="    print '(A)','PPA_WU05B12_";a=s.index(marker,s.index('  subroutine verify_application'))
 s=s[:a]+extra+s[a:]
 source=pathlib.Path(f'/tmp/frost-b12-{route}-preflight.f90');source.write_text(s)
 outputs=[]
 for opt in args.opts:
  build=pathlib.Path(os.environ.get('B12_LOW_AIR_BUILD','/tmp/ppa-wu05b12-low-air-runtime') if route=='low_air' else '/tmp/ppa-wu05b12-normal-runtime')/f'o{opt}'
  assert (build/'mod_fmr_production_application_bootstrap.o').exists()
  flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(build),'-I'+str(build)]
  base=pathlib.Path(f'/tmp/frost-b12-{route}-preflight-o{opt}')
  subprocess.run(['gfortran',*flags,'-c',str(source),'-o',str(base)+'.o'],check=True)
  objects=sorted(str(p)for p in build.glob('*.o')if p.name!='test.o')
  subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(base)+'.o','-o',str(base)],check=True)
  with open(str(base)+'.log','w')as out,open(str(base)+'.err','w')as err:subprocess.run([str(base)],stdout=out,stderr=err,check=True)
  outputs.append(pathlib.Path(str(base)+'.log').read_bytes());print(route,opt,'PREFLIGHT_PASS',flush=True)
 if len(outputs)==2:assert outputs[0]==outputs[1];print(route,'PREFLIGHT_O0_O2_IDENTITY=PASS',flush=True)
