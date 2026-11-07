"""Exercise surface and Boesten matrix checkpoint readers against real owners."""
import argparse
import json
import os
import subprocess
import struct
import zlib
from pathlib import Path

import matrix_logical_header as header
from native_n_crc_runtime import run

ENTRY = """
  if (index(trim(mode),'surface-')==1) then
    call surface_checkpoint()
    stop
  end if
"""
FIXTURE = """
  subroutine surface_checkpoint()
    use mod_restricted_surface_evaporation, only: boesten_evaporation_state_t
    type(boesten_evaporation_state_t) :: pair
    type(mobile_salt_state_t) :: mobile
    type(solute_compartment_state_t) :: stores
    real(real64), allocatable :: theta(:)
    real(real64) :: clock
    integer(int64) :: revision, parameter_id
    logical :: boesten
    boesten=trim(exponent_argument)=='3'
    cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    if (boesten) cfg%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION
    if (trim(mode)=='surface-write') then
      if (boesten) then
        pair%spev=2d0
        pair%saev=.5d0
        call fmr_new_b110_boesten_evaporation_committed_state(water,column%column_id, &
          cfg%tiles(1)%initial_state,pair,T0,ok)
      else
        call fmr_new_b110_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,T0,ok)
      end if
      call require(ok,'surface water owner')
      call initialize_matrix_solute(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
        spread(.2d0,1,numnod),solute,status)
      call require(status==0,'surface chemical owner')
      call solute%snapshot(clock,theta,mobile,stores,revision)
      call reconstruct_matrix_solute_trusted(p,9001_int64,revision,clock,theta, &
        mobile%concentration_mg_cm3,mobile%mass_mg_cm2,stores%sorbed_matrix_mass, &
        solute,status,surface_mass=.25d0)
      call require(status==MATRIX_OK,'positive surface solute store')
    else
      call observe_header()
      parameter_id=9001_int64
      if (trim(mode)=='surface-wrong-owner') parameter_id=9002_int64
      call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template, &
        670001_int64,parameter_id,p,water,solute,status, &
        allow_surface_mass=trim(mode)/='surface-disabled')
      if (status/=JOINT_OK) then
        call require(.not.water%ready().and..not.solute%ready(),'both targets empty')
        print '(A)','SURFACE_REFUSED_EMPTY'
        return
      end if
      call require(water%ready().and.solute%ready(),'both targets restored')
      print '(A)','SURFACE_ACCEPTED'
      if (trim(mode)=='surface-probe') return
      call solute%snapshot(clock,theta,mobile,stores,revision)
      call require(stores%pond_mass==.25d0,'positive surface store restored exactly')
      call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template, &
        670001_int64,9001_int64,p,water,solute,status,allow_surface_mass=.true.)
      call require(status/=JOINT_OK.and.water%ready().and.solute%ready(),'occupied owners preserved')
      print '(A)','SURFACE_OCCUPIED_REFUSED'
    end if
    call write_matrix_joint_restart_file(trim(endpoint_path),column,cfg%tiles(1)%template, &
      670001_int64,water,solute,status,allow_surface_mass=.true.)
    call require(status==JOINT_OK,'surface checkpoint written')
  end subroutine
"""


def project(raw):
    source = header.projection(raw).decode()
    source = source.replace("  call backend%initialize(top);", ENTRY + "  call backend%initialize(top);", 1)
    source = source.replace("\ncontains\n", "\ncontains\n" + FIXTURE, 1)
    source = source.replace("if(len_trim(exponent_argument)>0)read", "if(index(trim(mode),'surface-')/=1.and.len_trim(exponent_argument)>0)read")
    source = source.replace("tag=='S5MJ0001'", "(tag=='S5MJ0002'.or.tag=='S5MJ0003')")
    return source.replace("merge(0,1,trim(mode)=='header-base')", "merge(2,0,trim(exponent_argument)=='3')").encode()


def execute(native, output, compiler):
    files, digest = header.source_files(native)
    output.mkdir(parents=True)
    for name, data in files.items():
        path = Path(name)
        assert not path.is_absolute() and '..' not in path.parts
        if name.startswith('fixture/') or path.suffix in ('.o', '.mod', '.smod'):
            target = output / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    result = json.loads(files['RESULT.json'])
    assert result['platform'] == ('WINDOWS' if os.name == 'nt' else 'POSIX')
    assert subprocess.check_output([compiler, '--version'], text=True).splitlines()[0] == result['compiler']
    events = []
    outcomes = {}
    for role in ('incumbent', 'candidate'):
        build = json.loads(files[role + '/BUILD.json'])
        path_type = header.PureWindowsPath if result['platform'] == 'WINDOWS' else header.PurePosixPath
        root = path_type(build['bindings'][0]['object']).parent.parent
        objects = [output / path_type(item['object']).relative_to(root).as_posix() for item in build['bindings']]
        objects.append(output / role / 'publisher.o')
        source = output / role / 'surface.f90'
        source.write_bytes(project(files[role + '/' + build['drivers']['joint']['source']]))
        flags = [flag for flag in build['flags'] if not flag.startswith(('-I', '-J'))]
        flags.extend('-I' + str(output / directory) for directory in (role, 'fixture', 'incumbent'))
        executable = output / role / 'surface.exe'
        response = output / role / 'surface.args'
        args = flags + [str(source), *map(str, objects), '-o', str(executable)]
        response.write_text('\n'.join('"' + arg.replace('\\', '/') + '"' for arg in args))
        run([compiler, '@' + str(response)], output, events, role + '-link')
        outcomes[role] = {}
        for tag in ('2', '3'):
            original = output / role / ('original-' + tag)
            run([executable, 'surface-write', 'unused', original, tag], output, events, role + '-write')
            raw = original.read_bytes()
            assert raw[:8] == ('S5MJ000' + tag).encode()
            assert zlib.crc32(raw[:-4]) == struct.unpack('<I', raw[-4:])[0]
            restored = output / role / ('restored-' + tag)
            observed = run([executable, 'surface-read', original, restored, tag], output, events, role + '-read')
            assert b'SURFACE_ACCEPTED' in observed.stdout and restored.read_bytes() == raw
            assert b'MATRIX_LOGICAL_FIELD_OFFSETS=144 148 152 156' in observed.stdout
            assert b'SURFACE_OCCUPIED_REFUSED' in observed.stdout
            for refused_mode in ('surface-disabled', 'surface-wrong-owner'):
                observed = run([executable, refused_mode, original, restored, tag],
                               output, events, role + '-' + refused_mode)
                assert b'SURFACE_REFUSED_EMPTY' in observed.stdout
                assert restored.read_bytes() == raw
            admissions = []
            for offset in (144, 156):
                for value in (2, -1, 256):
                    body = bytearray(raw[:-4])
                    struct.pack_into('<i', body, offset, value)
                    path = output / role / f'malformed-{tag}-{offset}-{value}'
                    path.write_bytes(body + struct.pack('<I', zlib.crc32(body)))
                    observed = run([executable, 'surface-probe', path, restored, tag], output, events, role + '-malformed')
                    accepted = b'SURFACE_ACCEPTED' in observed.stdout
                    assert accepted != (b'SURFACE_REFUSED_EMPTY' in observed.stdout)
                    if accepted:
                        admissions.append([offset, value])
            outcomes[role][tag] = admissions
    for tag in ('2', '3'):
        assert (output / 'incumbent' / ('original-' + tag)).read_bytes() == (output / 'candidate' / ('original-' + tag)).read_bytes()
    (output / 'SURFACE_RESULT.json').write_text(json.dumps({
        'native_archive_sha256': digest, 'platform': result['platform'], 'optimization': result['optimization'],
        'admitted_malformed': outcomes, 'surface_mass': 0.25, 'production_admission': False
    }, indent=2) + '\n')
    assert not any(outcomes['candidate'].values()), outcomes
    print(outcomes)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('native', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('compiler')
    arguments = parser.parse_args()
    execute(arguments.native.resolve(), arguments.output.resolve(), arguments.compiler)
