"""Immutable original implicit-conductivity policy; no physical equations."""
import hashlib
import math
from pathlib import Path
import re

POLICY = 'original-headcalc-implicit-mualem-exact-boundary-strict-retry-v1'


def selection(text, selectors, boundary, *, original_output=None):
    if selectors['SWKIMPL'] == 0:
        return None
    from implicit_snow_composition import input_domain,source_identity
    from implicit_frost_composition import input_domain as frost_domain, source_identity as frost_identity
    frost=frost_domain(selectors,boundary,original_output)
    snow=input_domain(selectors,boundary,original_output) or frost
    required = dict(SWMACRO=0, SWSOPHY=0, SWSNOW=int(snow), SWFROST=int(frost),
                    SWHEA=1, SWCALT=2, SWMETDETAIL=0)
    if (selectors['SWKIMPL'] != 1 or any(selectors.get(k) != v for k, v in required.items())
            or selectors.get('SWBR', 0) != 0 or not (boundary['SWBOTB'] in (1,5,8)
                or boundary['SWBOTB']==6 and selectors.get('SWDRA') in (0,1,2))):
        raise ValueError('Original implicit conductivity requires bounded analytical daily no-snow/no-frost/no-aquifer inputs')
    active = '\n'.join(line.split('!', 1)[0].strip() for line in text.splitlines()
                       if line.strip() and not line.lstrip().startswith('*'))
    if re.search(r'(?i)\bSWAP_SOILS_DB\b', active):
        raise ValueError('Implicit conductivity soil database requires separate parameter-domain qualification')
    from implicit_hydraulic_state import input_models
    composed_models=input_models(text,selectors,boundary,original_output)
    models = re.findall(r'(?mi)^IHWCKMODEL\s*=\s*(.*)$', active)
    remainder = re.sub(r'(?mi)^IHWCKMODEL\s*=\s*[^\r\n]*$', '', active)
    if (re.search(r'(?i)\bIHWCKMODEL\b', remainder) or len(models) > 1
            or models and not re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*', models[0]) and composed_models is None):
        raise ValueError('Original implicit conductivity requires default Mualem model1')
    # Read the actual original named parameter table. Original TTUTIL remains
    # authoritative for numeric ranges; this guard excludes its unsupported
    # examined-Ksat derivative branch before starting a worker.
    tables = re.findall(r'(?mi)^\s*(ORES\s+OSAT[^\r\n]*)\r?\n((?:\s*[+\-.\d][^\r\n]*\r?\n)+)', active+'\n')
    if len(tables) != 1:
        raise ValueError('Implicit conductivity requires one explicit original Mualem parameter table')
    header, body = tables[0]
    names = header.upper().split()
    required_columns={'ORES','OSAT','ALFA','NPAR','LEXP','H_ENPR'}
    if selectors['SWHYST']>0:required_columns.add('ALFAW')
    if len(set(names)) != len(names) or not required_columns <= set(names):
        raise ValueError('Ambiguous implicit conductivity parameter columns')
    fitted = 'KSATFIT' if 'KSATFIT' in names else 'KSAT'
    if fitted not in names:
        raise ValueError('Missing original fitted conductivity')
    rows = []
    for line in body.splitlines():
        values = [float(v.replace('D','e').replace('d','e')) for v in line.split()]
        if len(values) != len(names) or not all(math.isfinite(v) for v in values):
            raise ValueError('Invalid implicit conductivity parameter row')
        row = dict(zip(names, values))
        # Literal original dhconduc's Gardner branch returns before the
        # examined-Ksat branch; do not reject its inactive measured Ksat.
        gardner=(composed_models is not None and len(rows)<len(composed_models) and composed_models[len(rows)]==2)
        if not gardner and 'KSATEXM' in row and row['KSATEXM'] > row[fitted]:
            raise ValueError('Original implicit derivative does not implement examined-Ksat interpolation')
        rows.append(row)
    if not rows:
        raise ValueError('Missing implicit conductivity parameter rows')
    return dict(policy=POLICY, SWKIMPL=1, SWKMEAN=selectors['SWKMEAN'],
                **(dict(hydraulic_models=composed_models,implicit_hydraulic_state_composition=True)
                   if composed_models is not None else dict(hydraulic_model=1)), original_parameter_rows=rows,
                examined_ksat_interpolation=False, physical_state_owner='existing-selected-owner',
                newton_failure_policy='original-implicit-nonconverged-trial-retry-v1',
                dtmin_retry_policy='below-input-minimum-only-after-actual-nonconvergence',clock_ulp_floor=8,
                boundary_jacobian_policy='original-implicit-exact-boundary-jacobian-v1',
                pond_event_policy='original-implicit-pond-depletion-event-v1',
                root_finalization_policy='original-implicit-complete-dry-end-final-root-evaluation-v2',
                pond_availability_policy='original-implicit-pond-evaporation-availability-v1',
                interception_partition_policy='original-implicit-exact-interception-partition-v1',
                saturation_derivative_policy='original-implicit-saturated-conductivity-derivative-v1',
                finite_newton_policy='original-implicit-finite-newton-rate-rollback-v1',
                **(frost_identity() if frost else source_identity() if snow else {}))


def metadata(project):
    if not project.input_directory:
        return None
    from experimental_project import inspect
    selected = inspect(project.input_directory).get('implicit_conductivity')
    if selected is None:
        return None
    if selected.get('implicit_snow_composition') and not project.original_output:
        raise ValueError('Implicit Snow composition requires original output ownership')
    return dict(selected, source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
