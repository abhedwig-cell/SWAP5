"""Read-only complete component snapshots of retained current daily524-to525 mismatch."""
import argparse,contextlib,json,re,shutil,struct,subprocess,sys
from pathlib import Path

PIN='33770602914210e11b50d6bede94838bb4274958'

def micro_lookup_extension(source,clock):
    assert re.search(r'Mcount\s*=\s*801\b',source)
    assert re.search(r'wiltpoint\s*=\s*-20000\.0d0',source)
    anchor='   public :: do_RWU_micro, read_rwu_micro_input, PP, PL, UpwPot, swAlpTot, M_table, K_table'
    assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n   public :: hybrid_lookup_probe\n   logical,save::hybrid_lookup_applied=.false.')
    routines=f'''
subroutine hybrid_lookup_write(filename,clock)
use MOD_grid,only:numlay
use plant_interface,only:icrop,sw_drought
use ieee_arithmetic,only:ieee_is_finite
character(*),intent(in)::filename
real(8),intent(in)::clock
integer::unit
integer,parameter::nm=430,nk=429
if(.not.allocated(M_table).or..not.allocated(K_table))error stop 'Absent original microscopic context'
if(any(shape(M_table)/=[801,numlay]).or.any(shape(K_table)/=[801,numlay]))error stop 'Foreign original microscopic shape'
if(.not.all(ieee_is_finite(M_table(1:nm,:))).or..not.all(ieee_is_finite(K_table(1:nk,:))))error stop 'Nonfinite original microscopic context'
if(any(M_table(1:nm,:)<0d0).or.any(K_table(1:nk,:)<0d0))error stop 'Negative original microscopic context'
open(newunit=unit,file=filename,access='stream',form='unformatted',status='replace')
write(unit)'S5JMLP01',clock,icrop,sw_drought,iMicro,numlay,nm,nk,M_table(1:nm,:),K_table(1:nk,:)
close(unit)
end subroutine

subroutine hybrid_lookup_probe(restoring,clock)
use MOD_grid,only:numlay
use plant_interface,only:icrop,sw_drought
use ieee_arithmetic,only:ieee_is_finite
logical,intent(in)::restoring
real(8),intent(in)::clock
integer::unit,ios,owner,drought,micro,layers,nm,nk
real(8)::saved_clock
real(8),allocatable::saved_m(:,:),saved_k(:,:)
character(8)::magic
character::trailing
logical::exists
if(abs(clock-{clock}d0)>1d-8)return
if(.not.restoring)then
  call hybrid_lookup_write('hybrid-lookup-capture.bin',clock)
  return
end if
if(hybrid_lookup_applied)return
call hybrid_lookup_write('hybrid-lookup-current.bin',clock)
inquire(file='hybrid-lookup-origin.bin',exist=exists)
if(.not.exists)return
open(newunit=unit,file='hybrid-lookup-origin.bin',access='stream',form='unformatted',status='old')
read(unit,iostat=ios)magic,saved_clock,owner,drought,micro,layers,nm,nk
if(ios/=0)error stop 'Incomplete microscopic probe header'
if(magic/='S5JMLP01'.or.saved_clock/=clock.or.owner/=icrop.or.drought/=sw_drought.or.micro/=iMicro)error stop 'Foreign microscopic probe owner'
if(layers/=numlay.or.nm/=430.or.nk/=429)error stop 'Foreign microscopic probe dimensions'
allocate(saved_m(nm,layers),saved_k(nk,layers))
read(unit,iostat=ios)saved_m,saved_k
if(ios/=0)error stop 'Incomplete microscopic probe context'
read(unit,iostat=ios)trailing
if(.not.is_iostat_end(ios))error stop 'Trailing microscopic probe context'
close(unit)
if(.not.all(ieee_is_finite(saved_m)).or..not.all(ieee_is_finite(saved_k)))error stop 'Nonfinite microscopic probe context'
if(any(saved_m<0d0).or.any(saved_k<0d0))error stop 'Negative microscopic probe context'
M_table(1:nm,:)=saved_m
K_table(1:nk,:)=saved_k
hybrid_lookup_applied=.true.
call hybrid_lookup_write('hybrid-lookup-restored.bin',clock)
end subroutine
'''
    anchor='end module mod_RWU_micro';assert source.count(anchor)==1
    return source.replace(anchor,routines+'\n'+anchor)

def saved_numeric(source):
    fields=[]
    for line in source.splitlines():
        match=re.match(r'\s*(real\([^)]*\)|integer|logical)(?!\w)(.*?\bsave\s*::\s*)(\w+)',line,re.I)
        if match:
            kind='real' if match[1].lower().startswith('real') else match[1].lower()
            fields.append((match[3],kind))
    return fields

def drainage_source(selected,clock,variables=False):
    source=(selected/'MOD_drainage.f90').read_text(encoding='cp1252').split('\ncontains',1)[0]
    module='MOD_drain'
    if variables:
        source=(selected/'variables.f90').read_text(encoding='cp1252')
        source=re.search(r'(?is)\bmodule variables\s*\n(.*?)\bend module variables',source)[1]
        module='variables'
    declarations=[]
    for line in source.splitlines():
        match=re.match(r'\s*(real\([^)]*\)|integer|logical)(?!\w).*?::\s*(\w+)',line,re.I)
        if match and (variables or re.search(r'\bsave\b',line,re.I)):
            kind='real' if match[1].lower().startswith('real') else match[1].lower()
            declarations.append((match[2],kind,line))
    imports=[];writes=[];inventory=[]
    for i,(name,kind,declaration) in enumerate(declarations):
        assert 'pointer' not in declaration.lower()
        alias='drain_field_'+str(i);count='size('+alias+')' if 'dimension' in declaration.lower() else '1'
        imports.append('use '+module+',only:'+alias+'=>'+name)
        if 'allocatable' in declaration.lower():writes.append('if(allocated('+alias+'))then')
        writes.append('write(unit)'+alias)
        writes.append("write(*,'(a,1x,a,1x,a,3(1x,i0))')'DIAG_DRAIN_LAYOUT',phase,'"+name+"',"+str({'real':1,'integer':2,'logical':3}[kind])+','+count+',storage_size('+alias+')')
        if 'allocatable' in declaration.lower():
            bits='64' if kind=='real' else '32'
            writes+=['else',"write(*,'(a,1x,a,1x,a,3(1x,i0))')'DIAG_DRAIN_LAYOUT',phase,'"+name+"',"+str({'real':1,'integer':2,'logical':3}[kind])+',-1,'+bits,'end if']
        inventory.append(dict(field=name,kind=kind,declaration=declaration.strip()))
    text='subroutine dump_drainage(phase)\n'+'\n'.join(imports)+f'''
implicit none
character(*),intent(in)::phase
integer::unit
if(abs(t1900-{clock}d0)>1d-8)return
if(phase/='BEFORE_METEO3'.and.phase/='BEFORE_DRAIN2'.and.phase/='AFTER_DRAIN2')return
open(newunit=unit,file='diagnostic-drain-'//trim(phase)//'.bin',access='stream',form='unformatted',status='replace')
'''+ '\n'.join(writes)+'''
close(unit)
end subroutine
'''
    return text,inventory

def snapshot_source(selected,clock,drainage=False,variables=False,micro=False):
    fields=[]
    for module,file in [('plant_interface','interface_plant.f90'),('atmosphere_interface','interface_atmosphere.f90')]:
        for name,kind in saved_numeric((selected/file).read_text(encoding='cp1252')):
            fields.append((module,name,name,kind))
    for name,expression,kind in [
        ('h','h(1:numnod)','real'),('theta','theta(1:numnod)','real'),
        ('k','k(1:numnod+1)','real'),('kmean','kmean(1:numnod+1)','real'),
        ('dimoca','dimoca(1:numnod)','real'),('fhyst','fhyst(1:numnod)','real'),
        ('indeks','indeks(1:numnod)','integer'),
        *[(name,name,'real') for name in ('dt','dtold','pond','pondm1','gwl','volact')]]:
        fields.append(('variables',name,expression,kind))
    fields.append(('MOD_MvG','cofgen','cofgen(:,1:numnod)','real'))
    for name in ('tsoil','heacon','heacap'):
        fields.append(('MOD_SoilTemperature',name,name+'(1:numnod)','real'))
    for name in ('tetop','tebot'):fields.append(('MOD_SoilTemperature',name,name,'real'))
    for name in ('theatm','katm','q0','hsurf'):fields.append(('MOD_top',name,name,'real'))
    for name in ('FlRunoff','ftoph'):fields.append(('MOD_top',name,name,'logical'))
    imports=['module hybrid_state_diagnostic','use MOD_grid,only:numnod','use variables,only:t1900']
    if micro:imports.append('use mod_RWU_micro,only:hybrid_lookup_probe')
    writes=[];inventory=[]
    for i,(module,name,expression,kind) in enumerate(fields):
        alias='component_'+str(i)
        imports.append('use '+module+',only:'+alias+'=>'+name)
        expression=re.sub(r'^'+re.escape(name)+r'\b',alias,expression)
        fmt={'real':'es25.17e3','integer':'i0','logical':'l1'}[kind]
        label=module+'.'+name
        writes.append("write(*,'(a,*(1x,"+fmt+"))') 'DIAG_FIELD "+label+"',"+expression)
        inventory.append(dict(field=label,kind=kind,original_expression=expression.replace(alias,name)))
    text='\n'.join(imports)+f'''
implicit none
contains
subroutine hybrid_snapshot(phase)
character(*),intent(in)::phase
if(t1900<{clock}d0.or.t1900>{clock+1}d0)return
'''+('call dump_drainage(phase)\n' if drainage or variables else '')+'''
'''+(f"if(phase=='DAY_RETURN'.and.abs(t1900-{clock}d0)<1d-8)call hybrid_lookup_probe(.false.,t1900)\n" if micro else '')+'''
write(*,'(a,1x,a,1x,f18.8)')'DIAG_COMPONENT_BEGIN',phase,t1900
'''+ '\n'.join(writes)+'''
write(*,'(a)')'DIAG_COMPONENT_END'
end subroutine
'''
    if drainage or variables:text+=drainage_source(selected,clock,variables)[0]
    text+='end module\n'
    return text,inventory

def instrument_source(text,filename,replace,drainage=False,clock=None,micro=False):
    anchor='use MOD_grid, only: numnod' if filename=='swap_main.f90' else 'use MOD_grid,            only: numnod'
    text=replace(text,anchor,anchor+'\nuse hybrid_state_diagnostic,only:hybrid_snapshot')
    if filename=='swap_main.f90':
        for label,anchor in [('READY',"   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900"),('DAY_RETURN',"      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900")]:
            text=replace(text,anchor,"call hybrid_snapshot('"+label+"')\n"+anchor)
    else:
        if micro:text=replace(text,'use hybrid_state_diagnostic,only:hybrid_snapshot','use hybrid_state_diagnostic,only:hybrid_snapshot\nuse mod_RWU_micro,only:hybrid_lookup_probe')
        for label,anchor in [('METEO2','            call Meteo(2)'),('METEO3','         call Meteo(3)')]:
            text=replace(text,anchor,"call hybrid_snapshot('BEFORE_"+label+"')\n"+anchor+"\ncall hybrid_snapshot('AFTER_"+label+"')")
        anchor='         call hybrid_apply_wofost(fl_cropemergence)'
        text=replace(text,anchor,anchor+"\ncall hybrid_snapshot('AFTER_MANAGEMENT_RESTORE')")
        if micro:text=replace(text,anchor,anchor+'\ncall hybrid_lookup_probe(.true.,t1900)')
        if drainage:
            anchor='         if (swdra > 0)    call drain(2)'
            text=replace(text,anchor,f"if(abs(t1900-{clock}d0)<1d-8)call hybrid_snapshot('BEFORE_DRAIN2')\n"+anchor+f"\nif(abs(t1900-{clock}d0)<1d-8)call hybrid_snapshot('AFTER_DRAIN2')")
    return text

def drainage_comparison(out):
    layouts={};payloads={}
    for label in ('warm','cold'):
        directory=out/label/'original';layout={}
        for line in (directory/'donor.stdout').read_text().splitlines():
            if not line.startswith('DIAG_DRAIN_LAYOUT '):continue
            _,phase,name,kind,count,bits=line.split()
            item=dict(field=name,kind=int(kind),count=int(count),bits=int(bits))
            fields=layout.setdefault(phase,[])
            existing=next((x for x in fields if x['field']==name),None)
            if existing is None:fields.append(item)
            else:assert existing==item  # repeated original retry snapshot overwrites the same binary

        layouts[label]=layout
        payloads[label]={phase:(directory/('diagnostic-drain-'+phase+'.bin')).read_bytes() for phase in layout}
    assert layouts['warm']==layouts['cold'] and len(layouts['warm'])==3
    result=[]
    for phase,fields in layouts['warm'].items():
        offset=0;differences=[]
        for field in fields:
            size=max(0,field['count'])*field['bits']//8
            before=payloads['warm'][phase][offset:offset+size];after=payloads['cold'][phase][offset:offset+size]
            assert len(before)==size and len(after)==size
            if before!=after:
                assert field['bits'] in (32,64)
                code=('d' if field['bits']==64 else 'f') if field['kind']==1 else ('q' if field['bits']==64 else 'i')
                a=struct.unpack('<'+str(field['count'])+code,before);b=struct.unpack('<'+str(field['count'])+code,after)
                changed=[i for i,(x,y) in enumerate(zip(a,b)) if x!=y]
                differences.append(dict(**field,changed_entries=len(changed),maximum_absolute_difference=max(abs(x-y) for x,y in zip(a,b)),first_changed=[dict(index=i+1,warm=a[i],cold=b[i]) for i in changed[:8]]))
            offset+=size
        assert offset==len(payloads['warm'][phase])==len(payloads['cold'][phase])
        result.append(dict(phase=phase,bytes=offset,layout=fields,differences=differences))
    return result

def snapshots(path,inventory):
    kinds={x['field']:x['kind'] for x in inventory};result=[];frame=None
    for line in path.read_text().splitlines():
        if line.startswith('DIAG_COMPONENT_BEGIN '):
            parts=line.split();frame=dict(phase=parts[1],clock=float(parts[2]),fields={})
        elif line.startswith('DIAG_FIELD '):
            parts=line.split();kind=kinds[parts[1]]
            convert=(lambda x:float(x.replace('D','E'))) if kind=='real' else (int if kind=='integer' else lambda x:x=='T')
            frame['fields'][parts[1]]=[convert(x) for x in parts[2:]]
        elif line.startswith('DIAG_COMPONENT_END'):
            assert len(frame['fields'])==len(inventory);result.append(frame);frame=None
    assert frame is None
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-root',type=Path,required=True);p.add_argument('--prior',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--reconnect-wofost-interface',action='store_true');p.add_argument('--drainage-snapshots',action='store_true');p.add_argument('--variables-snapshots',action='store_true');p.add_argument('--micro-lookup-replay',action='store_true');a=p.parse_args()
    assert not a.micro_lookup_replay and not a.drainage_snapshots
    pinned=a.source_root.resolve();assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=pinned,text=True).strip()==PIN
    sys.path.insert(0,str(pinned/'tools/solute'));sys.path.insert(0,str(pinned/'app/hybrid_water'))
    import daily_host as h
    import experimental_project as e
    from daily_coupling import validate_bundle
    from check_nomacro_coverage import physical
    prior=a.prior.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    base=prior/'water-history-O2-build';ref=prior/'provider';project=e.load(prior/'input-water-history')
    meta,case=validate_bundle(base,ref,project);identity=meta['identity']
    assert h.sha(Path(shutil.which('gfortran')))==identity['compiler_sha256']
    objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj'
    for name,digest in identity['donor_objects'].items():assert h.sha(objects/name)==digest
    for directory,key in [(objects,'donor_modules'),(ttutil,'ttutil_modules')]:
        for name,digest in identity[key].items():assert h.sha(directory/name)==digest
    assert h.sha(ttutil/'libttutil.a')==identity['ttutil_library']
    source=prior/'water-history-O2-everyday/warm/accepted-column-1-day-524.zip';digest=h.sha(source)
    origin=out/'verified-origin';receipt=h.verify_checkpoint(source,524,meta['binding'],origin)
    target=out/'private-carrier';shutil.copytree(base,target);(target/'BUILD.json').rename(target/'CARRIER_BUILD.json')
    for name in ('day_donor','day_kernel'):h.executable(target,name).chmod(0o755)
    replacements={Path(name).with_suffix('.o').name:target/Path(name).with_suffix('.o').name for name in identity['donor_generated']}
    linked=[str(replacements.get(q.name,q)) for q in sorted(objects.glob('*.o'))]+[str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')]
    logs=[]
    def compile(command):
        r=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=90)
        logs.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr))
        (out/'COMPILATION.json').write_text(json.dumps(logs,indent=2)+'\n');assert r.returncode==0,r.stderr
    # Verify cached touched objects by reproducing the exact immutable executable.
    original_link=target/'unmodified-donor-check'
    compile(['gfortran','-o',str(original_link),*linked])
    assert h.sha(original_link)==meta['executable_sha256']['donor']
    if a.micro_lookup_replay:
        prepared=json.loads((ref/'PREPARED.json').read_text())
        original=ref/'build/swap-selected/RWU_micro.f90'
        assert h.sha(original)==prepared['provider_files']['build/swap-selected/RWU_micro.f90']
        assert prepared['floating_point_profile']==identity['floating_point_profile']
        assert prepared['toolchain']['gfortran']['sha256']==identity['compiler_sha256']
        (target/'RWU_micro.f90').write_text(micro_lookup_extension(original.read_text(encoding='cp1252'),project.start_clock+524),encoding='cp1252')
        provider_flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch',*prepared['floating_point_profile']['flags']]
        compile(['gfortran',*provider_flags,'-I',str(objects),'-I',str(ttutil),'-c','RWU_micro.f90'])
        replacements['RWU_micro.o']=target/'RWU_micro.o'
    root=(target/'MOD_cropdevelopment.f90').read_text(encoding='cp1252')
    assert h.sha(target/'MOD_cropdevelopment.f90')==identity['donor_generated']['MOD_cropdevelopment.f90']
    modulepart=re.split(r'(?im)^\s*contains\s*$',root,1)[0]
    root_fields=[];root_writes=[]
    for line in modulepart.splitlines():
        match=re.match(r'\s*(real\([^)]*\)|integer|logical)(?!\w).*?\bsave\s*::\s*(.*)',line,re.I)
        if not match:continue
        kind='real' if match[1].lower().startswith('real') else match[1].lower()
        for name in match[2].split('!')[0].split(','):
            name=name.strip().split('=')[0].strip();assert re.fullmatch(r'\w+',name),(line,name)
            count='size('+name+')' if 'dimension' in line.lower() else '1'
            root_fields.append(dict(field=name,kind=kind,declaration=line.strip()))
            root_writes.append('write(unit)'+name)
            root_writes.append("write(*,'(a,1x,a,1x,a,3(1x,i0))')'DIAG_DRAIN_LAYOUT',phase,'"+name+"',"+str({'real':1,'integer':2,'logical':3}[kind])+','+count+',storage_size('+name+')')
    routine="""
subroutine hybrid_root_dump(phase)
use variables,only:t1900
character(*),intent(in)::phase
integer::unit
if(t1900/="""+str(project.start_clock+524)+"""d0)return
if(phase/='BEFORE_METEO3'.and.phase/='BEFORE_DRAIN2'.and.phase/='AFTER_DRAIN2')return
open(newunit=unit,file='diagnostic-drain-'//trim(phase)//'.bin',access='stream',form='unformatted',status='replace')
"""+'\n'.join(root_writes)+"""
close(unit)
end subroutine
"""
    root=re.sub(r'(?im)^(\s*)contains\s*$',r'\1public :: hybrid_root_dump\n\1contains',root,count=1)
    root=re.sub(r'(?im)^\s*end module MOD_cropdevelopment',routine+'\nend module MOD_cropdevelopment',root,count=1)
    assert 'subroutine hybrid_root_dump' in root
    (target/'MOD_cropdevelopment.f90').write_text(root,encoding='cp1252')
    compile(['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c','MOD_cropdevelopment.f90'])
    def root_wrapper(selected,clock,variables=False):
        return 'subroutine dump_drainage(phase)\nuse MOD_cropdevelopment,only:hybrid_root_dump\ncharacter(*),intent(in)::phase\ncall hybrid_root_dump(phase)\nend subroutine\n',root_fields
    globals()['drainage_source']=root_wrapper
    diagnostic,inventory=snapshot_source(ref/'build/swap-selected',project.start_clock+524,a.drainage_snapshots,a.variables_snapshots,a.micro_lookup_replay)
    (target/'hybrid_state_diagnostic.f90').write_text(diagnostic)
    for filename in ('swap.f90','swap_main.f90'):
        path=target/filename;assert h.sha(path)==identity['donor_generated'][filename]
        text=path.read_text(encoding='cp1252')
        text=instrument_source(text,filename,h.replace,a.drainage_snapshots or a.variables_snapshots,project.start_clock+524,a.micro_lookup_replay)
        path.write_text(text,encoding='cp1252')
    if a.reconnect_wofost_interface:
        path=target/'wofost.f90';assert h.sha(path)==identity['donor_generated']['wofost.f90']
        text=h.replace(path.read_text(encoding='cp1252'),'         r_act=hybrid_r_act',
            '         r_act=hybrid_r_act\n         call update_wofost_interface(s_pot,r_pot)\n         call update_wofost_interface(s_act,r_act)')
        path.write_text(text,encoding='cp1252')
    for filename in ('hybrid_state_diagnostic.f90',*(['wofost.f90'] if a.reconnect_wofost_interface else []),'swap.f90','swap_main.f90'):
        compile(['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c',filename])
    linked=[str(replacements.get(q.name,q)) for q in sorted(objects.glob('*.o'))]+[str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')]
    compile(['gfortran','-o',str(h.executable(target,'day_donor')),*linked,str(target/'hybrid_state_diagnostic.o')])
    records={}
    models=[('warm',h.ColumnStart(name='original'),525),('cold',h.ColumnStart(day=524,origin=origin,receipt=receipt,name='original'),1)]
    if a.micro_lookup_replay:models.append(('cold-restored',h.ColumnStart(day=524,origin=origin,receipt=receipt,name='original'),1))
    for label,start,last in models:
        model=out/label;model.mkdir();rows=[]
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(target,'day_donor'),h.executable(target,'day_kernel'),case,model,[start],runtime=True,checkpoint_enabled=True,project=project)
            if label=='cold-restored':shutil.copy2(out/'warm/original/hybrid-lookup-capture.bin',model/'original/hybrid-lookup-origin.bin')
            for _ in range(last):rows.append(host.step(1))
            host.close()
        assert not list(model.glob('accepted-*.zip'))
        records[label]=dict(last_row=rows[-1],snapshots=snapshots(model/'original/donor.stdout',inventory))
        if label=='warm':
            original_rows=[json.loads(s) for s in (prior/'water-history-O2-control/daily.jsonl').read_text().splitlines()][:525]
            assert list(map(physical,rows))==list(map(physical,original_rows))
    oldwarm=json.loads((prior/'water-history-O2-control/daily.jsonl').read_text().splitlines()[524])
    import zipfile
    with zipfile.ZipFile(next(p for p in (prior/'water-history-O2-everyday').rglob('accepted-column-1-day-525.zip') if '/warm/' not in p.as_posix())) as z:oldcold=json.loads(z.read('checkpoint.json'))['receipt']
    assert physical(records['warm']['last_row'])==physical(oldwarm)
    if not a.reconnect_wofost_interface:assert physical(records['cold']['last_row'])==physical(oldcold)
    target_label='cold-restored' if a.micro_lookup_replay else 'cold'
    exact=physical(records[target_label]['last_row'])==physical(records['warm']['last_row'])
    assert physical(oldwarm)!=physical(oldcold) and h.sha(source)==digest
    changes=[]
    warm={x['phase']:x for x in records['warm']['snapshots'] if x['clock']==project.start_clock+524}
    cold={x['phase']:x for x in records[target_label]['snapshots'] if x['clock']==project.start_clock+524}
    for phase in sorted(set(warm)&set(cold)):
        for name,before in warm[phase]['fields'].items():
            after=cold[phase]['fields'][name]
            if before!=after:changes.append(dict(phase=phase,field=name,changed_entries=sum(x!=y for x,y in zip(before,after)),maximum_absolute_difference=max(abs(float(x)-float(y)) for x,y in zip(before,after))))
    status=('PRIVATE_COMPLETE_WOFOST_INTERFACE_RECONNECT_PASS' if exact else 'PRIVATE_COMPLETE_WOFOST_INTERFACE_RECONNECT_FAIL') if a.reconnect_wofost_interface else 'READ_ONLY_ORIGINAL_WATER_HISTORY_MISMATCH_EXACTLY_REPRODUCED'
    if a.micro_lookup_replay:status='PRIVATE_COMPLETE_MICRO_LOOKUP_REPLAY_PASS' if exact else 'PRIVATE_COMPLETE_MICRO_LOOKUP_REPLAY_FAIL'
    result=dict(status=status,interface_reconnected=a.reconnect_wofost_interface,micro_lookup_replayed=a.micro_lookup_replay,cold_warm_physical_exact=exact,pinned_source=PIN,
        current_source=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),original_run=43836309698,
        origin_sha256=digest,origin_unchanged=True,no_publication=True,no_build_rebinding=True,
        original_executable_relink_exact=True,field_inventory=inventory,records=records,phase_differences=changes,
        private_sources={name:h.sha(target/name) for name in ('hybrid_state_diagnostic.f90','wofost.f90','swap.f90','swap_main.f90',*(['RWU_micro.f90'] if a.micro_lookup_replay else []))},
        private_executable_sha256=h.sha(h.executable(target,'day_donor')),
        scope='Read-only original component-state evidence, not current public qualification or demonstrated causation')
    if a.drainage_snapshots or a.variables_snapshots:
        result['complete_component_module']='MOD_cropdevelopment'
        result['complete_component_comparison']=drainage_comparison(out)
        result['whole_root_field_inventory']=root_fields
    if a.micro_lookup_replay:
        capture=out/'warm/original/hybrid-lookup-capture.bin'
        restored=out/'cold-restored/original/hybrid-lookup-restored.bin'
        assert capture.read_bytes()==restored.read_bytes()
        assert (out/'cold/original/hybrid-lookup-current.bin').read_bytes()==(out/'cold-restored/original/hybrid-lookup-current.bin').read_bytes()
        result['lookup_payloads']={label:h.sha(out/label/'original/hybrid-lookup-current.bin') for label in ('warm','cold','cold-restored')}
        result['lookup_payloads']['accepted_capture']=h.sha(capture)
        result['lookup_payloads']['restored']=h.sha(restored)
        result['lookup_header']=list(struct.unpack_from('<8sd6i',capture.read_bytes()))[1:]
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)
    if a.reconnect_wofost_interface or a.micro_lookup_replay:assert exact,'Complete original component replay did not reproduce warm physical state'

if __name__=='__main__':main()
