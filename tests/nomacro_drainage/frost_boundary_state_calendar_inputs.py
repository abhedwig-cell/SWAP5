"""Original Frost state/calendar decks with only their genuine lower boundary."""
from pathlib import Path
from datetime import date
import re
from frost_calendar_state_inputs import prepare as original
from original_output_baseline import assignment


def prepare(case, output):
    assert case['bottom'] in (5,8) and not (case['bottom']==8 and case['implicit'])
    calendar=case['calendar']
    original(case['kind'],case['hysteresis'],case['initial'],case['implicit'],
             'regular' if calendar=='dense' else calendar,output,
             reset=case['reset'],start=case['start'])
    path=Path(output)/'swap.swp';text=path.read_text(encoding='cp1252')
    text=assignment(text,'SWBOTB',case['bottom'])
    if calendar=='dense':text=assignment(text,'PERIOD',1)
    if case['bottom']==5 and not re.search(r'(?mi)^\s*DATE5\s+HBOT5',text):
        text+='\nDATE5 HBOT5\n2002-01-01 -100.0\n2004-12-31 -100.0\n* End of table\n'
    if case['bottom']==8 and not re.search(r'(?mi)^\s*HPLATE\s*=',text):
        text+='\nHPLATE = -50.0\n'
    if case['bottom']==5 and case['start'] is not None:
        # Shift the genuine varying head schedule with the existing shifted
        # irrigation schedule. The original reader requires an in-period row.
        offset=date.fromisoformat(case['start'])-date(2002,1,1)
        def shift_boundary(match):
            body,count=re.subn(r'(?m)^([ \t]*)([0-9]{4}-[0-9]{2}-[0-9]{2})(?=[ \t])',
                lambda row:row[1]+(date.fromisoformat(row[2])+offset).isoformat(),match[2])
            assert count>=1
            return match[1]+body+'* End of table'
        text,count=re.subn(r'(?mi)^([ \t]*DATE5[^\n]*\n)(.*?)^\* End of table',
                          shift_boundary,text,count=1,flags=re.S)
        assert count==1
    path.write_text(text,encoding='cp1252')
