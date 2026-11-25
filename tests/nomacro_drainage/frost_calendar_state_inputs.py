"""Original bounded Frost inputs with genuine requested calendar selectors."""
from pathlib import Path
from datetime import date
import re
from frost_history_state_inputs import prepare as original
from original_output_baseline import assignment


def prepare(kind,hysteresis,initial,implicit,calendar,output,*,reset=1,start=None):
    assert hysteresis in (0,1,2) and calendar in ('regular','monthly','dates') and reset in (0,1)
    original(kind,min(hysteresis,1),initial,implicit,output)
    path=Path(output)/'swap.swp';text=path.read_text(encoding='cp1252')
    fields=dict(SWHYST=hysteresis,NPRINTDAY=1,SWMONTH=int(calendar=='monthly'),SWODAT=int(calendar=='dates'),
                PERIOD=0 if calendar=='dates' else 7 if calendar=='regular' else 1,SWRES=reset)
    if start is not None:fields['TSTART']=start
    for key,value in fields.items():text=assignment(text,key,value)
    if start is not None:
        offset=date.fromisoformat(start)-date(2002,1,1)
        def irrigation(match):
            body=match[2]
            def shift(row):return row[1]+(date.fromisoformat(row[2])+offset).isoformat()
            body,count=re.subn(r'(?m)^([ \t]*)([0-9]{4}-[0-9]{2}-[0-9]{2})(?=[ \t])',shift,body)
            assert count>=1
            return match[1]+body+'* End of table'
        text,count=re.subn(r'(?mi)^([ \t]*IRDATE[^\n]*\n)(.*?)^\* End of table',irrigation,text,count=1,flags=re.S)
        assert count==1
    if calendar=='dates':
        dates=['2002-01-31','2002-02-02','2002-02-05','2002-12-31','2003-01-01','2004-12-31']
        text,count=re.subn(r'(?mi)^([ \t]*OUTDATINT[ \t]*=[ \t]*\n).*?^\* End of table',
                           lambda match:match[1]+'\n'.join(dates)+'\n* End of table',text,count=1,flags=re.S)
        assert count==1
    path.write_text(text,encoding='cp1252')
