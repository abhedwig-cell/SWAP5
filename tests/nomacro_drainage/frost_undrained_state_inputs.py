"""Genuine original Frost decks with their requested drainage switch off."""
from pathlib import Path
from frost_boundary_state_calendar_inputs import prepare as explicit_inputs
from frost_implicit_hys2_inputs import prepare as implicit_inputs
from original_output_baseline import assignment


def prepare(case,output):
    if case['drainage']!=0:raise ValueError('Foreign undrained Frost input domain')
    (implicit_inputs if case['implicit'] else explicit_inputs)(case,output)
    path=Path(output)/'swap.swp';text=path.read_text(encoding='cp1252')
    path.write_text(assignment(text,'SWDRA',0),encoding='cp1252')
