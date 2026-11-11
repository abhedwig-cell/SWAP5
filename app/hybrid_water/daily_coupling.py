"""External daily accept/discard adapter; original forcing and physics stay owned by DailyHost.

A private, locally accepted day is only a proposal to the external caller.
Only accept() publishes in the caller's accepted namespace. Every proposal uses
the same immutable accepted native/auxiliary origin, including after discard.
This is serial daily transaction control, not a groundwater feedback solver.
"""
import contextlib
from dataclasses import dataclass
from datetime import date, timedelta
import json
import math
from pathlib import Path
import secrets
import zipfile

import daily_host as h


def validate_bundle(bundle, reference, project):
    """Reuse a qualified binary only at its exact source/build/input boundary."""
    meta = json.loads((bundle / 'BUILD.json').read_text())
    identity = meta['identity']
    if meta['project'] != dict(case=project.case, model=project.model,
                              start_date=project.start_date, nodes=project.nodes,
                              water_tolerance=project.water_tolerance):
        raise ValueError('Bundle project differs')
    for key, name in [('host', 'daily_host.py'), ('adapter', 'donor_adapter.f90'),
                      ('driver', 'main.f90'), ('budget_source', 'hybrid_step_budget.f90')]:
        if key == 'budget_source' and not meta['binding']['budget_retry']:
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
    case = reference / 'distribution/SWAP_4.3.1/cases' / project.case
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
    """One externally accepted column; no peer model, forcing override or new codec.

    Each output directory has one owner and must be new. Supply an explicit
    coupling_id on cold start and recovery. A native checkpoint may be adopted
    only with adopt_native=True; ordinary recovery requires this adapter's exact
    source/build/project/coupling binding. No physical origin is overwritten.
    """
    def __init__(self, bundle, reference, output, project, coupling_id, *,
                 origin=None, day=0, adopt_native=False):
        if project not in (h.ANDELST, h.GRASSGROWTH, h.HUPSEL):
            raise ValueError('Unregistered project')
        if not isinstance(coupling_id, str) or not coupling_id or len(coupling_id) > 128:
            raise ValueError('Explicit coupling identity is required')
        self.bundle, self.reference, self.output = map(Path, (bundle, reference, output))
        self.meta, self.case = validate_bundle(self.bundle, self.reference, project)
        self.project, self.coupling_id = project, coupling_id
        self.last_day = {h.ANDELST: 481, h.GRASSGROWTH: 1827, h.HUPSEL: 1096}[project]
        if type(day) is not int or not 0 <= day <= self.last_day or (origin is None) != (day == 0):
            raise ValueError('Origin and original project period differ')
        if adopt_native and origin is None:
            raise ValueError('Native adoption requires a checkpoint')
        self.binding = {**self.meta['binding'], 'external_daily': {
            'version': 1, 'source_sha256': h.sha(Path(__file__)),
            'coupling_id': coupling_id, 'forcing': 'original-project'}}
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

    def prepare(self):
        self._check_origin()
        if self._pending is not None:
            raise ValueError('A day proposal is already outstanding')
        if self._day >= self.last_day:
            raise ValueError('Original project period is complete')
        if (self.output / f'accepted-column-1-day-{self._day+1}.zip').exists():
            raise FileExistsError('Accepted day target is occupied')
        validate_bundle(self.bundle, self.reference, self.project)
        self._attempt += 1
        trial = self.output / f'trial-{self._attempt}'
        trial.mkdir()
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
                               h.executable(self.bundle, 'day_kernel'), self.case,
                               trial, [start], runtime=True, checkpoint_enabled=True,
                               project=self.project)
            # Bind the private host before its FIRST advance. The existing
            # stateless C publisher uses the passed sibling paths, not the DLL
            # directory. Reuse this owner's callable without changing DailyHost
            # or recompiling identical C code for each day proposal.
            host.binding = self.meta['binding']
            host.publish = self._publisher
            raw = host.step(1, checkpoint=True)
            if not raw['committed']:
                raise ValueError('Local water/solute acceptance refused the proposal')
            candidate = trial / f"accepted-column-1-day-{raw['day']}.zip"
            ready = trial / 'verified-candidate'
            checked = h.verify_checkpoint(candidate, self._day+1, self.meta['binding'], ready)
            if checked != raw:
                raise ValueError('Private candidate receipt differs')
            host.close()
        self._check_origin()
        self._candidate = (ready, raw, h.sha(candidate), candidate)
        t0 = self.project.start_clock + self._day
        self._pending = PreparedDay(self.coupling_id, secrets.token_hex(16), self._origin_hash,
                                    t0, t0+1, (date.fromisoformat(self.project.start_date)+
                                               timedelta(days=self._day)).isoformat(), json.dumps(raw))
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
        ready, raw, digest, candidate = self._candidate
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
                   'forcing': 'original-project'}}
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
