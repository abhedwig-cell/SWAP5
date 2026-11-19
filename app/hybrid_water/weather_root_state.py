"""Original previous-trial root stress carry for bounded hourly weather.

Integral uses these saved factors during zero-demand hours without recomputing
them. They affect root extension even when the first cold water ledger is exact.
No uptake law, root factor, root depth or original input is recalculated here.
"""
import hashlib
import math
from pathlib import Path
import struct

MAGIC = b'S5WRH001'
MODULE = 'hybrid_weather_root_state'
SIZE = 108
POLICY = 'original-hourly-root-stress-carry-v1'


def enabled(project):
    from weather_terminal_receipt import enabled as terminal
    if not terminal(project):
        return False
    from experimental_project import inspect
    s = inspect(project.input_directory)['selectors']
    return s['SWMETDETAIL'] == 1 and s['SWCFBS'] == 0


def domain(project):
    return [1, project.nodes, 0, 1, 0, 0, 6, 1]


def metadata(project):
    if not enabled(project):
        return None
    return dict(policy=POLICY, source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                codec=MAGIC.decode(), domain=domain(project), bytes=SIZE,
                fields=['MOD_re_global.alpwetnoddrz', 'MOD_re_global.alpdrynodrtz'],
                ownership='Original saved root stress; immutable carry, no new physical store')


def validate_candidate(raw, receipt, project):
    if not enabled(project):
        return
    if len(raw) < SIZE + 48 or raw[:8] != MAGIC:
        raise ValueError('Foreign hourly root stress native codec')
    first, second = struct.unpack_from('<8i', raw, len(raw)-SIZE), struct.unpack_from('<8i', raw, len(raw)-SIZE+32)
    if list(first) != domain(project) or first != second:
        raise ValueError('Foreign hourly root stress domain')
    clock, wet, dry, wet_copy, dry_copy, size = struct.unpack_from('<5di', raw, len(raw)-44)
    if (size != SIZE or not all(map(math.isfinite, (clock, wet, dry)))
            or clock != project.start_clock + receipt.get('day', -1)
            or not 0 <= wet <= 1 or not 0 <= dry <= 1
            or (wet, dry) != (wet_copy, dry_copy)
            or [wet, dry] != receipt.get('weather_root_memory')):
        raise ValueError('Hourly root stress native carry differs from accepted receipt')


def source(project):
    values = ','.join(map(str, domain(project)))
    return f'''module {MODULE}
use ieee_arithmetic,only:ieee_is_finite
implicit none
private
public::weather_root_checkpoint,weather_root_apply,weather_root_witness
logical,save::pending=.false.
real(8),save::saved(2)=0d0,saved_clock=0d0
contains
subroutine weather_root_checkpoint(unit,restoring)
use variables,only:t1900
use MOD_re_global,only:alpwetnoddrz,alpdrynodrtz
integer,intent(in)::unit
logical,intent(in)::restoring
integer::header(8),copy(8),trailer,ios
real(8)::clock,values(2),witness(2)
if(restoring)then
 read(unit,iostat=ios)header,copy,clock,values,witness,trailer
 if(ios/=0)error stop 'Incomplete hourly root stress carry'
else
 header=[{values}];copy=header;clock=t1900
 values=[alpwetnoddrz,alpdrynodrtz];witness=values;trailer={SIZE}
end if
if(any(header/=[{values}]).or.any(header/=copy).or.trailer/={SIZE}) &
 error stop 'Foreign hourly root stress domain'
if(.not.ieee_is_finite(clock).or.clock/=t1900)error stop 'Foreign hourly root stress clock'
if(.not.all(ieee_is_finite(values)).or.any(values<0d0).or.any(values>1d0).or.any(values/=witness)) &
 error stop 'Invalid hourly root stress values'
if(restoring)then
 saved=values;saved_clock=clock;pending=.true.
else
 write(unit)header,copy,clock,values,witness,trailer
end if
end subroutine
subroutine weather_root_apply()
use variables,only:t1900
use MOD_re_global,only:alpwetnoddrz,alpdrynodrtz
if(.not.pending)return
if(t1900/=saved_clock)error stop 'Stale hourly root stress restoration'
alpwetnoddrz=saved(1);alpdrynodrtz=saved(2);pending=.false.
end subroutine
subroutine weather_root_witness()
use variables,only:t1900
use MOD_re_global,only:alpwetnoddrz,alpdrynodrtz
write(*,'(a,3(1x,es25.17e3))') 'WEATHER_ROOT_MEMORY',t1900,alpwetnoddrz,alpdrynodrtz
end subroutine
end module
'''


def apply_build(output, project, patched):
    if not enabled(project):
        return patched
    (output/(MODULE+'.f90')).write_text(source(project), encoding='cp1252')
    path = output/'macropore.f90'
    text = path.read_text(encoding='cp1252')
    begin = text.index('    subroutine hybrid_macro_checkpoint(')
    end = text.index('    end subroutine hybrid_macro_checkpoint', begin)
    body = text[begin:end]
    assert body.count("'S5HUP012'") == 2
    body = body.replace("'S5HUP012'", "'"+MAGIC.decode()+"'")
    old = '      use MOD_grid, only: numnod'
    assert body.count(old) == 1
    body = body.replace(old, '      use '+MODULE+',only:weather_root_checkpoint\n'+old, 1)
    old = '        read(unit,iostat=ios) trailing'
    assert body.count(old) == 1
    body = body.replace(old, '        call weather_root_checkpoint(unit,.true.)\n'+old, 1)
    old = '      end if\n      close(unit)'
    assert body.count(old) == 1
    body = body.replace(old, '        call weather_root_checkpoint(unit,.false.)\n'+old, 1)
    path.write_text(text[:begin]+body+text[end:], encoding='cp1252')
    path = output/'swap.f90'
    text = path.read_text(encoding='cp1252')
    old = 'use MOD_wofost,only:hybrid_apply_wofost'
    assert text.count(old) == 1
    text = text.replace(old, 'use '+MODULE+',only:weather_root_apply\n'+old, 1)
    old = '         call hybrid_apply_wofost(fl_cropemergence)'
    assert text.count(old) == 1
    text = text.replace(old, old+'\n         call weather_root_apply()', 1)
    path.write_text(text, encoding='cp1252')
    path = output/'swap_main.f90'
    text = path.read_text(encoding='cp1252')
    old = 'use MOD_grid, only: numnod'
    assert text.count(old) == 1
    text = text.replace(old, 'use '+MODULE+',only:weather_root_witness\n'+old, 1)
    lines = text.splitlines(keepends=True)
    assert sum("'HYBRID_HYDRAULIC'" in line for line in lines) == 2
    text = ''.join(line+('   call weather_root_witness()\n' if "'HYBRID_HYDRAULIC'" in line else '') for line in lines)
    path.write_text(text, encoding='cp1252')
    return [MODULE, *patched]
