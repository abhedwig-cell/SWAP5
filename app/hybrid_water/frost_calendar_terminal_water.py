"""Project the existing terminal trial on its actual day receipt, not an interval."""
import hashlib,re
from pathlib import Path

BASE_SHA='dc491e5faa9c7ca8e0e1e2a573cac965cb2e7f790d1cb6ad89ab82e7b90a6540'
PARENT=Path(__file__).with_name('terminal_water_receipt.f90')
IMPORT='''    use MOD_integral, only: igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup, &
      iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iqbdo'''
VARIABLES='''    use variables, only: theta,pond,dt,runon,runots,qbot,epd,reva, &
      ivolbeg,ipondbeg,issnowbeg,isicbeg'''


def source(original=None):
    raw=PARENT.read_bytes() if original is None else original
    raw=raw.replace(b'\r\n',b'\n')
    if hashlib.sha256(raw).hexdigest()!=BASE_SHA:raise ValueError('Changed complete original terminal water receipt')
    text=raw.decode('cp1252')
    edits=[(IMPORT,'    use hybrid_age_output_state, only: hybrid_output_frame'),
           (VARIABLES,'    use variables, only: theta,pond,dt,runon,runots,qbot,epd,reva'),
           ('    ssdi=iqssdi',"    if(.not.hybrid_output_frame%active)error stop 'Missing actual original day receipt for Frost terminal trial'\n    ssdi=iqssdi")]
    for before,after in edits:
        if text.count(before)!=1:raise ValueError('Changed original terminal day projection anchor')
        text=text.replace(before,after,1)
    flows=('igrai','isnrai','igsnow','igird','irunon','iqssdi','iqbup','iintc','iruno','iqrot','iepd','ievap','isubl','iqdra')
    slots=dict(zip(flows,range(1,15)));slots['iqbdo']=16
    for name,slot in slots.items():
        text,count=re.subn(r'\b'+name+r'\b','hybrid_output_frame%flow_cm('+str(slot)+')',text)
        if count<1:raise ValueError('Missing original terminal flow projection '+name)
    for name,slot in [('ivolbeg',1),('ipondbeg',2),('issnowbeg',3),('isicbeg',4)]:
        text,count=re.subn(r'\b'+name+r'\b','hybrid_output_frame%start_stock_cm('+str(slot)+')',text)
        if count!=1:raise ValueError('Changed original terminal start stock projection '+name)
    return text


def install(output):
    path=Path(output)/'terminal_water_receipt.f90'
    path.write_text(source(path.read_bytes()),encoding='cp1252')
