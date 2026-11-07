"""Exercise surface and Boesten matrix checkpoint readers against real owners."""
import argparse
import json
import os
import subprocess
import struct
import zlib
from pathlib import Path

import matrix_logical_header as header
import matrix_logical_publication as publication
import pond_thermal_writer as fault_support
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
    use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
    type(boesten_evaporation_state_t) :: pair
    type(mobile_salt_state_t) :: mobile
    type(solute_compartment_state_t) :: stores
    real(real64), allocatable :: theta(:)
    real(real64) :: clock
    integer(int64) :: revision, parameter_id
    logical :: boesten, surface_enabled, temporal
    boesten=trim(exponent_argument)=='3'
    temporal=trim(exponent_argument)=='1t'
    surface_enabled=exponent_argument(1:1)/='1'
    cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    if (temporal) &
      cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    if (boesten) cfg%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION
    if (index(trim(mode),'surface-write')==1) then
      if (boesten) then
        pair%spev=2d0
        pair%saev=.5d0
        call fmr_new_b110_boesten_evaporation_committed_state(water,column%column_id, &
          cfg%tiles(1)%initial_state,pair,T0,ok)
      else if (temporal) then
        call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id, &
          cfg%tiles(1)%initial_state,T0,ok,spread(0d0,1,numnod))
      else
        call fmr_new_b110_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,T0,ok)
      end if
      call require(ok,'surface water owner')
      call initialize_matrix_solute(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
        spread(merge(.3d0,.2d0,trim(mode)=='surface-write-previous'),1,numnod),solute,status)
      call require(status==0,'surface chemical owner')
      if (surface_enabled) then
        call solute%snapshot(clock,theta,mobile,stores,revision)
        call reconstruct_matrix_solute_trusted(p,9001_int64,revision,clock,theta, &
        mobile%concentration_mg_cm3,mobile%mass_mg_cm2,stores%sorbed_matrix_mass, &
        solute,status,surface_mass=.25d0)
        call require(status==MATRIX_OK,'positive surface solute store')
      end if
    else
      call observe_header()
      parameter_id=9001_int64
      if (trim(mode)=='surface-wrong-owner') parameter_id=9002_int64
      call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template, &
        670001_int64,parameter_id,p,water,solute,status, &
        allow_surface_mass=surface_enabled.and.trim(mode)/='surface-disabled')
      if (status/=JOINT_OK) then
        call require(.not.water%ready().and..not.solute%ready(),'both targets empty')
        print '(A)','SURFACE_REFUSED_EMPTY'
        return
      end if
      call require(water%ready().and.solute%ready(),'both targets restored')
      print '(A)','SURFACE_ACCEPTED'
      if (trim(mode)=='surface-probe') return
      call solute%snapshot(clock,theta,mobile,stores,revision)
      call require(stores%pond_mass==merge(.25d0,0d0,surface_enabled),'surface store restored exactly')
      call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template, &
        670001_int64,9001_int64,p,water,solute,status,allow_surface_mass=surface_enabled)
      call require(status/=JOINT_OK.and.water%ready().and.solute%ready(),'occupied owners preserved')
      print '(A)','SURFACE_OCCUPIED_REFUSED'
    end if
    if (trim(mode)=='surface-write-advance'.or.trim(mode)=='surface-read-advance') then
      call require(.not.surface_enabled,'matrix continuation fixture')
      if (.not.temporal) then
        cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
        cfg%numerical%transaction%temporal_tolerance=1d-6
      end if
      call backend%initialize(top)
      call run_matrix_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
        cfg%tiles(1)%base_forcing,cfg%numerical,solute,T0,T1,result)
      call require(result%status==JOINT_OK,'accepted physical continuation')
      call require(abs(result%chemical%residual)<1d-11,'continued chemical balance')
      call require(abs(result%water%mass%residual)<HARD_MASS_GATE,'continued water balance')
      print '(A)','MATRIX_CONTINUATION_PASS'
    end if
    call write_matrix_joint_restart_file(trim(endpoint_path),column,cfg%tiles(1)%template, &
      670001_int64,water,solute,status,allow_surface_mass=surface_enabled)
    if (trim(mode)=='surface-write-refuse') then
      call require(status/=JOINT_OK,'publication must fail closed')
      print '(A)','SURFACE_PUBLICATION_REFUSED'
    else
      call require(status==JOINT_OK,'surface checkpoint written')
    end if
  end subroutine
"""


def project(raw):
    source = header.projection(raw).decode()
    source = source.replace("  call backend%initialize(top);", ENTRY + "  call backend%initialize(top);", 1)
    source = source.replace("\ncontains\n", "\ncontains\n" + FIXTURE, 1)
    source = source.replace("if(len_trim(exponent_argument)>0)read", "if(index(trim(mode),'surface-')/=1.and.len_trim(exponent_argument)>0)read")
    source = source.replace("tag=='S5MJ0001'", "tag==('S5MJ000'//exponent_argument(1:1))")
    return source.replace("merge(0,1,trim(mode)=='header-base')", "merge(2,merge(1,0,trim(exponent_argument)=='1t'),trim(exponent_argument)=='3')").encode()


def execute(native, output, compiler, qualify_publication=False):
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
    publication_faults = []
    publication_terminations = []
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
        if qualify_publication and role == 'candidate':
            runtime = header.g
            original = runtime.raw(runtime.guard()['baseline'], runtime.SOURCE)
            writer = output / role / 'matrix_publication.f90'
            writer.write_bytes(publication.postimage(runtime.postimage(original)))
            replacement = output / role / 'matrix_publication.o'
            run([compiler, *flags, '-J' + str(output / role), '-c', writer,
                 '-o', replacement], output, events, 'publication-compile')
            indices = [i for i, binding in enumerate(build['bindings'])
                       if binding['original'].replace(chr(92), '/').endswith('/' + runtime.SOURCE)]
            assert len(indices) == 1
            objects[indices[0]] = replacement
        executable = output / role / 'surface.exe'
        response = output / role / 'surface.args'
        args = flags + [str(source), *map(str, objects), '-o', str(executable)]
        response.write_text('\n'.join('"' + arg.replace('\\', '/') + '"' for arg in args))
        run([compiler, '@' + str(response)], output, events, role + '-link')
        if qualify_publication and role == 'candidate':
            fault_executable = publication.build_fault_executable(
                compiler, flags, source, objects, output, events, result['optimization'])
        outcomes[role] = {}
        for tag in ('1', '1t', '2', '3'):
            original = output / role / ('original-' + tag)
            run([executable, 'surface-write', 'unused', original, tag], output, events, role + '-write')
            raw = original.read_bytes()
            assert raw[:8] == ('S5MJ000' + tag[0]).encode()
            assert zlib.crc32(raw[:-4]) == struct.unpack('<I', raw[-4:])[0]
            restored = output / role / ('restored-' + tag)
            observed = run([executable, 'surface-read', original, restored, tag], output, events, role + '-read')
            assert b'SURFACE_ACCEPTED' in observed.stdout and restored.read_bytes() == raw
            assert b'MATRIX_LOGICAL_FIELD_OFFSETS=144 148 152 156' in observed.stdout
            assert b'SURFACE_OCCUPIED_REFUSED' in observed.stdout
            refused_modes = ['surface-wrong-owner']
            if tag[0] != '1':
                refused_modes.append('surface-disabled')
            for refused_mode in refused_modes:
                observed = run([executable, refused_mode, original, restored, tag],
                               output, events, role + '-' + refused_mode)
                assert b'SURFACE_REFUSED_EMPTY' in observed.stdout
                assert restored.read_bytes() == raw
            if tag in ('1', '1t'):
                direct = output / role / f'advance-{tag}-direct'
                resumed = output / role / f'advance-{tag}-resumed'
                for mode, target in (('surface-write-advance', direct), ('surface-read-advance', resumed)):
                    observed = run([executable, mode, original, target, tag], output, events, role + '-advance')
                    assert b'MATRIX_CONTINUATION_PASS' in observed.stdout
                assert direct.read_bytes() == resumed.read_bytes()
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
            if qualify_publication and role == 'candidate':
                target = output / role / ('publish-' + tag)
                pending = target.with_suffix('.pending')
                target.write_bytes(raw)
                pending.write_bytes(b'occupied pending')
                run([executable, 'surface-write-refuse', 'unused', target, tag],
                    output, events, 'publication-occupied-pending')
                assert target.read_bytes() == raw and pending.read_bytes() == b'occupied pending'
                failed = output / role / ('directory-' + tag)
                failed.mkdir()
                marker = failed / 'preserved'
                marker.write_bytes(b'destination marker')
                run([executable, 'surface-write-refuse', 'unused', failed, tag],
                    output, events, 'publication-replace-refused')
                assert marker.read_bytes() == b'destination marker'
                assert failed.with_suffix('.pending').read_bytes() == raw
                fresh = output / role / ('replace-' + tag)
                fresh.write_bytes(b'previous generation')
                run([executable, 'surface-write', 'unused', fresh, tag],
                    output, events, 'publication-replace-success')
                assert fresh.read_bytes() == raw and not fresh.with_suffix('.pending').exists()
                previous = output / role / ('previous-' + tag)
                run([executable, 'surface-write-previous', 'unused', previous, tag],
                    output, events, 'publication-previous-generation')
                old_bytes = previous.read_bytes()
                assert old_bytes != raw
                assert zlib.crc32(old_bytes[:-4]) == struct.unpack('<I', old_bytes[-4:])[0]
                previous_restore = output / role / ('previous-restored-' + tag)
                run([executable, 'surface-read', previous, previous_restore, tag],
                    output, events, 'publication-previous-restore')
                assert previous_restore.read_bytes() == old_bytes
                for stage in range(2, 6 if os.name == 'nt' else 7):
                    target = output / role / f'fault-{tag}-{stage}'
                    target.write_bytes(old_bytes)
                    label = f'publication-fault-{tag}-{stage}'
                    event = fault_support.execute(
                        [fault_executable, 'surface-write-refuse', 'unused', target, tag],
                        output, label, {'MTPUB_TARGET': str(target), 'MTPUB_FAIL': str(stage)})
                    assert b'SURFACE_PUBLICATION_REFUSED' in (output / event['stdout']).read_bytes()
                    pending = target.with_suffix('.pending')
                    if stage == 6:
                        assert target.read_bytes() == raw and not pending.exists()
                    else:
                        assert target.read_bytes() == old_bytes and pending.read_bytes() == raw
                    publication_faults.append({'fixture': tag, 'stage': stage, 'event': event})
                for phase in ('before', 'after'):
                    case = output / role / f'termination-{tag}-{phase}'
                    case.mkdir()
                    target = case / 'published'
                    target.write_bytes(old_bytes)
                    event = fault_support.terminate(
                        [fault_executable, 'surface-write', 'unused', target, tag],
                        case, phase, target)
                    pending = target.with_suffix('.pending')
                    expected = old_bytes if phase == 'before' else raw
                    assert target.read_bytes() == expected
                    if phase == 'before':
                        assert pending.read_bytes() == raw
                    else:
                        assert not pending.exists()
                    recovery = case / 'restored'
                    observed = run([executable, 'surface-read', target, recovery, tag],
                                   output, events, f'publication-termination-{tag}-{phase}-restore')
                    assert b'SURFACE_ACCEPTED' in observed.stdout
                    assert recovery.read_bytes() == expected
                    publication_terminations.append({'fixture': tag, 'event': event})



    for tag in ('1', '1t', '2', '3'):
        assert (output / 'incumbent' / ('original-' + tag)).read_bytes() == (output / 'candidate' / ('original-' + tag)).read_bytes()
    for tag in ('1', '1t'):
        endpoint = f'advance-{tag}-direct'
        assert (output / 'incumbent' / endpoint).read_bytes() == (output / 'candidate' / endpoint).read_bytes()
    (output / 'SURFACE_RESULT.json').write_text(json.dumps({
        'native_archive_sha256': digest, 'platform': result['platform'], 'optimization': result['optimization'],
        'publication_terminations': publication_terminations,
        'publication_faults': publication_faults, 'admitted_malformed': outcomes, 'surface_mass': 0.25, 'private_publication': qualify_publication, 'production_admission': False
    }, indent=2) + '\n')
    assert not any(outcomes['candidate'].values()), outcomes
    print(outcomes)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('native', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('compiler')
    parser.add_argument('--qualify-publication', action='store_true')
    arguments = parser.parse_args()
    execute(arguments.native.resolve(), arguments.output.resolve(), arguments.compiler,
            arguments.qualify_publication)
