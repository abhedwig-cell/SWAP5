#!/usr/bin/env python3
"""Independent short actual-runtime signed/mixed/GWL activation matrix.

Reuse whole modules freshly built by the two B11 runtime runners. Generated
programs retain their exact helper procedures, replacing only the case matrix
and selected response parameters. Outputs and generated source are retained.
"""
import argparse, hashlib, pathlib, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--opts', nargs='+', type=int, default=[0, 2])
args = parser.parse_args()
for route in ['normal', 'low_air']:
    fixture = ROOT / f'tests/frost/test_ppa_wu05b11_{route}_runtime.f90'
    original = fixture.read_text()
    begin = original.index('  call initialize_parameters(parameters,2)')
    end = original.index('\ncontains\n', begin)
    setup = original[begin:original.index('  do pattern=1,3', begin)]
    if route == 'normal':
        setup += "  case_temperature=1._real64\n  call initialize_soil_temperature_state([1._real64,1._real64,1._real64,1._real64],initial%soil_temperature,status)\n"
    else:
        setup += "  drain_depth=[-3._real64,-4._real64]\n"
    main = setup + '''  do mixture=0,1
  do table_sign=-1,1
  do gwl_index=1,3
    initial%groundwater_level=-real(gwl_index,real64)
    do signum=-1,1,2
      q=real(signum,real64)*.001_real64
      call execute_case(2,0._real64,q,-999999._real64,1.e-8_real64,.false.,.true.,result,observation, &
           frost_case=.true.,initial_physical_state=initial,final_physical_state=final,drain_case=.true.)
      call require(result%committed.and.result%completed,'actual activation matrix commits')
      table_first=real(table_sign,real64)*.01_real64*max(0._real64,min(2._real64,3._real64-abs(initial%groundwater_level)))
      table_second=-table_first/2._real64
      if(mixture==1)table_first=max(0._real64,initial%groundwater_level-control_head(1))/100._real64
      raw_expected=table_first+table_second
      call require(abs(observation%drainage_response%level(1)%signed_soil_to_drain_rate-table_first)<=1.e-14_real64, &
           'independent first generated level from original GWL')
      call require(abs(observation%drainage_response%level(2)%signed_soil_to_drain_rate-table_second)<=1.e-14_real64, &
           'independent second signed table level from original GWL')
      call require(abs(observation%drainage_response%aggregate%signed_soil_to_drain_rate-raw_expected)<=1.e-14_real64, &
           'independent actual raw aggregate')
      call require(abs(observation%frost_drainage%total_rate-raw_expected)<=1.e-14_real64,'surviving final-node aggregate')
      call require(abs(observation%bottom_flux-q)<=1.e-14_real64,'separate qbot retained including zero generated rate')
      call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'hard mass closure')
      call require(abs(result%mass%storage_change-(q-raw_expected)*1.e-8_real64)<=hard_mass_gate, &
           'independent input/storage/final sink single owner')
      call require(abs(observation%drainage_response_window_signed_exchange_native-raw_expected*1.e-8_real64)<=hard_mass_gate, &
           'signed accepted window receipt equals final nodes')
      cases=cases+1
    end do
  end do
  end do
  end do
  print '(A,I0)','PPA_WU05B11_ACTUAL_SIGNED_MIXED_GWL_CASES=',cases
  print '(A)','PPA_WU05B11_ACTIVATION=PASS'
'''
    source = original[:begin] + main + original[end:]
    source = source.replace('  logical::ok\n', '  logical::ok\n  integer::mixture,table_sign,gwl_index,cases=0\n  real(real64)::table_first,table_second\n', 1)
    if route == 'low_air':
        source = source.replace('tabulated%groundwater_depth=[20._real64]', 'tabulated%groundwater_depth=[1._real64,2._real64,3._real64]')
        source = source.replace('tabulated%signed_exchange_rate=[.01_real64]', 'tabulated%signed_exchange_rate=[.02_real64,.01_real64,0._real64]')
        source = source.replace('tabulated%signed_exchange_rate=[-.005_real64]', 'tabulated%signed_exchange_rate=[-.01_real64,-.005_real64,0._real64]')
    marker = '    end do\n  end subroutine\n\n  subroutine initialize_parameters'
    change = '''      parameters%drainage_response_levels(l)%tabulated%signed_exchange_rate= &
           real(table_sign,real64)*parameters%drainage_response_levels(l)%tabulated%signed_exchange_rate
      if(mixture==1.and.l==1)then
        parameters%drainage_response_levels(l)%variant=FMR_DRAIN_VARIANT_LINEAR
        parameters%drainage_response_levels(l)%linear%drainage_resistance=100._real64
        forcing%drainage_response_controls(l)%drain_head_supplied=.true.
        forcing%drainage_response_controls(l)%drain_head=control_head(l)
      end if
    end do
  end subroutine

  subroutine initialize_parameters'''
    assert source.count(marker) == 1
    source = source.replace(marker, change)
    path = pathlib.Path(f'/tmp/frost-b11-{route}-activation.f90')
    path.write_text(source)
    for opt in args.opts:
        build = pathlib.Path(f'/tmp/ppa-wu05b11-{route.replace("_", "-")}-runtime/o{opt}')
        assert (build / 'mod_fmr_serialized_reference_backend.o').exists(), build
        flags = ['-std=f2008', '-ffree-line-length-none', '-w', '-fopenmp', '-fcheck=all', '-fbacktrace',
                 '-ffpe-trap=invalid,zero,overflow', f'-O{opt}', '-J'+str(build), '-I'+str(build)]
        base = pathlib.Path(f'/tmp/frost-b11-{route}-activation-o{opt}')
        subprocess.run(['gfortran', *flags, '-c', str(path), '-o', str(base)+'.o'], check=True)
        objects = sorted(str(p) for p in build.glob('*.o') if p.name != 'test.o')
        subprocess.run(['gfortran', '-fopenmp', f'-O{opt}', *objects, str(base)+'.o', '-o', str(base)], check=True)
        with open(str(base)+'.log', 'w') as out, open(str(base)+'.err', 'w') as err:
            subprocess.run([str(base)], stdout=out, stderr=err, check=True)
        assert 'PPA_WU05B11_ACTIVATION=PASS' in pathlib.Path(str(base)+'.log').read_text()
        print(route, opt, 'PASS', 'generated_sha256', hashlib.sha256(path.read_bytes()).hexdigest(), flush=True)
    if args.opts == [0, 2]:
        assert pathlib.Path(f'/tmp/frost-b11-{route}-activation-o0.log').read_bytes() == pathlib.Path(f'/tmp/frost-b11-{route}-activation-o2.log').read_bytes()
        print(route, 'O0_O2_IDENTITY=PASS', flush=True)
