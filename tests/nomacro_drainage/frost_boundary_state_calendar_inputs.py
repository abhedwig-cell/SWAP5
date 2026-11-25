"""Original Frost state/calendar decks with only their genuine lower boundary."""
from pathlib import Path
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
    path.write_text(text,encoding='cp1252')
