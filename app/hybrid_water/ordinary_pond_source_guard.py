"""Read-only complete HeadCalc identity for the qualified ordinary source forms.

These are actual B96 numeric compiler postimages, shared across O0/O2. The
project and existing native/output metadata independently select the form.
No field in the caller's mutable donor-generated hash inventory authorizes it.
"""
import hashlib
from pathlib import Path

HEADS = {
    'groundwater': 'a13d2e813001ff1d366cca902c8384a4347e00627a4996fb5ed5f7a612fde4f9',
    'cde': '8564da21cbc664908d9f0faa78e2a32da3422e72b16d9d23a1cda8ef12a97d08',
    'cde-step': '0d5c03b9de4748cdff7b734ead3d4b2147e65464410cdd9f9e22ffda1097249a',
    'water-step': 'f20a1f5e12c3d206d962f49491398b160328bc992fe60594750812b8a40898c3',
    'water': '1ba937ea6db926f0a91d985c9e9db386ae8322e3ed253b81ff6bf82566c73150',
}


def validate(bundle, project, identity):
    if not identity.get('ordinary_implicit_pond_switch'):
        return
    from experimental_project import inspect
    report = inspect(project.input_directory)
    if report['boundary']['SWBOTB'] == 1:
        if identity['original_output'].get('groundwater_cde_clock'):
            from groundwater_cde_clock_source_guard import validate as validate_groundwater_clock
            return validate_groundwater_clock(bundle,identity)
        form = 'groundwater'
    else:
        step = identity['original_output'].get('flprintdt')
        if type(step) is not bool:
            raise ValueError('Foreign ordinary implicit original output source form')
        form = ('cde' if project.solute else 'water')+('-step' if step else '')
    source = (Path(bundle)/'headcalc.f90').read_bytes().replace(b'\r\n', b'\n')
    if report['boundary']['SWBOTB'] == 5:
        # Invert only the literal admitted prescribed-head receipt projection.
        # The whole numerical body must still equal the qualified air-boundary
        # parent below; no generated/candidate hash authorizes a provider.
        from groundwater_snow_retry import inverse
        from lower_boundary_receipt import render_headcalc
        template=('logical                          :: flboth, flok\n'
                  '         budget_step=projected_water_residual()\n'
                  '            budget_step = projected_water_residual()\n')
        source=render_headcalc(inverse(source.decode('cp1252'),
            lambda text:render_headcalc(text,5),template),8).encode('cp1252')
    if hashlib.sha256(source).hexdigest() != HEADS[form]:
        raise ValueError('Foreign actual ordinary implicit coupled HeadCalc provider')
