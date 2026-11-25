"""Original Frost fixture with explicit bounded state and fitted-Ksat selectors."""
import re
from pathlib import Path
import frost_cde_drainage_runtime as runtime
from original_output_baseline import assignment


def prepare(kind,hysteresis,initial,implicit,output):
    assert kind in ('water','cde') and hysteresis in (0,1) and initial in (1,2) and implicit in (0,1)
    output=Path(output);runtime.thermal.fixture(output,'water-frost-drained',3)
    path=output/'swap.swp';text=path.read_text(encoding='cp1252')
    fields=dict(SWSOLU=int(kind=='cde'),SWHYST=hysteresis,SWINCO=initial)
    if implicit:fields.update(SWKIMPL=1,MAXIT=100,MAXBACKTR=10)
    for key,value in fields.items():text=assignment(text,key,value)
    if kind=='cde':text=assignment(text,'CPRE','0.01')
    if implicit:
        def fitted(match):
            names=match[1].split();rows=[]
            for line in match[2].splitlines():
                values=line.split();assert len(values)==len(names)
                values[names.index('KSATEXM')]=values[names.index('KSATFIT')]
                rows.append(' '.join(values))
            return match[1]+'\n'.join(rows)+'\n* End of table'
        text,count=re.subn(r'(?mi)^([ \t]*ORES[ \t]+OSAT[^\r\n]*\n)(.*?)^\* End of table',fitted,text,count=1,flags=re.S)
        assert count==1
    path.write_text(text,encoding='cp1252');path=output/'swap.dra'
    path.write_text(assignment(path.read_text(encoding='cp1252'),'SWDIVD',1),encoding='cp1252')
