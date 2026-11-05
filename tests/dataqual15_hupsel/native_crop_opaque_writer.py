"""Explicit private DTO fault injection through the actual atomic public writer."""
import hashlib,json,os,shutil,subprocess
from pathlib import Path
import production_diagnostic_native as native
ROOT=native.ROOT
APP='app/solute_project/hupsel_rotation_restart.f90'

def instrument_app(source):
    start=source.index(' subroutine write_hupsel_rotation_restart(');end=source.index(' end subroutine',start)
    body=source[start:end]
    marker='  logical::ok\n';assert body.count(marker)==1
    body=body.replace(marker,marker+'  logical::fault\n  integer::fu,fault_field,fault_bits\n')
    marker='  if(io==0)call serialize_wofost_crop_view(u,.false.,v,io,source_clipped_schema=.true.,grass_schema=.true.)'
    assert body.count(marker)==1
    injected='''  ! TEST ONLY: perturb an exported DTO after public-state checks.
  inquire(file='logical-fault.bin',exist=fault)
  if(fault)then
   open(newunit=fu,file='logical-fault.bin',status='old',action='read')
   read(fu,*)fault_field,fault_bits
   close(fu)
   select case(fault_field)
'''
    for i,(owner,field)in enumerate((owner,field)for owner in ('v','g')for field in ('grass_management_present','receipt%root_layer_reduction_clipped','owner%evolution_continuation%anthesis_reached','root_growth_carrier%valid')):
        injected+='   case('+str(i+1)+')\n'
        if 'evolution_continuation'in field:injected+='    if(.not.allocated('+owner+'%owner%evolution_continuation))allocate('+owner+'%owner%evolution_continuation)\n'
        injected+='    '+owner+'%'+field+'=transfer(fault_bits,.true.)\n'
    injected+='   case default\n    error stop "invalid test fault selector"\n   end select\n  end if\n'
    return source[:start]+body.replace(marker,injected+marker)+source[end:]

PROCEDURE='''
  subroutine probe_logical_writer()
    use iso_fortran_env,only:int8,int32
    integer(int8),allocatable::before(:),after(:)
    integer(int32)::bad(4)=[2,-1,256,2147483647]
    integer::n,n_after,u,io,j,field,probe_log
    inquire(file='checkpoint.bin',size=n,iostat=io)
    call require(io==0.and.n>0,'logical writer target exists')
    allocate(before(n),after(n))
    open(newunit=u,file='checkpoint.bin',access='stream',form='unformatted',status='old',action='read')
    read(u,iostat=io)before;close(u);call require(io==0,'logical writer baseline read')
    open(newunit=probe_log,file='logical_writer_probe.dat',status='new',action='write')
    do field=1,8
      do j=1,4
        open(newunit=u,file='logical-fault.bin',status='replace',action='write')
        write(u,*)field,bad(j);close(u)
        call write_hupsel_rotation_restart('checkpoint.bin',column_id,template,p%parameter_set_id,p,water,solute, &
          hupsel_germination,potato,grass,scheduled_irrigation,code)
        call require(code==1,'malformed DTO writer must refuse')
        inquire(file='checkpoint.bin',size=n_after,iostat=io)
        call require(io==0.and.n_after==n,'malformed DTO writer changed target size')
        open(newunit=u,file='checkpoint.bin',access='stream',form='unformatted',status='old',action='read')
        read(u,iostat=io)after;close(u)
        call require(io==0.and.all(before==after),'malformed DTO writer changed target bytes')
        write(probe_log,'(3(i0,1x))')field,j,code
      end do
    end do
    close(probe_log)
    open(newunit=u,file='logical-fault.bin',status='old');close(u,status='delete')
    call write_hupsel_rotation_restart('checkpoint.bin',column_id,template,p%parameter_set_id,p,water,solute, &
      hupsel_germination,potato,grass,scheduled_irrigation,code)
    call require(code==0,'unperturbed public writer resumes')
    open(newunit=u,file='checkpoint.bin',access='stream',form='unformatted',status='old',action='read')
    read(u,iostat=io)after;close(u)
    call require(io==0.and.all(before==after),'fault probe changed unperturbed target')
  end subroutine
'''

def instrument_main(source):
    result=native.instrument(source)
    marker='    close(probe_log);potato%last_pressure=saved_p;grass%last_pressure=saved_g;code=0\n'
    assert result.count(marker)==1
    result=result.replace(marker,marker+'    call probe_logical_writer()\n')
    assert result.count('\ncontains\n')==1
    return result.replace('\ncontains\n','\ncontains\n'+PROCEDURE,1)

def build(bundle,out,compiler):
    out.mkdir();b=json.loads((bundle/'BUILD.json').read_text());objects=list(b['object_sha256']);sources=list(b['source_sha256'])
    assert len(objects)==len(sources)==236
    for p in bundle.glob('*.mod'):shutil.copyfile(p,out/p.name)
    flags=[x for x in b['flags']if not x.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
    events=[]
    def run(cmd):
        p=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=300)
        (out/(str(len(events))+'.stdout')).write_bytes(p.stdout);(out/(str(len(events))+'.stderr')).write_bytes(p.stderr)
        events.append(dict(command=list(map(str,cmd)),returncode=p.returncode));assert p.returncode==0,p.stderr
    app=out/'hupsel_rotation_restart.f90';app.write_text(instrument_app((ROOT/APP).read_text()),encoding='utf-8',newline='\n')
    obj=out/'fault_app.o';run([compiler,*flags,'-c',app,'-o',obj])
    index=next(i for i,name in enumerate(sources)if Path(name)==ROOT/APP);objects[index]=str(obj)
    main=out/'main.f90';main.write_text(instrument_main((ROOT/'app/solute_project/main.f90').read_text()),encoding='utf-8',newline='\n')
    main_obj=out/'fault_main.o';run([compiler,*flags,'-c',main,'-o',main_obj]);objects[-1]=str(main_obj)
    exe=out/('writer-probe.exe'if os.name=='nt'else'writer-probe')
    args=['-fopenmp']+(['-Wl,--stack,16777216']if os.name=='nt'else[])+objects+[b['publication_provider']['object'],b['ttutil_archive'],'-o',str(exe)]
    response=out/'link.args';response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n');run([compiler,'@'+str(response)])
    (out/'BUILD.json').write_text(json.dumps(dict(status='PRIVATE_BODY_ONLY_DTO_FAULT_INSTRUMENTATION',parent_build_sha256=native.sha(bundle/'BUILD.json'),app_sha256=native.sha(app),main_sha256=native.sha(main),executable_sha256=native.sha(exe),events=events),indent=2)+'\n')
    return exe

def qualify(bundle,inputs,out,compiler):
    out.mkdir();exe=bundle/('swap5_hupsel_germination.exe'if os.name=='nt'else'swap5_hupsel_germination')
    probe=build(bundle,out/'build',compiler);native.measure(exe,probe,inputs,out/'publication')
    rows=[line.split()for line in (out/'publication/writer2/logical_writer_probe.dat').read_text().splitlines()]
    assert rows==[[str(i),str(j),'1']for i in range(1,9)for j in range(1,5)]
    assert not list((out/'publication/writer2').glob('checkpoint.bin.*'))
    (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_PUBLIC_WRITER_32_PRIVATE_DTO_FAULT_REFUSALS_PRESERVE_PRIOR_TARGET_PASS',scope='EXPLICIT_PRIVATE_SERIALIZED_DTO_FAULT_INJECTION_NOT_MALFORMED_PUBLIC_STATE_CONSTRUCTION',production_admission=False),indent=2)+'\n')
