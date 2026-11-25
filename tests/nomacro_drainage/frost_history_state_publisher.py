"""Read-only PE loader-relative byte comparison; no model imports."""
import hashlib
from pathlib import Path
import struct

def publisher_equivalence(before,after):
    """Compare loader-relative PE contents; retain both original byte identities."""
    left=before.read_bytes();right=after.read_bytes()
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

