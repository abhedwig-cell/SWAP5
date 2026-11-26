"""Original analytical, no-vapor decks for the bounded undrained Frost owner."""
from pathlib import Path
import re
from frost_undrained_state_inputs import prepare as original
from original_output_baseline import assignment


def prepare(case, output):
    assert case['implicit']==case['hysteresis']==case['drainage']==0
    models=case['models'];assert models and any(x!=1 for x in models)
    assert all(x in (1,3,4,5,6,7,8,9,10,11) for x in models)
    original(case,output)
    path=Path(output)/'swap.swp';text=path.read_text(encoding='cp1252')
    parameters=dict(iHWCKmodel=' '.join(map(str,models)),SWVAPOR='0 0',
        ALFA_2='.005 .003',NPAR_2='1.5 1.6',OMEGA_1='.8 .8',
        H0='-1e6 -1e6',HA='-10.0 -10.0',APAR='-1.5 -1.5',OMEGA_K='.01 .01')
    for key,value in parameters.items():
        text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+value+'\n'
    path.write_text(text,encoding='cp1252')
    for crop in Path(output).glob('*.crp'):
        text=assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',0)
        # Model3's original supported oxygen1 is an explicit physical fixture.
        # The original oxygen2 refusal is retained, never retried as a fallback.
        if 3 in models:text=assignment(text,'SWOXYGEN',1)
        crop.write_text(text,encoding='cp1252')
