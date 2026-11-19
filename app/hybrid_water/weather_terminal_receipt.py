"""Read-only complete terminal receipt for bounded original detailed weather."""
import hashlib
from pathlib import Path

POLICY = 'original-detailed-weather-complete-terminal-water-receipt-v1'
MODULE = 'hybrid_weather_terminal_receipt'


def enabled(project):
    if not project.input_directory or project.macro or not project.solute or project.original_output:
        return False
    from experimental_project import inspect
    from daily_host import ORIGINAL_TIME_POLICY
    if project.time_step_policy != ORIGINAL_TIME_POLICY:
        return False
    report = inspect(project.input_directory)
    s = report['selectors']
    required = dict(SWMACRO=0, SWSOLU=1, SWSOPHY=0, SWHYST=0, SWSNOW=0,
                    SWFROST=0, SWKIMPL=0, SWDRA=1, SWHEA=1, SWCALT=2)
    return (all(s.get(k) == v for k, v in required.items())
            and s.get('SWBR', 0) == 0 and report['boundary']['SWBOTB'] == 6
            and (s['SWMETDETAIL'] == 1 or s['SWRAIN'] == 3))


def source():
    # Reuse the existing complete terminal receipt. Inactive snow rates and
    # stocks are not read; its existing cumulative zero terms remain literal.
    text = Path(__file__).with_name('terminal_water_receipt.f90').read_text(encoding='cp1252')
    edits = (
        ('hybrid_terminal_water_receipt', MODULE),
        ('    use MOD_snow, only: gsnow,snrai,subl,ssnow\n', ''),
        ('    real(8), intent(out) :: terms(28)',
         '    use ieee_arithmetic,only:ieee_is_finite\n    real(8), intent(out) :: terms(28)'),
        ("if(swmacro/=0.or.swsnow/=1.or.swdra/=1)error stop 'Unsupported terminal water receipt domain'",
         "if(swmacro/=0.or.swsnow/=0.or.swdra/=1)error stop 'Unsupported weather terminal receipt domain'"),
        ('isnrai+snrai*dt,igsnow+gsnow*dt', 'isnrai,igsnow'),
        ('isubl+subl*dt', 'isubl'),
        ('sum(theta(1:numnod)*dz(1:numnod)),pond,ssnow,canopy',
         'sum(theta(1:numnod)*dz(1:numnod)),pond,0d0,canopy'),
        ('  end subroutine',
         "    if(.not.all(ieee_is_finite(terms)))error stop 'Nonfinite weather terminal water receipt'\n  end subroutine"),
        ('    residual=real(sum(real(terms,real128)),8)',
         "    residual=real(sum(real(terms,real128)),8)\n"
         "    write(*,'(a,29(1x,es25.17e3))') 'WEATHER_TERMINAL_WATER',residual,terms"),
    )
    for old, new in edits:
        assert text.count(old) == 1, old
        text = text.replace(old, new)
    return text


def metadata(project):
    if not enabled(project):
        return None
    return dict(policy=POLICY, source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                template_sha256=hashlib.sha256(Path(__file__).with_name('terminal_water_receipt.f90').read_bytes()).hexdigest(),
                water_guard_cm=1e-10, physical_equations_changed=False,
                ownership='Read-only original cumulative water receipt before terminal trial acceptance')


def apply_build(output, project, patched):
    if not enabled(project):
        return patched
    (output / (MODULE + '.f90')).write_text(source(), encoding='cp1252')
    path = output / 'headcalc.f90'
    text = path.read_text(encoding='cp1252')
    old = '   use hybrid_step_budget, only: projected_water_residual'
    assert text.count(old) == 1
    text = text.replace(old, '   use ' + MODULE + ',only:terminal_water_residual\n'
                        '   use variables,only:tcum\n' + old, 1)
    old = '         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
    assert text.count(old) == 1
    text = text.replace(old, old + '\n'
                        '         if(tcum+dt>=1d0-1d-8)then\n'
                        '            if(abs(terminal_water_residual())>1d-10)flnonconv=.true.\n'
                        '         end if', 1)
    path.write_text(text, encoding='cp1252')
    return [MODULE, *patched]
