"""Original boundary/drainage Frost decks; no implicit fixture substitution."""
from pathlib import Path
import re
from frost_analytical_inputs import prepare as analytical_inputs
from frost_undrained_state_inputs import prepare as original_model1_inputs
from original_output_baseline import assignment


def prepare(case,output):
    assert case['implicit']==case['hysteresis']==0
    assert (case['drainage']==0 and case['bottom']==6) or (case['drainage']==1 and case['bottom'] in (5,6,8))
    models=case['effective_models'];assert models and all(x in (1,3,4,5,6,7,8,9,10,11) for x in models)
    model1=all(x==1 for x in models);assert not model1 or case['drainage']==0 and case['bottom']==6
    base=dict(case,bottom=5 if case['bottom']==6 else case['bottom'],drainage=0,models=case['models'] or [1,1])
    (original_model1_inputs if model1 else analytical_inputs)(base,output)
    path=Path(output)/'swap.swp';text=path.read_text(encoding='cp1252')
    text=assignment(assignment(text,'SWBOTB',case['bottom']),'SWDRA',case['drainage'])
    if model1:
        pattern=r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*(?:\r?\n|$)'
        if not case['models']:
            text,count=re.subn(pattern,'',text);assert count in (0,1)
        else:
            value=' '.join(map(str,case['models']))
            text=assignment(text,'iHWCKmodel',value) if re.search(pattern,text) else text+'\niHWCKmodel = '+value+'\n'
    path.write_text(text,encoding='cp1252')
