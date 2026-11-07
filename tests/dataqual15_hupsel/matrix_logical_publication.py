"""Private S5MJ publication projection using the admitted native publisher."""


def replace_once(source, before, after):
    assert source.count(before) == 1, before
    return source.replace(before, after, 1)


def postimage(reader_source):
    source = reader_source.decode()
    source = replace_once(
        source, 'module mod_matrix_joint_restart_file\n',
        'module mod_matrix_joint_restart_file\n  use iso_c_binding, only: c_int,c_char,c_null_char\n')
    source = replace_once(source, 'contains\n', '''  interface
    integer(c_int) function publish_matrix(pending,target) bind(C,name='swap5_restart_publish')
      import c_int,c_char
      character(c_char),intent(in)::pending(*),target(*)
    end function
  end interface
contains
''')
    source = replace_once(source, '    integer::u,io,mode,n\n',
                          '    integer::u,io,mode,n,close_status\n    character(:),allocatable::pending\n')
    source = replace_once(
        source, "    open(newunit=u,file=path,access='stream',form='unformatted',status='replace',iostat=io)",
        "    pending=path//'.pending'\n"
        "    open(newunit=u,file=pending,access='stream',form='unformatted',status='new',iostat=io)")
    source = replace_once(source, '''    close(u)
    if(io/=0)return
    call append_crc(path,io)
    if(io==0)status=JOINT_OK
''', '''    if(io==0)flush(u,iostat=io)
    close(u,iostat=close_status)
    if(io/=0.or.close_status/=0)return
    call append_crc(pending,io)
    if(io/=0)return
    if(publish_matrix(pending//c_null_char,path//c_null_char)==0)status=JOINT_OK
''')
    first = source.index('  subroutine append_crc(')
    last = source.index('  subroutine check_crc(', first)
    crc = replace_once(source[first:last], 'integer::u,n,io', 'integer::u,n,io,close_status')
    crc = replace_once(crc, '    close(u)\n    if(io==0)status=0',
                       '    if(io==0)flush(u,iostat=io)\n    close(u,iostat=close_status)\n'
                       '    if(io==0.and.close_status==0)status=0')
    return (source[:first] + crc + source[last:]).encode()


def build_fault_executable(compiler, flags, driver, objects, output, events, optimization):
    """Link the same writer object to a separately instrumented publisher."""
    import subprocess
    from native_n_crc_runtime import run
    from pond_thermal_writer import ROOT, shim_source

    compiler_c = subprocess.check_output(
        [compiler, '-print-prog-name=gcc'], text=True).strip()
    source = ROOT / 'app/support/restart_publish.c'
    real = output / 'publication-fault-real.o'
    shim = output / 'publication-fault-shim.c'
    shim_object = shim.with_suffix('.o')
    shim.write_text(shim_source(), encoding='utf-8')
    cflags = ['-' + optimization, '-std=c11']
    run([compiler_c, *cflags, '-DSWAP5_RESTART_TESTING',
         '-Dswap5_restart_publish=swap5_restart_publish_real',
         '-c', source, '-o', real], output, events, 'publication-fault-real')
    run([compiler_c, *cflags, '-c', shim, '-o', shim_object],
        output, events, 'publication-fault-shim')
    assert objects[-1] == output / 'candidate/publisher.o'
    executable = output / 'candidate/publication-fault.exe'
    response = executable.with_suffix('.args')
    args = [*flags, str(driver), *map(str, objects[:-1]),
            str(real), str(shim_object), '-o', str(executable)]
    response.write_text('\n'.join('"' + arg.replace('\\', '/') + '"' for arg in args))
    run([compiler, '@' + str(response)], output, events, 'publication-fault-link')
    return executable
