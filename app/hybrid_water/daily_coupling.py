"""External daily accept/discard with opt-in original lower-boundary head inputs.

A private, locally accepted day is only a proposal to the external caller.
Only accept() publishes in the caller's accepted namespace. Every proposal uses
the same immutable accepted native/auxiliary origin, including after discard.
This is serial daily transaction control, not a groundwater feedback solver.
"""
import contextlib
import hashlib
from dataclasses import dataclass
from datetime import date, timedelta
import json
import math
import re
import shutil
from pathlib import Path
import secrets
import zipfile
import struct

import daily_host as h

ORIGINAL_FORCING = 'original-project'
CAUCHY_FORCING = 'andelst-cauchy-daily-v1'
GROUNDWATER_FORCING = 'grass-groundwater-daily-v1'
IRRIGATION_FORCING = 'hupsel-surface-irrigation-daily-v1'
SURFACE_IRRIGATION_FORCING = 'surface-irrigation-daily-v1'
IRRIGATION_MODES = (IRRIGATION_FORCING, SURFACE_IRRIGATION_FORCING)


@dataclass(frozen=True)
class CauchyDayForcing:
    """One original-datum aquifer-head segment bound to an accepted origin."""
    coupling_id: str
    origin_sha256: str | None
    origin_day: int
    t0_day1900: int
    t1_day1900: int
    head_start_cm: float
    head_end_cm: float
    provenance: str

    def document(self):
        return dict(self.__dict__)


@dataclass(frozen=True)
class GroundwaterDayForcing(CauchyDayForcing):
    """Original signed GWLEVEL in cm relative to the original soil surface.

    Inherited head fields carry water-level coordinates, not aquifer pressure.
    The distinct type/mode prevents exchanging it with a Cauchy aquifer segment.
    """


@dataclass(frozen=True)
class IrrigationDayForcing:
    """One fixed surface event: original mm, mg/cm3 and mm/h; or explicit absence."""
    coupling_id: str
    origin_sha256: str | None
    origin_day: int
    t0_day1900: int
    t1_day1900: int
    enabled: bool
    depth_mm: float
    concentration_mg_cm3: float
    rate_mm_h: float
    provenance: str

    def document(self):
        return dict(self.__dict__)



def write_groundwater_case(case, target, forcing, project):
    """Retain sparse original DATE1/GWLEVEL rows and insert owned daily knots."""
    shutil.copytree(case,target)
    bbc=target/'swap.bbc';source=bbc.read_text(encoding='cp1252')
    if len(re.findall(r'(?mi)^\s*SWBOTB\s*=\s*1\b',source))!=1:
        raise ValueError('Original prescribed groundwater mode required')
    first=date.fromisoformat(project.start_date)+timedelta(days=forcing.origin_day)
    number=r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[EeDd][+-]?\d+)?'
    pattern=rf'(?m)^([ \t]*DATE1[ \t]+GWLEVEL[ \t]*\r?\n)((?:[ \t]*\d{{4}}-\d{{2}}-\d{{2}}[ \t]+{number}[ \t]*\r?\n)+)'
    def segment(m):
        rows={}
        for line in m[2].splitlines():
            stamp,value=line.split()
            if stamp in rows:raise ValueError('Duplicate original groundwater date')
            rows[stamp]=line
        for stamp,value in [(str(first),forcing.head_start_cm),(str(first+timedelta(days=1)),forcing.head_end_cm)]:
            if stamp not in rows:rows[stamp]=f' {stamp} {float(value)!r}'
            else:
                old=rows[stamp].split()[1]
                if float(old.replace('D','e').replace('d','e'))!=value:
                    rows[stamp]=re.sub(rf'({re.escape(stamp)}[ \t]+){number}',lambda x:x[1]+repr(float(value)),rows[stamp])
        return m[1]+'\n'.join(rows[k] for k in sorted(rows))+'\n'
    source,count=re.subn(pattern,segment,source)
    if count!=1:raise ValueError('Missing or ambiguous original groundwater table')
    bbc.write_text(source,encoding='cp1252')


def forcing_digest(document):
    return hashlib.sha256(json.dumps(document,sort_keys=True,separators=(',', ':'),allow_nan=False).encode()).hexdigest()


def write_cauchy_case(case, target, forcing, project):
    """Private original input only; unchanged original interpolation/physics."""
    shutil.copytree(case,target)
    bbc=target/'swap.bbc';source=bbc.read_text(encoding='cp1252')
    for name,value in [('SWBOTB',3),('SW3',2),('SW4',0)]:
        if len(re.findall(rf'(?mi)^\s*{name}\s*=\s*{value}\b',source))!=1:
            raise ValueError('Unsupported original Cauchy mode: '+name)
    first=date.fromisoformat(project.start_date)+timedelta(days=forcing.origin_day)
    last=first+timedelta(days=1)
    # The unchanged DailyHost extends the original 1998 terminal point at a
    # year restart. Supply its expected padding, then the real one-day endpoint.
    table_start=date(1998,12,31) if forcing.origin_day>=365 else first
    # TTUTIL infers numeric column type; integral endpoints must still be real.
    # repr(float) round-trips caller doubles without an integer lexical endpoint.
    number=r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[EeDd][+-]?\d+)?'
    pattern=rf'(?m)^([ \t]*DATE3[ \t]+HAQUIF[ \t]*\r?\n)(?:[ \t]*\d{{4}}-\d{{2}}-\d{{2}}[ \t]+{number}[ \t]*\r?\n)+'
    def segment(match):
        table=match[0]
        for stamp,value in [(table_start,forcing.head_start_cm),(last,forcing.head_end_cm)]:
            row=rf'(?m)^([ \t]*{stamp}[ \t]+)({number})([ \t]*\r?$)'
            def change(m):
                # Preserve original decimal spelling when the requested value
                # is unchanged. TTUTIL owns conversion, including its rounding.
                old=float(m[2].replace('D','e').replace('d','e'))
                return m[0] if old==value else m[1]+repr(float(value))+m[3]
            table,n=re.subn(row,change,table)
            if n>1:raise ValueError('Duplicate aquifer-head date')
            if not n:table+=f' {stamp} {float(value)!r}\n'
        return table
    # Retain all original neighboring knots: the original adaptive clock can
    # evaluate a final abscissa a few ulps beyond the nominal day boundary.
    source,count=re.subn(pattern,segment,source)
    if count!=1:raise ValueError('Missing or ambiguous original aquifer-head table')
    bbc.write_text(source,encoding='cp1252')


def validate_bundle(bundle, reference, project):
    """Reuse a qualified binary only at its exact source/build/input boundary."""
    meta = json.loads((bundle / 'BUILD.json').read_text())
    identity = meta['identity']
    from fixed_irrigation_file import enabled as fixed_file_enabled,POLICY as FIXED_FILE_POLICY
    from frost_reference import enabled as frost_enabled,POLICY as FROST_POLICY,source as frost_source
    from time_event_closure import POLICY as EVENT_POLICY, metadata as event_metadata, source as event_source
    expected_event=event_metadata((reference/'build/swap-selected/timecontrol.f90').read_bytes()) if project.time_step_policy==EVENT_POLICY else None
    if identity.get('time_event_closure')!=expected_event:raise ValueError('Foreign original TimeControl event-closure policy')
    if expected_event and (bundle/'timecontrol.f90').read_bytes()!=event_source((reference/'build/swap-selected/timecontrol.f90').read_bytes()):
        raise ValueError('Foreign actual corrected TimeControl source')
    if expected_event and (bundle/'terminal_water_receipt.f90').read_bytes()!=(h.APP/'terminal_water_receipt.f90').read_bytes():
        raise ValueError('Foreign actual terminal water receipt source')
    expected_frost=None
    if frost_enabled(project):
        guarded=frost_source((reference/'build/swap-selected/frozencond.f90').read_bytes())
        expected_frost={'policy':FROST_POLICY,'source_sha256':h.sha(h.APP/'frost_reference.py'),
                        'generated_source_sha256':hashlib.sha256(guarded).hexdigest()}
    if identity.get('frost_reference')!=expected_frost:raise ValueError('Foreign bounded original frost reference policy')
    if expected_frost and (bundle/'frozencond.f90').read_bytes()!=guarded:raise ValueError('Foreign actual original frost source')
    expected_file={'policy':FIXED_FILE_POLICY,'source_sha256':h.sha(h.APP/'fixed_irrigation_file.py')} if fixed_file_enabled(project) else None
    if identity.get('fixed_irrigation_file')!=expected_file:raise ValueError('Foreign original fixed irrigation file policy')
    from conserved_subsurface_solute import enabled as chemical_enabled, metadata as chemical_metadata, correction as chemical_correction
    expected_chemical=chemical_metadata() if chemical_enabled(project) else None
    if identity.get('conserved_subsurface_solute')!=expected_chemical:raise ValueError('Foreign conserved subsurface solute policy')
    from conserved_scheduled_subsurface_solute import enabled as chemical_scheduled_enabled, metadata as chemical_scheduled_metadata
    expected_chemical_scheduled=chemical_scheduled_metadata() if chemical_scheduled_enabled(project) else None
    if identity.get('conserved_scheduled_subsurface_solute')!=expected_chemical_scheduled:raise ValueError('Foreign conserved scheduled subsurface solute policy')
    if (expected_chemical or expected_chemical_scheduled) and (bundle/'mod_subsurface_solute_source.f90').read_bytes()!=chemical_correction().helper_source():
        raise ValueError('Foreign actual conserved subsurface solute helper')
    from conserved_aquifer_solute import enabled as aquifer_enabled, metadata as aquifer_metadata, correction as aquifer_correction
    expected_aquifer=aquifer_metadata() if aquifer_enabled(project) else None
    if identity.get('conserved_aquifer_solute')!=expected_aquifer:raise ValueError('Foreign original aquifer solute source/state policy')
    if expected_aquifer and (bundle/'mod_aquifer_solute_reservoir.f90').read_bytes()!=aquifer_correction().helper_source():
        raise ValueError('Foreign actual aquifer solute evaluator')
    from conserved_original_age import metadata as age_metadata,correction as age_correction
    expected_age=age_metadata() if project.age else None
    if expected_age is not None:
        from age_output_calendar import age_identity
        expected_age=age_identity(expected_age,project)
    if identity.get('conserved_original_age')!=expected_age:raise ValueError('Foreign original age source/state policy')
    from age_fixed_irrigation import enabled as age_fixed_enabled,metadata as age_fixed_metadata
    expected_age_fixed=age_fixed_metadata() if age_fixed_enabled(project) else None
    if identity.get('original_age_fixed_irrigation')!=expected_age_fixed:raise ValueError('Foreign original fixed young-water age policy')
    if expected_age:
        age_source=age_correction()
        for name in (*age_source.PROVIDERS,*age_source.OUTPUT_PROVIDERS):
            if (bundle/(name+'.f90')).read_bytes().replace(b'\r\n',b'\n')!=(h.ROOT/'src/process'/(name+'.f90')).read_bytes().replace(b'\r\n',b'\n'):
                raise ValueError('Foreign actual original age provider')
    from scheduled_subsurface_irrigation import enabled as scheduled_subsurface_enabled, POLICY as SCHEDULED_SUBSURFACE_POLICY
    expected_subsurface={'policy':SCHEDULED_SUBSURFACE_POLICY,'source_sha256':h.sha(h.APP/'scheduled_subsurface_irrigation.py')} if scheduled_subsurface_enabled(project) else None
    if identity.get('scheduled_subsurface_irrigation')!=expected_subsurface:raise ValueError('Foreign original scheduled subsurface irrigation policy')
    from surface_schedule import enabled as surface_schedule_enabled,POLICY as SURFACE_SCHEDULE_POLICY
    expected_schedule={'policy':SURFACE_SCHEDULE_POLICY,'source_sha256':h.sha(h.APP/'surface_schedule.py')} if surface_schedule_enabled(project) else None
    if identity.get('surface_schedule')!=expected_schedule:raise ValueError('Foreign original surface schedule')
    from lower_boundary_receipt import selected_boundary,policy as lower_policy,render_budget
    lower_boundary=selected_boundary(project)
    lower=lower_boundary is not None
    expected_lower={'policy':lower_policy(lower_boundary),'source_sha256':h.sha(h.APP/'lower_boundary_receipt.py'),
                    'template_sha256':h.sha(h.APP/'hybrid_step_budget.f90'),'effective_SWBOTB':lower_boundary} if lower else None
    if identity.get('lower_boundary_receipt')!=expected_lower:raise ValueError('Foreign original lower-boundary receipt')
    if lower:
        source=bundle/'hybrid_step_budget.f90'
        if identity['budget_source']!=h.sha(source) or source.read_text(encoding='cp1252')!=render_budget((h.APP/'hybrid_step_budget.f90').read_text(encoding='cp1252'),lower_boundary):
            raise ValueError('Foreign generated lower-boundary receipt source')
    from micro_lookup_state import POLICY,enabled
    from scheduled_pond_state import POLICY as POND_HISTORY_POLICY,enabled as pond_history_enabled
    expected_pond_history={'policy':POND_HISTORY_POLICY,'source_sha256':h.sha(h.APP/'scheduled_pond_state.py')} if pond_history_enabled(project) else None
    if identity.get('scheduled_pond_history')!=expected_pond_history:
        raise ValueError('Foreign original scheduled pond history policy; rebuild without rebinding')
    expected_micro=POLICY if enabled(project) else None
    if identity.get('micro_lookup_state_policy')!=expected_micro:
        raise ValueError('Bundle original microscopic lookup state policy differs; rebuild without rebinding')
    if expected_micro and identity.get('micro_lookup_state_source')!=h.sha(h.APP/'micro_lookup_state.py'):
        raise ValueError('Bundle original microscopic lookup state generator differs')
    if expected_micro and identity.get('history_top_state_source')!=h.sha(h.APP/'history_top_state.py'):
        raise ValueError('Foreign original top history generator')
    if expected_micro and identity.get('oxygen_lookup_state_source')!=h.sha(h.APP/'oxygen_lookup_state.py'):
        raise ValueError('Foreign original oxygen history generator')
    if not project.macro:
        tables=False
        if project.input_directory:
            from experimental_project import inspect
            tables=inspect(project.input_directory)['selectors']['SWSOPHY']==1
        expected=project.soil_table_policy if tables else None
        if identity.get('soil_table_policy') != expected:
            raise ValueError('Bundle soil-table interpolation policy differs')
        if project.soil_table_policy == h.PCHIP_SOIL_TABLE_POLICY and identity.get('soil_table_policy_source') != h.sha(h.APP/'daily_host.py'):
            raise ValueError('Bundle soil-table selection source differs')
    if not project.macro:
        expected=project.solute_step_policy if project.solute else None
        if identity.get('solute_step_policy') != expected:
            raise ValueError('Bundle chemical substep policy differs; rebuild without rebinding checkpoints')
        if project.solute_step_policy == h.TRANSACTIONAL_SOLUTE_STEP_POLICY and identity.get('solute_step_policy_source') != h.sha(h.APP/'solute_step_policy.py'):
            raise ValueError('Bundle chemical substep generator differs')
    if not project.macro and identity.get('time_step_policy_source') != h.sha(h.APP/'donor_sources.py'):
        raise ValueError('Bundle time-step generator source differs')
    if not project.macro and identity.get('time_step_policy') != project.time_step_policy:
        raise ValueError('Bundle time-step policy differs; rebuild at current source')
    from irrigation_pulse_time import POLICY as PULSE_POLICY, metadata as pulse_metadata
    expected_pulse=pulse_metadata((reference/'build/swap-selected/timecontrol.f90').read_bytes()) if project.time_step_policy==PULSE_POLICY else None
    if identity.get('irrigation_pulse_time') != expected_pulse:
        raise ValueError('Foreign original irrigation pulse temporal policy')
    from local_wetting_time import POLICY as WETTING_POLICY, metadata as wetting_metadata
    expected_wetting=wetting_metadata((reference/'build/swap-selected/timecontrol.f90').read_bytes()) if project.time_step_policy==WETTING_POLICY else None
    if identity.get('local_wetting_time') != expected_wetting:
        raise ValueError('Foreign original local wetting temporal policy')
    if not project.macro and identity.get('floating_point_profile') != h.no_macro_fp_profile():
        raise ValueError('Bundle floating-point profile differs')
    if 'restart_publisher' in identity:
        h.validate_restart_publisher(bundle, identity['restart_publisher'])
    if meta['project'] != dict(case=project.case, model=project.model,
                              start_date=project.start_date, nodes=project.nodes,
                              water_tolerance=project.water_tolerance):
        raise ValueError('Bundle project differs')
    for key, name in [('host', 'daily_host.py'), ('adapter', 'donor_adapter.f90'),
                      ('driver', 'main.f90'), ('budget_source', 'hybrid_step_budget.f90')]:
        if key == 'budget_source' and (lower or not meta['binding']['budget_retry']):
            continue
        if identity[key] != h.sha(h.APP / name):
            raise ValueError('Bundle source differs: ' + name)
    for name, digest in identity['kernel_sources']:
        if h.sha(h.ROOT / name) != digest:
            raise ValueError('Kernel source differs: ' + name)
    for name, digest in identity['donor_generated'].items():
        if h.sha(bundle / name) != digest:
            raise ValueError('Generated donor differs: ' + name)
    for role, name in [('donor', 'day_donor'), ('kernel', 'day_kernel')]:
        if h.sha(h.executable(bundle, name)) != meta['executable_sha256'][role]:
            raise ValueError('Executable differs: ' + role)
    if 'irrigation_extension' in identity:
        from irrigation_forcing import __file__ as extension_source
        ext=identity['irrigation_extension']
        from irrigation_forcing import project_protocol
        if (ext.get('protocol')!=project_protocol(project) or ext['source_sha256']!=h.sha(Path(extension_source))
            or ext['object_sha256']!=h.sha(bundle/'irrigation.o')):
            raise ValueError('Foreign irrigation extension source/object')
    case = h.project_case(reference, project)
    if project.input_directory and identity.get('experimental_input_adapter') != h.sha(h.APP/'experimental_project.py'):
        raise ValueError('Experimental input adapter differs')
    for name, digest in meta['inputs'].items():
        if h.sha(case / name) != digest:
            raise ValueError('Original input differs: ' + name)
    return meta, case


@dataclass(frozen=True)
class PreparedDay:
    coupling_id: str
    token: str
    origin_sha256: str | None
    t0_day1900: int
    t1_day1900: int
    date: str
    _raw_json: str
    _forcing_json: str = '"original-project"'

    @property
    def forcing(self):
        return json.loads(self._forcing_json)

    @property
    def budget(self):
        # Never expose a locally accepted branch as externally committed state.
        row = json.loads(self._raw_json)
        row.update(committed=False, candidate_only=True)
        return row

    @property
    def bottom_outward_cm(self):
        return json.loads(self._raw_json)['bottom_outward_cm']

    @property
    def mean_bottom_outward_m_per_s(self):
        # Accepted coupling convention: whole-window cm outward / duration.
        return self.bottom_outward_cm * 0.01 / ((self.t1_day1900-self.t0_day1900)*86400)

    def bottom_outward_m3(self, area_m2):
        if not math.isfinite(area_m2) or area_m2 <= 0:
            raise ValueError('A finite positive column area is required')
        volume = self.bottom_outward_cm * 0.01 * area_m2
        if not math.isfinite(volume):
            raise ValueError('Nonfinite exchanged volume')
        return volume


class CoupledDailyColumn:
    """One externally accepted column with original registered boundary semantics.

    Each output directory has one owner and must be new. Supply an explicit
    coupling_id on cold start and recovery. A native checkpoint may be adopted
    only with adopt_native=True; ordinary recovery requires this adapter's exact
    source/build/project/coupling binding. No physical origin is overwritten.
    """
    def __init__(self, bundle, reference, output, project, coupling_id, *,
                 origin=None, day=0, adopt_native=False, forcing_mode=ORIGINAL_FORCING):
        h.project_case(reference, project)
        if not isinstance(coupling_id, str) or not coupling_id or len(coupling_id) > 128:
            raise ValueError('Explicit coupling identity is required')
        if (forcing_mode not in (ORIGINAL_FORCING,CAUCHY_FORCING,GROUNDWATER_FORCING,*IRRIGATION_MODES) or
            (forcing_mode==CAUCHY_FORCING and project!=h.ANDELST) or
            (forcing_mode==GROUNDWATER_FORCING and project!=h.GRASSGROWTH) or
            (forcing_mode==IRRIGATION_FORCING and project!=h.HUPSEL)):
            raise ValueError('Unsupported external forcing mode/project')
        if forcing_mode==SURFACE_IRRIGATION_FORCING:
            from irrigation_forcing import project_protocol
            project_protocol(project)
        self.forcing_mode=forcing_mode
        self.bundle, self.reference, self.output = map(Path, (bundle, reference, output))
        self.meta, self.case = validate_bundle(self.bundle, self.reference, project)
        if forcing_mode in IRRIGATION_MODES and 'irrigation_extension' not in self.meta['identity']:
            raise ValueError('Irrigation consumer not built')
        self.project, self.coupling_id = project, coupling_id
        self.last_day = project.last_day
        if type(day) is not int or not 0 <= day <= self.last_day or (origin is None) != (day == 0):
            raise ValueError('Origin and original project period differ')
        if adopt_native and origin is None:
            raise ValueError('Native adoption requires a checkpoint')
        self.binding = {**self.meta['binding'], 'external_daily': {
            'version': 1, 'source_sha256': h.sha(Path(__file__)),
            'coupling_id': coupling_id, 'forcing': forcing_mode}}
        self._origin = Path(origin).resolve() if origin is not None else None
        self._origin_hash = h.sha(self._origin) if self._origin is not None else None
        expected = self.meta['binding'] if adopt_native else self.binding
        self._origin_binding = expected
        if self._origin is not None:
            with zipfile.ZipFile(self._origin) as z:
                manifest = json.loads(z.read('checkpoint.json'))
            if manifest['binding'] != expected:
                raise ValueError('Foreign source, build, project or coupling origin')
        self.output.mkdir()  # exclusive directory ownership; never reuse a live owner
        self._day, self._revision = day, 0
        self._origin_receipt = None
        if self._origin is not None:
            self._origin_receipt = h.verify_checkpoint(self._origin, day, expected,
                                                       self.output / 'verified-initial-origin')
            if not adopt_native:
                c = self._origin_receipt['coupling']
                if c['id'] != coupling_id or type(c['revision']) is not int or c['revision'] < 1:
                    raise ValueError('Invalid external origin revision')
                self._revision = c['revision']
                if self.forcing_mode!=ORIGINAL_FORCING:
                    f=c['forcing'];document=f['input']
                    if f['mode']!=self.forcing_mode or type(c['origin_day']) is not int or c['origin_day']!=day-1:
                        raise ValueError('Invalid persisted Cauchy origin')
                    kind=GroundwaterDayForcing if self.forcing_mode==GROUNDWATER_FORCING else CauchyDayForcing
                    if self.forcing_mode in IRRIGATION_MODES:
                        self._validate_irrigation(IrrigationDayForcing(**document),day=c['origin_day'],origin=c['origin_sha256'])
                    else:self._validate_cauchy(kind(**document),day=c['origin_day'],origin=c['origin_sha256'])
                    if f['identity_sha256']!=forcing_digest(document) or not re.fullmatch(r'[0-9a-f]{64}',f['applied_irrigation_sha256' if self.forcing_mode in IRRIGATION_MODES else 'applied_bbc_sha256']):
                        raise ValueError('Invalid persisted Cauchy forcing identity')
        self._publisher = None  # load once on first proposal, never compile per day
        self._pending = None
        self._candidate = None
        self._attempt = 0
        self._failed = False

    @property
    def day(self):
        return self._day

    @property
    def revision(self):
        return self._revision

    @property
    def checkpoint(self):
        return self._origin

    def _check_origin(self):
        if self._failed:
            raise ValueError('Failed publication requires explicit disk recovery')
        if self._origin is not None and h.sha(self._origin) != self._origin_hash:
            raise ValueError('Accepted origin was changed')

    def _validate_cauchy(self, forcing, *, day=None, origin=None):
        kind=GroundwaterDayForcing if self.forcing_mode==GROUNDWATER_FORCING else CauchyDayForcing
        if type(forcing) is not kind:raise ValueError('Explicit boundary segment of the selected kind required')
        if day is None:day,origin=self._day,self._origin_hash
        if (forcing.coupling_id!=self.coupling_id or forcing.origin_sha256!=origin or
            type(forcing.origin_day) is not int or forcing.origin_day!=day or
            type(forcing.t0_day1900) is not int or type(forcing.t1_day1900) is not int or
            forcing.t0_day1900!=self.project.start_clock+day or forcing.t1_day1900!=forcing.t0_day1900+1):
            raise ValueError('Foreign or stale Cauchy forcing origin/window')
        for value in (forcing.head_start_cm,forcing.head_end_cm):
            if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value) or not -10000<=value<=1000:
                raise ValueError('Cauchy head outside original finite input range')
        if not isinstance(forcing.provenance,str) or not forcing.provenance or len(forcing.provenance)>128:
            raise ValueError('Explicit Cauchy input provenance required')

    def cauchy_forcing(self, head_start_cm, head_end_cm, provenance):
        self._check_origin()
        if self.forcing_mode!=CAUCHY_FORCING:raise ValueError('Original forcing mode has no override')
        start=self.project.start_clock+self._day
        forcing=CauchyDayForcing(self.coupling_id,self._origin_hash,self._day,start,start+1,
                                head_start_cm,head_end_cm,provenance)
        self._validate_cauchy(forcing)
        return forcing

    def groundwater_forcing(self, level_start_cm, level_end_cm, provenance):
        self._check_origin()
        if self.forcing_mode!=GROUNDWATER_FORCING:raise ValueError('Prescribed groundwater mode required')
        start=self.project.start_clock+self._day
        forcing=GroundwaterDayForcing(self.coupling_id,self._origin_hash,self._day,start,start+1,
                                     level_start_cm,level_end_cm,provenance)
        self._validate_cauchy(forcing)
        return forcing

    def _validate_irrigation(self, forcing, *, day=None, origin=None):
        if type(forcing) is not IrrigationDayForcing:raise ValueError('Typed irrigation request required')
        if day is None:day,origin=self._day,self._origin_hash
        if (forcing.coupling_id!=self.coupling_id or forcing.origin_sha256!=origin or
            type(forcing.origin_day) is not int or forcing.origin_day!=day or
            type(forcing.t0_day1900) is not int or type(forcing.t1_day1900) is not int or
            forcing.t0_day1900!=self.project.start_clock+day or forcing.t1_day1900!=forcing.t0_day1900+1):
            raise ValueError('Foreign or stale irrigation origin/window')
        if type(forcing.enabled) is not bool:raise ValueError('Explicit irrigation switch required')
        values=(forcing.depth_mm,forcing.concentration_mg_cm3,forcing.rate_mm_h)
        if any(type(v) not in (int,float) or not math.isfinite(v) for v in values):
            raise ValueError('Nonfinite or nonnumeric irrigation')
        depth,conc,rate=values
        if not self.project.solute and conc!=0:
            raise ValueError('Water-only irrigation cannot carry solute')
        if forcing.enabled:
            if not (.01<=depth<=100 and 0<=conc<=1000 and 0<rate<=100 and (0.1*depth)/(0.1*24*rate)<=1):
                raise ValueError('Irrigation outside original input range/duration')
        elif any(values):raise ValueError('Disabled irrigation must carry zero water and solute input')
        if not isinstance(forcing.provenance,str) or not forcing.provenance or len(forcing.provenance)>128:
            raise ValueError('Explicit irrigation provenance required')

    def irrigation_forcing(self, depth_mm, concentration_mg_cm3, rate_mm_h, provenance, *, enabled=True):
        self._check_origin()
        if self.forcing_mode not in IRRIGATION_MODES:raise ValueError('Surface irrigation mode required')
        start=self.project.start_clock+self._day
        request=IrrigationDayForcing(self.coupling_id,self._origin_hash,self._day,start,start+1,
                                    enabled,depth_mm,concentration_mg_cm3,rate_mm_h,provenance)
        self._validate_irrigation(request)
        return request

    def prepare(self, *, cauchy=None, groundwater=None, irrigation=None):
        self._check_origin()
        if self._pending is not None:
            raise ValueError('A day proposal is already outstanding')
        if self._day >= self.last_day:
            raise ValueError('Original project period is complete')
        if self.forcing_mode in IRRIGATION_MODES:
            if cauchy is not None or groundwater is not None:raise ValueError('Wrong irrigation input kind')
            self._validate_irrigation(irrigation)
        elif irrigation is not None:raise ValueError('Irrigation mode required')
        if ((cauchy is not None and groundwater is not None) or
            (self.forcing_mode==CAUCHY_FORCING and groundwater is not None) or
            (self.forcing_mode==GROUNDWATER_FORCING and cauchy is not None)):
            raise ValueError('Boundary forcing kind does not match the selected mode')
        if self.forcing_mode==GROUNDWATER_FORCING:cauchy=groundwater
        if self.forcing_mode not in (ORIGINAL_FORCING,*IRRIGATION_MODES):self._validate_cauchy(cauchy)
        elif cauchy is not None or groundwater is not None:raise ValueError('Original forcing mode has no override')
        if (self.output / f'accepted-column-1-day-{self._day+1}.zip').exists():
            raise FileExistsError('Accepted day target is occupied')
        validate_bundle(self.bundle, self.reference, self.project)
        self._attempt += 1
        trial = self.output / f'trial-{self._attempt}'
        trial.mkdir()
        case=self.case
        if cauchy is not None:
            case=trial/'forcing-case'
            writer=write_groundwater_case if self.forcing_mode==GROUNDWATER_FORCING else write_cauchy_case
            writer(self.case,case,cauchy,self.project)
        if irrigation is not None:
            case=trial/'forcing-case'
            shutil.copytree(self.case,case)
            from irrigation_forcing import INPUT
            protocol=self.meta['identity']['irrigation_extension']['protocol']
            (case/INPUT).write_text(protocol+' '+ ' '.join(map(str,[irrigation.t0_day1900,int(irrigation.enabled),
                float(irrigation.depth_mm),float(irrigation.concentration_mg_cm3),float(irrigation.rate_mm_h)]))+'\n',encoding='ascii')
        receipt, origin = None, None
        if self._origin is not None:
            origin = trial / 'origin'
            # Adoption has already been verified; each later origin has our binding.
            receipt = h.verify_checkpoint(self._origin, self._day, self._origin_binding, origin)
        start = h.ColumnStart(day=self._day, origin=origin, receipt=receipt, name='original')
        if self._publisher is None:
            self._publisher = h.restart_publisher(self.output)
        with contextlib.ExitStack() as stack:
            host = h.DailyHost(stack, h.executable(self.bundle, 'day_donor'),
                               h.executable(self.bundle, 'day_kernel'), case,
                               trial, [start], runtime=True, checkpoint_enabled=True,
                               project=self.project)
            # Bind the private host before its FIRST advance. The existing
            # stateless C publisher uses the passed sibling paths, not the DLL
            # directory. Reuse this owner's callable without changing DailyHost
            # or recompiling identical C code for each day proposal.
            host.binding = self.meta['binding']
            host.publish = self._publisher
            forcing_record=ORIGINAL_FORCING
            if cauchy is not None:
                forcing_record={'mode':self.forcing_mode,'input':cauchy.document(),
                    'identity_sha256':forcing_digest(cauchy.document()),
                    'applied_bbc_sha256':h.sha(host.columns[0].directory/'swap.bbc')}
                key='external_groundwater_trial' if self.forcing_mode==GROUNDWATER_FORCING else 'external_cauchy_trial'
                host.binding={**self.meta['binding'],key:forcing_record}
            if irrigation is not None:
                forcing_record={'mode':self.forcing_mode,'input':irrigation.document(),
                    'identity_sha256':forcing_digest(irrigation.document()),
                    'applied_irrigation_sha256':h.sha(host.columns[0].directory/INPUT)}
                host.binding={**self.meta['binding'],'external_irrigation_trial':forcing_record}
            raw = host.step(1, checkpoint=True)
            if not raw['committed']:
                raise ValueError('Local water/solute acceptance refused the proposal')
            candidate = trial / f"accepted-column-1-day-{raw['day']}.zip"
            ready = trial / 'verified-candidate'
            checked = h.verify_checkpoint(candidate, self._day+1, host.binding, ready)
            if self.project.solute:
                # Current nonmacro codec: same strict state domain as the real
                # original consumer, checked BEFORE external publication.
                with zipfile.ZipFile(candidate) as z:aux=z.read('macro.bin')
                expected=b'S5HUP012'
                if self.project.input_directory:
                    from experimental_project import auxiliary_magic
                    expected=auxiliary_magic(self.project)
                if aux[:8]!=expected:raise ValueError('Foreign conserved solute codec')
                conserved=struct.unpack_from('<'+str(self.project.nodes+2)+'d',aux,48)
                if not all(math.isfinite(v) and v>=0 for v in conserved):
                    raise ValueError('Unrestartable candidate conserved solute state')
            if self.project.age:
                from conserved_original_age import validate as validate_age,validate_effluent
                from experimental_project import auxiliary_magic
                with zipfile.ZipFile(candidate) as z:aux=z.read('macro.bin')
                if aux[:8]!=auxiliary_magic(self.project):raise ValueError('Foreign original age native codec')
                validate_age(raw['age_state_cm_day'])
                validate_effluent(raw['age_effluent'])
            if checked != raw:
                raise ValueError('Private candidate receipt differs')
            host.close()
        self._check_origin()
        self._candidate = (ready, raw, h.sha(candidate), candidate, forcing_record)
        t0 = self.project.start_clock + self._day
        self._pending = PreparedDay(self.coupling_id, secrets.token_hex(16), self._origin_hash,
                                    t0, t0+1, (date.fromisoformat(self.project.start_date)+
                                               timedelta(days=self._day)).isoformat(), json.dumps(raw),json.dumps(forcing_record))
        return self._pending

    def _check_proposal(self, proposal):
        self._check_origin()
        if proposal is not self._pending or proposal is None:
            raise ValueError('Foreign, discarded or already accepted proposal')

    def discard(self, proposal):
        self._check_proposal(proposal)
        self._pending = self._candidate = None

    def accept(self, proposal):
        self._check_proposal(proposal)
        ready, raw, digest, candidate, forcing_record = self._candidate
        if h.sha(candidate) != digest:
            raise ValueError('Private proposal changed')
        # Verify the bytes actually being published, not only the retained ZIP.
        with zipfile.ZipFile(candidate) as z:
            for name in h.CHECKPOINT_FILES:
                if (ready / name).read_bytes() != z.read(name):
                    raise ValueError('Prepared native state changed')
        receipt = {**raw, 'coupling': {'id': self.coupling_id, 'revision': self._revision+1,
                   'origin_revision': self._revision, 'origin_sha256': self._origin_hash,
                   'origin_day': self._day, 'window_day1900': [proposal.t0_day1900, proposal.t1_day1900],
                   'forcing': forcing_record}}
        try:
            target = h.publish_checkpoint(self.output, ready, receipt, self.binding, self._publisher)
        except Exception:
            # Publication may have failed after replacement/directory sync. Never
            # pretend rollback or retry is safe; accepted disk recovery is explicit.
            self._failed = True
            raise
        self._day += 1
        self._revision += 1
        self._origin, self._origin_hash = target, h.sha(target)
        self._origin_receipt = receipt
        self._origin_binding = self.binding
        self._pending = self._candidate = None
        return target
