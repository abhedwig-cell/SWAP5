"""Current public writer atomic refusal and actual new-envelope owner controls."""
import argparse, csv, hashlib, json, os, re, shutil, subprocess, sys, tarfile, time
from pathlib import Path
from production_diagnostic_guards import ROOT, qualify as nested, windows_bundle

BASE = ROOT/'integration/dataqual15_hupsel'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def instrument(source):
    marker = "        call require(code==0,'source complete rotation checkpoint')\n"
    assert source.count(marker) == 1
    source = source.replace(marker, marker+'        if(t1==2d0)call probe_diagnostic_writer()\n')
    marker = '\ncontains\n'; assert source.count(marker) == 1
    procedure = '''
  subroutine probe_diagnostic_writer()
    use iso_fortran_env,only:int8
    use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf,ieee_negative_inf
    integer(int8),allocatable::before(:),after(:)
    real(real64)::saved_p,saved_g,bad(3)
    integer::n,n_after,u,io,j,field,probe_log
    saved_p=potato%last_pressure;saved_g=grass%last_pressure
    bad=[ieee_value(0d0,ieee_quiet_nan),ieee_value(0d0,ieee_positive_inf), &
         ieee_value(0d0,ieee_negative_inf)]
    inquire(file='checkpoint.bin',size=n,iostat=io)
    call require(io==0.and.n>0.and.n<=16777216,'writer probe original size')
    allocate(before(n),after(n))
    open(newunit=u,file='checkpoint.bin',access='stream',form='unformatted',status='old',action='read')
    read(u,iostat=io)before;close(u);call require(io==0,'writer probe original read')
    open(newunit=probe_log,file='writer_probe.dat',status='new',action='write')
    do field=1,2
      do j=1,3
        potato%last_pressure=saved_p;grass%last_pressure=saved_g
        if(field==1)potato%last_pressure=bad(j)
        if(field==2)grass%last_pressure=bad(j)
        call write_hupsel_rotation_restart('checkpoint.bin',column_id,template,p%parameter_set_id,p,water,solute, &
          hupsel_germination,potato,grass,scheduled_irrigation,code)
        call require(code==1,'nonfinite writer must refuse normally')
        inquire(file='checkpoint.bin',size=n_after,iostat=io)
        call require(io==0.and.n_after==n,'failed writer changed target size')
        open(newunit=u,file='checkpoint.bin',access='stream',form='unformatted',status='old',action='read')
        read(u,iostat=io)after;close(u)
        call require(io==0.and.all(before==after),'failed writer changed target bytes')
        write(probe_log,'(3(i0,1x))')field,j,code
      end do
    end do
    close(probe_log);potato%last_pressure=saved_p;grass%last_pressure=saved_g;code=0
  end subroutine
'''
    return source.replace(marker,marker+procedure,1)


def writer_build(bundle, out, compiler, windows=False):
    out.mkdir(); r = json.loads((bundle/'BUILD.json').read_text())
    record = r['baseline'] if windows else r
    compiler = compiler.resolve()
    assert subprocess.check_output([str(compiler),'--version'],text=True).splitlines()[0] == record['compiler']
    if windows:
        objects = list(r['linked_objects_sha256']); pins = r['linked_objects_sha256']
        assert sha(bundle/'hupsel_rotation_restart.f90') == r['source_sha256']
        assert hashlib.sha256((ROOT/'app/solute_project/hupsel_rotation_restart.f90').read_bytes().replace(b'\r\n',b'\n')).hexdigest() == r['source_sha256']
    else: objects = list(record['object_sha256']); pins = record['object_sha256']
    assert len(objects) == 236 and all(sha(Path(p)) == digest for p,digest in pins.items())
    provider = record['publication_provider']
    for key in ('source','object'): assert sha(Path(provider[key])) == provider[key+'_sha256']
    assert sha(Path(record['ttutil_archive'])) == record['archive_sha256']
    for p in bundle.glob('*.mod'): shutil.copyfile(p,out/p.name)
    source = out/'main_writer_probe.f90'; source.write_text(instrument((ROOT/'app/solute_project/main.f90').read_text()),encoding='utf-8',newline='\n')
    flags = [p for p in record['flags'] if not p.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
    events = []
    def run(cmd):
        start=time.monotonic();p=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=300)
        i=len(events);(out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr)
        events.append(dict(command=list(map(str,cmd)),returncode=p.returncode,seconds=time.monotonic()-start))
        (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,p.stderr
    obj=out/'writer_probe.o';run([compiler,*flags,'-c',source,'-o',obj]);objects[-1]=str(obj)
    exe=out/('writer-probe.exe' if os.name=='nt' else 'writer-probe')
    args=['-fopenmp']+(['-Wl,--stack,16777216'] if os.name=='nt' else [])+objects+[provider['object'],record['ttutil_archive'],'-o',str(exe)]
    response=out/'link.args';response.write_text('\n'.join('"'+p.replace('\\','/')+'"' for p in args)+'\n')
    run([compiler,'@'+str(response)])
    (out/'BUILD.json').write_text(json.dumps(dict(executable_sha256=sha(exe),instrumented_main_sha256=sha(source),
        parent_build_sha256=sha(bundle/'BUILD.json'),current_app_source_sha256=hashlib.sha256((ROOT/'app/solute_project/hupsel_rotation_restart.f90').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),events=events),indent=2)+'\n')
    return exe


def measure(exe, probe, inputs, out):
    out.mkdir(); events=[]; env=os.environ.copy();env.pop('SWAP5_DIAG_PREDECESSOR',None)
    def run(name,end,seed=None,program=exe):
        case=out/name;case.mkdir()
        for p in inputs.iterdir():
            if p.suffix.lower() in ('.swp','.crp','.dra','.met','.nml'):shutil.copyfile(p,case/p.name)
        ends=[float(v) for v in re.search(r'^ends_day=(.*)$',(case/'input.nml').read_text(),re.M)[1].split(',')if v.strip()]
        stop=next(i+1 for i,v in enumerate(ends)if v==end)
        cmd=[str(program),'input.nml',str(seed)if seed else '-',str(stop),'swap.swp','maize.crp']
        start=time.monotonic();p=subprocess.run(cmd,cwd=case,env=env,capture_output=True,timeout=120)
        (case/'stdout').write_bytes(p.stdout);(case/'stderr').write_bytes(p.stderr)
        events.append(dict(command=cmd,returncode=p.returncode,seconds=time.monotonic()-start));assert p.returncode==0,p.stdout+p.stderr
        raw=(case/'checkpoint.bin').read_bytes();assert raw[:8]==b'S5HR0004'
        return case
    first=run('day1',1);whole=run('continuous2',2);restart=run('restart2',2,first/'checkpoint.bin');attempt=run('writer2',2,program=probe)
    assert (whole/'checkpoint.bin').read_bytes()==(restart/'checkpoint.bin').read_bytes()==(attempt/'checkpoint.bin').read_bytes()
    assert (whole/'budget.csv').read_bytes()==(attempt/'budget.csv').read_bytes()
    assert (whole/'crop.csv').read_bytes()==(attempt/'crop.csv').read_bytes()
    expected=['1 1 1','1 2 1','1 3 1','2 1 1','2 2 1','2 3 1']
    assert [' '.join(line.split())for line in (attempt/'writer_probe.dat').read_text().splitlines()]==expected
    assert not list(attempt.glob('checkpoint.bin.*'))
    result=dict(status='CURRENT_S5HR4_TWO_DAY_OWN_RESTART_AND_SIX_PUBLIC_WRITER_REFUSALS_PASS',
                executable_sha256=sha(exe),probe_executable_sha256=sha(probe),checkpoint_sha256=sha(whole/'checkpoint.bin'),
                finite_writer_refusals=6,each_failed_write_preserves_prior_target_bytes=True,strict_restart_exact=True,events=events)
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');return whole


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('bundle','compiler','inputs','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();bundle=a.bundle.resolve();out=a.output.resolve();out.mkdir()
    probe=writer_build(bundle,out/'writer-build',a.compiler,windows=os.name=='nt')
    qualified=windows_bundle(bundle,out/'ordinary-bundle')if os.name=='nt'else bundle
    exe=qualified/('swap5_hupsel_germination.exe'if os.name=='nt'else'swap5_hupsel_germination')
    case=measure(exe,probe,a.inputs.resolve(),out/'publication')
    nested(qualified,case,case/'checkpoint.bin',out/'nested')
    print('CURRENT_PRODUCTION_ENVELOPE_PUBLICATION_WRITER_AND_37_OWNER_CONTROLS_PASS')
