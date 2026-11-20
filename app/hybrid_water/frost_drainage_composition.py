"""Candidate explicit Frost/SWDIVD1 water/CDE composition; not admitted."""
import hashlib
from pathlib import Path

POLICY = 'original-explicit-frost-divdra-overlap-daily-composition-v1'


def enabled(project):
    if not project.input_directory or project.macro or project.age or not project.original_output:
        return False
    from experimental_project import switches, one
    folder = Path(project.input_directory)
    text = (folder / 'swap.swp').read_text(encoding='cp1252')
    selected = switches(text)
    if selected.get('SWFROST') != 1 or selected.get('SWDRA') != 1:
        return False
    name = one(text, 'DRFIL', r"'[^']+'").strip("'")
    prefix = one(text, 'PATHDRAIN', r"'[^']*'").strip("'").strip()
    return switches((folder / (prefix + name + '.dra')).read_text(encoding='cp1252')).get('SWDIVD') == 1


def codec(project):
    return b'S5FDC001' if project.solute else b'S5FDW001'


def metadata(project):
    if not enabled(project): return None
    folder = Path(__file__).parent
    sha = lambda p: hashlib.sha256(p.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
    providers = ['frost_drainage_composition.py', 'frost_divdra_overlap.py']
    if project.solute: providers.append('snow_undrained_cde_positive.py')
    return dict(policy=POLICY, providers={name: sha(folder / name) for name in providers},
        correction='FROST-DIVDRA-OVERLAP-01', native_codec=codec(project).decode(),
        fixed_SWKIMPL=0, fixed_SWDIVD=1, new_physical_state=False,
        chemical_positive_mass_policy='original-cde-preserve-positive-cell-mass-v1' if project.solute else None)


def apply_build(output, donor_build, project, patched):
    if not enabled(project): return patched
    import frost_divdra_overlap
    original = (donor_build / 'swap-selected/divdra.f90').read_bytes()
    (output / 'divdra.f90').write_text(frost_divdra_overlap.source(original), encoding='cp1252')
    if 'divdra' in patched: raise ValueError('Multiple actual Divdra source owners')
    patched.insert(0, 'divdra')
    if project.solute:
        from snow_undrained_cde_positive import source
        path = output / 'solute.f90'
        path.write_text(source(path.read_text(encoding='cp1252')), encoding='cp1252')
    return patched


def validate(bundle, reference, project, identity):
    expected = metadata(project)
    if identity.get('frost_drainage_composition') != expected:
        raise ValueError('Foreign explicit Frost drainage composition policy')
    if expected is None: return
    import frost_divdra_overlap
    original = (reference / 'build/swap-selected/divdra.f90').read_bytes()
    if (bundle / 'divdra.f90').read_text(encoding='cp1252') != frost_divdra_overlap.source(original):
        raise ValueError('Foreign actual corrected Divdra source')
    if project.solute:
        text = (bundle / 'solute.f90').read_text(encoding='cp1252')
        if text.count('               if (cmsy(i) <= 0d0) then') != 1 or '               if (cmsy(i) < vsmall) then' in text:
            raise ValueError('Foreign actual positive CDE cell-mass predicate')

# Actual wrong-source control; never merge.
