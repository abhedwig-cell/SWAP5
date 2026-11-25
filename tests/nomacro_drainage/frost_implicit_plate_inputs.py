"""Original implicit Frost decks; only the real plate boundary is selected."""
from pathlib import Path
import re
from frost_calendar_state_inputs import prepare as calendar_inputs
from frost_boundary_inputs import prepare as dense_inputs
from original_output_baseline import assignment


def prepare(case,output):
    assert case['bottom']==8 and case['implicit']==1
    if case['calendar']=='parent-dense':
        assert case['hysteresis']==case['initial']==2 and case['days']==35
        dense_inputs(case['kind'],1,8,output)
        return
    assert case['hysteresis'] in (0,1)
    calendar_inputs(case['kind'],case['hysteresis'],case['initial'],1,
        'regular' if case['calendar']=='dense' else case['calendar'],output,
        reset=case['reset'],start=case['start'])
    path=Path(output)/'swap.swp';text=path.read_text(encoding='cp1252')
    text=assignment(text,'SWBOTB',8)
    if case['calendar']=='dense':text=assignment(text,'PERIOD',1)
    if not re.search(r'(?mi)^\s*HPLATE\s*=',text):text+='\nHPLATE = -50.0\n'
    path.write_text(text,encoding='cp1252')
