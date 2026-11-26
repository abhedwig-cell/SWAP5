"""Genuine original HYS2 boundary/calendar decks and changed old implicit5."""
from pathlib import Path
import re
from frost_boundary_inputs import prepare as dense_inputs
from frost_boundary_state_calendar_inputs import prepare as head_inputs
from frost_calendar_state_inputs import prepare as calendar_inputs
from original_output_baseline import assignment


def prepare(case,output):
    assert case['bottom'] in (5,8) and case['implicit']==1
    if case['calendar']=='parent-dense':
        assert case['hysteresis']==case['initial']==2 and case['days']==35
        dense_inputs(case['kind'],1,case['bottom'],output);return
    if case['bottom']==5:
        head_inputs(case,output);return
    calendar_inputs(case['kind'],case['hysteresis'],case['initial'],1,
        'regular' if case['calendar']=='dense' else case['calendar'],output,
        reset=case['reset'],start=case['start'])
    p=Path(output)/'swap.swp';text=assignment(p.read_text(encoding='cp1252'),'SWBOTB',8)
    if case['calendar']=='dense':text=assignment(text,'PERIOD',1)
    if not re.search(r'(?mi)^\s*HPLATE\s*=',text):text+='\nHPLATE = -50.0\n'
    p.write_text(text,encoding='cp1252')
