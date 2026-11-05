"""Exact extracted CRC/native-I/O primitives; no full-adapter admission."""
import argparse,hashlib,json,os,re,struct,subprocess,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='6226cbb6c1539127890cc1c635e883f868bf0760'
REGISTER='integration/dataqual15_hupsel/CRC_FAMILY_PREREGISTRATION_20261105.json'
sha=lambda b:hashlib.sha256(b).hexdigest()

def procedure(text,kind,name):
    start=re.search(r'^\s*'+kind+r'\s+'+name+r'\(',text,re.M).start()
    end=re.search(r'^\s*end '+kind+r'\s*$',text[start:],re.M).end()+start
    return text[start:end]+'\n'

def guard():
    r=json.loads((ROOT/REGISTER).read_text());assert r['baseline']==BASE and r['production_delta']==[]
    for area in ('src','app','reference'):
        assert subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT)==subprocess.check_output(['git','rev-parse',BASE+':'+area],cwd=ROOT)
        assert not subprocess.check_output(['git','diff','HEAD','--',area],cwd=ROOT)
        assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',area],cwd=ROOT)
    for name,h in r['source_sha256'].items():
        assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==h
        assert sha(subprocess.check_output(['git','show',BASE+':'+name],cwd=ROOT))==h
    return r

DRIVER='''program probe
 use crc_fixture
 implicit none
 character(512)::mode,path
 integer::u,n,code
 integer(int8),allocatable::bytes(:)
 call get_command_argument(1,mode);call get_command_argument(2,path)
 select case(trim(mode))
 case('value')
  inquire(file=trim(path),size=n);allocate(bytes(n))
  open(newunit=u,file=trim(path),access='stream',form='unformatted',status='old',action='read')
  read(u)bytes;close(u);print '(I0)',crc32(bytes)
 case('append')
  call append_crc(trim(path),code);print '(I0)',code
 case('check')
  call check_crc(trim(path),code);print '(I0)',code
 end select
end program
'''

def wrapper(text,candidate,has_io):
    body=procedure(candidate if candidate else text,'function','crc32')
    if has_io:body+=procedure(text,'subroutine','append_crc')+procedure(text,'subroutine','check_crc')
    else:body+='subroutine append_crc(path,code)\ncharacter(*),intent(in)::path\ninteger,intent(out)::code\ncode=1\nend subroutine\nsubroutine check_crc(path,code)\ncharacter(*),intent(in)::path\ninteger,intent(out)::code\ncode=1\nend subroutine\n'
    return 'module crc_fixture\nuse iso_fortran_env,only:int8,int32,int64\nimplicit none\ninteger,parameter::MAX_BYTES=10485760\ncontains\n'+body+'end module\n'+DRIVER

def corpus():
    return {'empty':b'','standard':b'123456789','zero':b'\0','high':b'\xff','all':bytes(range(256)),'reverse':bytes(reversed(range(256))),'repeated':b'\xff'*4096,'zeros':b'\0'*4096,'ramp':bytes(range(256))*256,'mixed':bytes((i*73+(i>>3)+19)%256 for i in range(65537))}

def run(args,out,events,label):
    p=subprocess.run(list(map(str,args)),cwd=out,capture_output=True,timeout=90);stem='%04d-%s'%(len(events),label)
    for stream in ('stdout','stderr'):(out/(stem+'.'+stream)).write_bytes(getattr(p,stream))
    events.append(dict(label=label,command=list(map(str,args)),returncode=p.returncode,stdout=stem+'.stdout',stderr=stem+'.stderr'))
    (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,(label,p.stderr)
    return p.stdout

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();r=guard();out=a.output.resolve();out.mkdir(parents=True)
    shared=(ROOT/'src/adapter/mod_age_joint_restart_file.f90').read_text();reports=[]
    for name in list(r['source_sha256'])[:-1]:
        text=(ROOT/name).read_text();has_io='subroutine append_crc('in text
        for role in ('incumbent','candidate'):
            case=out/(Path(name).stem+'-'+role);case.mkdir();source=case/'probe.f90';source.write_text(wrapper(text,shared if role=='candidate'else None,has_io),newline='\n')
            exe=case/('probe.exe'if os.name=='nt'else'probe');events=[];flags=['-'+a.optimization,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fopenmp','-J'+str(case)]
            run([a.compiler,*flags,source,'-o',exe],case,events,'compile');values=[];native=[]
            for label,raw in corpus().items():
                payload=case/(label+'.payload');payload.write_bytes(raw);actual=int(run([exe,'value',payload],case,events,'value-'+label))&0xffffffff;expected=zlib.crc32(raw)
                values.append(dict(case=label,payload_sha256=sha(raw),actual=actual,expected=expected,oracle_pass=actual==expected))
                if has_io and label in ('standard','all','zeros','mixed'):
                    target=case/(label+'.native');target.write_bytes(raw);status=int(run([exe,'append',target],case,events,'append-'+label));assert status==0
                    disk=target.read_bytes();assert disk[:-4]==raw
                    own=int(run([exe,'check',target],case,events,'own-'+label));assert own==0
                    row=dict(case=label,native_sha256=sha(disk),stored=struct.unpack_from('<I',disk,len(disk)-4)[0],expected=expected,own_status=own,controls={})
                    mutants={'body':(bytes([disk[0]^1])+disk[1:],False),'crc':(disk[:-1]+bytes([disk[-1]^1]),False),'resealed':(bytes([disk[0]^1])+disk[1:-4]+struct.pack('<I',zlib.crc32(bytes([disk[0]^1])+disk[1:-4])),True),'truncated':(disk[:-2],False)}
                    for kind,(bad,want)in mutants.items():
                        path=case/(label+'-'+kind+'.native');path.write_bytes(bad);code=int(run([exe,'check',path],case,events,kind+'-'+label));row['controls'][kind]=dict(status=code,expected_accept=want,oracle_pass=(code==0)==want)
                    native.append(row)
            passed=all(v['oracle_pass']for v in values)and all(n['stored']==n['expected']and all(c['oracle_pass']for c in n['controls'].values())for n in native)
            report=dict(source=name,role=role,has_io=has_io,values=values,native=native,oracle_pass=passed,wrapper_sha256=sha(source.read_bytes()),executable_sha256=sha(exe.read_bytes()),flags=flags,compiler=subprocess.check_output([a.compiler,'--version'],text=True).splitlines()[0]);(case/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');reports.append(report)
            if role=='candidate':assert passed,name
    guard();result=dict(status='EXACT_EXTRACTED_CRC_FAMILY_COMPONENT_MEASUREMENT_COMPLETE',optimization=a.optimization,reports=reports,production_source_changed=False,full_adapter_qualified=False,whole_scientific_admission=False)
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(a.optimization,[(Path(v['source']).stem,v['role'],v['oracle_pass'])for v in reports])

if __name__=='__main__':main()
