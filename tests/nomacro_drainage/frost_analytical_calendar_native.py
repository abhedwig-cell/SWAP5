"""Real native calendar and thermal attacks with the original CDE interval2 frame."""
from output_thermal_controls import m
from frost_calendar_output import codec as magic,selection
from pathlib import Path
import contextlib,struct

def native(build,reference,project,full,out):
    selected=m.e.switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252'))
    root_tail_bytes=96 if selected['SWKIMPL'] else 0
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-2.zip';digest=m.sha(source)
    attacks=['old002','old003','old004','old005','foreign-kind','truncated','trailing','header-witness','shape','policy','negative-day','foreign-day','negative-counter','changed-counter','print-counter','zero-pointer','overflow-pointer','future-pointer','flag-domain','short-flag','step-flag','nonfinite','value-witness','negative-period','ordinary-water','ordinary-cde','ordinary-age','domain-version','domain-shape','domain-macro','domain-mode','domain-kind','domain-witness','domain-snow','domain-frost','domain-drainage','domain-heat','domain-calculation','aquifer-codec']
    if project.solute:attacks+=['cde-header-witness','cde-shape','cde-value-witness','cde-nonfinite','cde-negative-initial']
    checks=[]
    for attack in attacks:
        target=out/attack;target.mkdir(parents=True);origin=target/'origin';receipt=m.h.verify_checkpoint(source,2,meta['binding'],origin)
        path=origin/'macro.bin';raw=bytearray(path.read_bytes());assert raw[:8]==magic(project)
        starts=[];prefix=struct.pack('<2i',1,project.nodes);pos=raw.find(prefix)
        while pos>=0:
            if pos+160<=len(raw):
                header=list(struct.unpack_from('<20i',raw,pos));nreal=header[3]
                if nreal>100 and pos+160+16*nreal<=len(raw) and header==list(struct.unpack_from('<20i',raw,pos+80)):starts.append(pos)
            pos=raw.find(prefix,pos+1)
        assert len(starts)==1,starts
        pos=starts[0];header=list(struct.unpack_from('<20i',raw,pos));nreal=header[3]
        def integer(index,value,witness=True):
            struct.pack_into('<i',raw,pos+4*index,value)
            if witness:struct.pack_into('<i',raw,pos+80+4*index,value)
        def value(index,v,witness=True):
            struct.pack_into('<d',raw,pos+160+8*index,v)
            if witness:struct.pack_into('<d',raw,pos+160+8*nreal+8*index,v)
        if attack.startswith('domain-'):
            selected=selection(project);domain=struct.pack('<10i',1,project.nodes,0,int(project.solute),selected['swhyst'],1,selected['swfrost'],selected['swdra'],1,2)
            assert raw.count(domain+domain)==1;d=raw.index(domain+domain)
            index={'domain-version':0,'domain-shape':1,'domain-macro':2,'domain-mode':4,'domain-kind':3,'domain-witness':0,'domain-snow':5,'domain-frost':6,'domain-drainage':7,'domain-heat':8,'domain-calculation':9}[attack]
            previous=struct.unpack_from('<i',raw,d+4*index)[0];changed=previous+1
            struct.pack_into('<i',raw,d+4*index,changed)
            if attack!='domain-witness':struct.pack_into('<i',raw,d+40+4*index,changed)
        elif attack=='aquifer-codec':raw[:8]=b'S5IOQ001'
        elif attack.startswith('ordinary-'):raw[:8]={'ordinary-water':b'S5IOW001','ordinary-cde':b'S5IOC001','ordinary-age':b'S5IOA001'}[attack]
        elif attack.startswith('old'):raw[:8]=('S5AGE'+attack[-3:]).encode()
        elif attack=='foreign-kind':raw[:8]=b'S5IHW001' if project.solute or project.age else b'S5IHC001'
        elif attack=='truncated':raw=raw[:-1]
        elif attack=='trailing':raw+=b'x'
        elif attack=='header-witness':integer(7,header[7]+1,False)
        elif attack=='shape':integer(1,project.nodes+1)
        elif attack=='policy':integer(4,header[4]+1)
        elif attack=='negative-day':integer(6,-1)
        elif attack=='foreign-day':integer(6,5)
        elif attack=='negative-counter':integer(7,-1)
        elif attack=='changed-counter':integer(7,header[7]+1 if header[4]==0 or header[19] else header[4])
        elif attack=='print-counter':integer(8,header[8]+1)
        elif attack=='zero-pointer':integer(9,0)
        elif attack=='overflow-pointer':integer(10,2147483647)
        elif attack=='future-pointer':integer(10,100)
        elif attack=='flag-domain':integer(12,2)
        elif attack=='short-flag':integer(18,1-header[18])
        elif attack=='step-flag':integer(19,1-header[19])
        elif attack=='nonfinite':value(0,float('nan'))
        elif attack=='value-witness':value(0,123.,False)
        elif attack=='negative-period':value(nreal-1,-1.)
        elif attack.startswith('cde-'):
            c=pos+160+16*nreal;n=20+project.nodes
            assert struct.unpack_from('<3i',raw,c)==(2,project.nodes,n) and c+24+16*n==len(raw)-root_tail_bytes
            if attack=='cde-header-witness':struct.pack_into('<i',raw,c+12,3)
            if attack=='cde-shape':
                for offset in (4,16):struct.pack_into('<i',raw,c+offset,project.nodes+1)
            if attack=='cde-value-witness':struct.pack_into('<d',raw,c+24+8,123.)
            if attack in ('cde-nonfinite','cde-negative-initial'):
                for offset in (24,24+8*n):struct.pack_into('<d',raw,c+offset,float('nan') if attack=='cde-nonfinite' else -1.)
        path.write_bytes(raw)
        try:
            with contextlib.ExitStack() as stack:
                m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,[m.h.ColumnStart('original',2,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            diagnostic='\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
            assert 'ERROR STOP' in diagnostic and not list(target.glob('accepted-*.zip')),(attack,diagnostic,str(error))
            checks.append(dict(attack=attack,status='REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Corrupt original-output native accepted: '+attack)
        assert m.sha(source)==digest
    return checks

