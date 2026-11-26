"""Same28 actual day-ledger terms, with a distinct strict drainage-off domain."""
from pathlib import Path


def source(original=None):
    from frost_calendar_terminal_water import source as day_source
    text=day_source(original)
    edits=[('    use MOD_swap_base, only: swmacro, swsnow, swdra',
            '    use MOD_swap_base, only: swmacro, swsnow, swdra, swfrost'),
           ("    if(swmacro/=0.or.swsnow/=1.or.swdra/=1)error stop 'Unsupported terminal water receipt domain'",
            "    if(swmacro/=0.or.swsnow/=1.or.swfrost/=1.or.swdra/=0)error stop 'Unsupported undrained Frost terminal water receipt domain'")]
    for before,after in edits:
        if text.count(before)!=1:raise ValueError('Foreign original Frost terminal day receipt')
        text=text.replace(before,after,1)
    return text


def install(output):
    path=Path(output)/'terminal_water_receipt.f90'
    path.write_text(source(path.read_bytes()),encoding='cp1252')
