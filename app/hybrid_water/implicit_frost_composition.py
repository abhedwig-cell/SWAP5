"""Candidate existing implicit/Snow/Frost/drainage composition; not admitted."""
import hashlib
from pathlib import Path

POLICY = 'original-implicit-frost-fitted-surface-daily-drainage-v1'


def input_domain(selectors, boundary, original_output):
    required = dict(SWMACRO=0, SWKIMPL=1, SWFROST=1, SWSNOW=1, SWHYST=2,
                    SWDRA=1, SWHEA=1, SWCALT=2, SWSOPHY=0, SWBR=0, SWMETDETAIL=0)
    return bool(original_output is not False and selectors.get('SWSOLU') in (0, 1)
                and boundary.get('SWBOTB') == 6
                and all(selectors.get(k) == v for k, v in required.items()))


def enabled(project):
    from frost_drainage_composition import enabled as common
    if not common(project): return False
    from experimental_project import switches
    selectors = switches((Path(project.input_directory) / 'swap.swp').read_text(encoding='cp1252'))
    # The full public reader additionally owns boundary-file resolution,
    # effective SWDIVD1, original dense thermal output and the parameter table.
    return selectors.get('SWKIMPL') == 1


def source_identity():
    return dict(implicit_frost_composition=True, implicit_frost_policy=POLICY,
        implicit_frost_composition_source_sha256=hashlib.sha256(
            Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest())


def codec(project):
    return b'S5FIC001' if project.solute else b'S5FIW001'


def metadata(project):
    if not enabled(project): return None
    folder = Path(__file__).parent
    providers = ['implicit_frost_composition.py', 'implicit_frost_surface_conductivity.py',
                 'frost_drainage_composition.py', 'frost_divdra_overlap.py',
                 'ordinary_implicit_pond_switch.py', 'ordinary_implicit_pond_tangent.py',
                 'extended_implicit_pond.py']
    if project.solute: providers.append('snow_undrained_cde_positive.py')
    sha = lambda p: hashlib.sha256(p.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
    return dict(policy=POLICY, providers={name: sha(folder/name) for name in providers},
        correction='FROST-DIVDRA-OVERLAP-01', native_codec=codec(project).decode(),
        fixed_SWKIMPL=1, fixed_SWDIVD=1, examined_ksat_interpolation=False,
        new_physical_state=False, physical_equations_changed=False,
        chemical_positive_mass_policy='original-cde-preserve-positive-cell-mass-v1' if project.solute else None)


def apply_build(output, project, patched):
    if not enabled(project): return patched
    from implicit_frost_surface_conductivity import source, validate
    path = output/'headcalc.f90'; original = path.read_text(encoding='cp1252')
    actual = source(original); validate(actual, original)
    path.write_text(actual, encoding='cp1252')
    return patched


def validate(bundle, project):
    if not enabled(project): return
    from implicit_frost_surface_conductivity import restore
    # Generic bundle admission has already bound the complete generated source
    # and executable. Also require the exact inverse of the selected new seam.
    restore((bundle/'headcalc.f90').read_text(encoding='cp1252'))
