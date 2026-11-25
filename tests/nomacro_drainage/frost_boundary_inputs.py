"""Original Frost donor inputs with only selected lower-boundary configuration."""
import re
from pathlib import Path
from frost_history_state_inputs import prepare as parent
from original_output_baseline import assignment


def prepare(kind, implicit, bottom, output):
    assert kind in ('water', 'cde') and implicit in (0, 1) and bottom in (5, 8)
    parent(kind, 1, 2, implicit, output)
    path=Path(output)/'swap.swp';text=path.read_text(encoding='cp1252')
    text=assignment(assignment(text,'SWHYST',2),'SWBOTB',bottom)
    if bottom==5 and not re.search(r'(?mi)^\s*DATE5\s+HBOT5',text):
        text+='\nDATE5 HBOT5\n2002-01-01 -100.0\n2004-12-31 -100.0\n* End of table\n'
    if bottom==8 and not re.search(r'(?mi)^\s*HPLATE\s*=',text):
        text+='\nHPLATE = -50.0\n'
    path.write_text(text,encoding='cp1252')
