"""Actual current source/native equivalence to retained complete calendar periods."""
import argparse
import io
import json
from pathlib import Path
import subprocess
import struct
import hashlib
import sys
import zipfile
import calendar_forensics as scientific
import extended_runtime as prior

m=prior.m;ROOT=prior.ROOT


def differences(before,after,prefix=''):
    if isinstance(before,dict) and isinstance(after,dict):
        assert set(before)==set(after),'Actual build identity keys changed'
        return [item for key in before for item in differences(before[key],after[key],prefix+'.'+key if prefix else key)]
    return [] if before==after else [prefix]


def publisher_equivalence(before,after):
    """Compare loader-relative PE contents; retain both original byte identities."""
    left=Path(before).read_bytes();right=Path(after).read_bytes()
    assert len(left)==len(right) and left[:2]==right[:2]==b'MZ','Changed publisher requires new implementation qualification'
    def fields(raw):
        pe=struct.unpack_from('<I',raw,60)[0];assert raw[pe:pe+4]==b'PE\0\0'
        sections=struct.unpack_from('<H',raw,pe+6)[0];optional=pe+24
        magic=struct.unpack_from('<H',raw,optional)[0];assert magic in (0x10b,0x20b)
        width=8 if magic==0x20b else 4;base_at=optional+(24 if width==8 else 28)
        base=struct.unpack_from('<Q' if width==8 else '<I',raw,base_at)[0]
        table=optional+struct.unpack_from('<H',raw,pe+20)[0]
        directory=optional+(112 if width==8 else 96)
        layout=[struct.unpack_from('<4I',raw,table+40*i+8) for i in range(sections)]
        def offset(rva):
            for virtual_size,virtual_address,raw_size,raw_at in layout:
                if virtual_address<=rva<virtual_address+max(virtual_size,raw_size):return raw_at+rva-virtual_address
            raise AssertionError('Foreign publisher RVA')
        metadata={(pe+8,4):'COFF link timestamp',(optional+64,4):'PE checksum',(base_at,width):'loader image base'}
        export_rva=struct.unpack_from('<I',raw,directory)[0]
        if export_rva:metadata[(offset(export_rva)+4,4)]='export link timestamp'
        reloc_rva,reloc_size=struct.unpack_from('<2I',raw,directory+40)
        relocations={};cursor=offset(reloc_rva);end=cursor+reloc_size
        while cursor<end:
            page,size=struct.unpack_from('<2I',raw,cursor);assert size>=8 and size%2==0 and cursor+size<=end
            for item in struct.unpack_from('<'+str((size-8)//2)+'H',raw,cursor+8):
                kind,delta=item>>12,item&4095
                if kind==0:continue
                assert kind in (3,10),'Unsupported publisher relocation'
                size_of=8 if kind==10 else 4;where=offset(page+delta)
                value=struct.unpack_from('<Q' if size_of==8 else '<I',raw,where)[0]
                relocations[(where,size_of)]=(value-base)%(1<<(8*size_of))
            cursor+=size
        return metadata,relocations,base
    lm,lr,lb=fields(left);rm,rr,rb=fields(right)
    assert lm==rm and lr==rr,'Publisher loader-relative code/data changed'
    allowed={i for at,size in [*lm,*lr] for i in range(at,at+size)}
    changes=[i for i,(a,b) in enumerate(zip(left,right)) if a!=b]
    assert all(i in allowed for i in changes),'Publisher bytes changed outside exact loader relocation/link metadata'
    return dict(status='ACTUAL_PE_LOADER_RELATIVE_CODE_DATA_EXACT',old_sha256=hashlib.sha256(left).hexdigest(),
                current_sha256=hashlib.sha256(right).hexdigest(),old_image_base=lb,current_image_base=rb,
                actual_relocations=len(lr),changed_byte_count=len(changes),changed_offsets=changes,
                original_bytes_modified=False,metadata_fields=[dict(offset=at,bytes=size,role=role) for (at,size),role in lm.items()])


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','prior-profile','prior-build','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--label',choices=('water','cde'),required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--existing-current',action='store_true')
    a=p.parse_args();old=json.loads((a.prior_profile/'RESULT.json').read_text())
    assert old['status']=='ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS' and old['parameters']['days']==1096
    previous=scientific.audit_root(a.prior_profile,a.prior_build)
    case,mode,fmt=('water','monthly',2) if a.label=='water' else ('automatic','daily',3)
    command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage/calendar_runtime.py'),'--case',case,'--mode',mode,'--format',str(fmt),
             '--days','35','--optimization',a.optimization,'--reference-work',str(a.reference_work),'--build-root',str(a.build_root),'--output',str(a.output)]
    if not a.existing_current:
        r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240)
        (a.output/'preservation.stdout').write_text(r.stdout);(a.output/'preservation.stderr').write_text(r.stderr);r.check_returncode()
    q=json.loads((a.output/'RESULT.json').read_text());build=Path(q['build_root'])
    current=json.loads((build/'BUILD.json').read_text());before=json.loads((a.prior_build/'BUILD.json').read_text())
    assert {path.name:path.read_bytes() for path in build.glob('*.f90')}=={path.name:path.read_bytes() for path in a.prior_build.glob('*.f90')},'Actual current generated Fortran changed'
    assert current['inputs']==before['inputs'] and current['project']==before['project']
    changed=differences(before['identity'],current['identity'])
    publisher=None
    if 'restart_publisher.library_sha256' in changed:
        old_dll=a.prior_build/'restart_publish.dll';current_dll=build/'restart_publish.dll'
        assert m.sha(old_dll)==before['identity']['restart_publisher']['library_sha256'] and m.sha(current_dll)==current['identity']['restart_publisher']['library_sha256']
        publisher=publisher_equivalence(old_dll,current_dll)
    assert set(changed)<= {'host','extended_drainage.source_sha256','restart_publisher.library_sha256'},changed
    rows=m.rows(a.output/'trajectory');old_rows=m.rows(a.prior_profile/'trajectory')
    assert m.physical(rows)==m.physical(old_rows[:35]),'Actual current35day physical prefix changed'
    for day in (2,4,14,17,30,35):
        with zipfile.ZipFile(a.output/f'trajectory/accepted-column-1-day-{day}.zip') as now,zipfile.ZipFile(a.prior_profile/f'trajectory/accepted-column-1-day-{day}.zip') as gold:
            assert all(now.read(name)==gold.read(name) for name in ('result.end','macro.bin')),'Actual current complete native prefix changed'
    current_science=scientific.audit_root(a.output)
    (a.output/'FORENSICS.json').write_text(json.dumps(current_science,indent=2)+'\n')
    result=dict(status='ACTUAL_CURRENT_CALENDAR_INPUT_FORTRAN_COMPILER_KERNEL_PHYSICAL_NATIVE_EQUIVALENCE_PASS',
                label=a.label,optimization=a.optimization,current_source=q['source'],prior_source=old['source'],
                prior_profile=str(a.prior_profile),prior_build=str(a.prior_build),actual_days=35,fresh_unaffected_full_periods=0,
                exact_inputs=True,exact_generated_fortran=True,exact_compiler_kernel_provider_identity_except_recorded_source_roles=True,
                changed_identity_source_roles=changed,exact_physical_prefix=True,exact_prior_native_days=[2,4,14,17,30,35],
                publisher=publisher,new_model_executions_in_this_comparison=0 if a.existing_current else 1,
                prior_full_independent_science=previous,current_independent_science=current_science)
    (a.output/'PRESERVATION.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],a.label,a.optimization)


if __name__=='__main__':main()
