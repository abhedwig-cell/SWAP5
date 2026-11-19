"""Instance-owned transport to the existing SWAP5 daily transaction executor."""
import ctypes as c
import hashlib
import os
from pathlib import Path
import shutil
import subprocess

PROTOCOL = 'swap5-direct-day-kernel-1'
MODEL = 'HYBRID_SALTFARM_WATER'
APP = Path(__file__).resolve().parent


class NativeDayKernel:
    """The day-pipe lifecycle, with an opaque Fortran context per instance."""

    def __init__(self, library, model, transcript):
        if model != MODEL:
            raise ValueError('Direct day kernel model is unavailable')
        runtime_directory = None
        if os.name == 'nt':
            compiler = shutil.which('gfortran')
            if compiler is None:
                raise ValueError('Verified GNU runtime is required')
            runtime_directory = os.add_dll_directory(str(Path(compiler).parent))
        try:
            self.lib = c.CDLL(str(library))
        finally:
            if runtime_directory is not None:
                runtime_directory.close()
        self.log = transcript
        self.queue = [('DAILY_MODEL', [model])]
        self.handle = c.c_void_p()
        self.initial = []
        self.stage = 0
        self.done = self.cancelled = False
        doubles, integers = c.POINTER(c.c_double), c.POINTER(c.c_int)
        self.lib.dk_new.argtypes = [c.c_int, c.c_int, c.c_double, integers,
                                   doubles, doubles, doubles, c.POINTER(c.c_void_p), integers]
        self.lib.dk_request.argtypes = [c.c_void_p, c.c_int, c.c_int, doubles, integers]
        self.lib.dk_apply.argtypes = [c.c_void_p, c.c_int, c.c_int, c.c_int,
                                     doubles, doubles, integers]
        self.lib.dk_free.argtypes = [c.c_void_p]
        for name in ('dk_new', 'dk_request', 'dk_apply', 'dk_free'):
            getattr(self.lib, name).restype = None

    def poll(self):
        return 0 if self.done or self.cancelled else None

    def kill(self):
        # Watchdogs mark cancellation and kill the donor process. They must not
        # free a Fortran context from another thread while its executor runs.
        self.cancelled = True

    def wait(self, **kwargs):
        return 0

    def terminate(self):
        if not self.done:
            self.lib.dk_free(self.handle)
            self.handle = c.c_void_p()
            self.done = True

    @staticmethod
    def checked(status, allowed=(0,)):
        if status.value not in allowed:
            raise RuntimeError('Direct day kernel refused command: ' + str(status.value))

    def write(self, text):
        if self.cancelled:
            raise TimeoutError('Direct day kernel cancelled')
        if self.done:
            raise ValueError('Direct day kernel is closed')
        values = text.split()
        if self.stage == 0:
            if len(values) != 1 or int(values[0]) < 1:
                raise ValueError('Invalid column count')
            self.columns = int(values[0])
            self.stage = 1
        elif self.stage == 1:
            if len(values) != 2:
                raise ValueError('Incomplete project metadata')
            nodes, epoch = int(values[0]), float(values[1])
            if not 1 <= nodes <= 10000:
                raise ValueError('Invalid project grid')
            if self.initial and (nodes != self.nodes or epoch != self.epoch):
                raise ValueError('Direct columns must share their explicit project grid and epoch')
            self.nodes, self.epoch = nodes, epoch
            self.stage = 2
        elif self.stage == 2:
            if len(values) != self.nodes + 8:
                raise ValueError('Incomplete initial day state')
            initial = list(map(float, values))
            if initial[0] != int(initial[0]):
                raise ValueError('Noninteger initial day')
            self.initial.append(initial)
            self.stage = 1
            if len(self.initial) == self.columns:
                first = (c.c_int * self.columns)(*(int(x[0]) for x in self.initial))
                totals = (c.c_double * self.columns)(*(x[1] for x in self.initial))
                stocks = (c.c_double * (6 * self.columns))(
                    *(v for x in self.initial for v in x[2:8]))
                heads = (c.c_double * (self.nodes * self.columns))(
                    *(v for x in self.initial for v in x[8:]))
                status = c.c_int()
                self.lib.dk_new(self.columns, self.nodes, self.epoch, first, totals,
                                stocks, heads, c.byref(self.handle), c.byref(status))
                self.checked(status)
                self.initial.clear()
                self.stage = 3
        elif self.stage == 3:
            if len(values) != 2:
                raise ValueError('Incomplete day request')
            column, day = map(int, values)
            if column == 0:
                self.terminate()
                return
            times, status = (c.c_double * 2)(), c.c_int()
            self.lib.dk_request(self.handle, column, day, times, c.byref(status))
            self.checked(status)
            self.column, self.day = column, day
            self.queue.append(('DAILY_REQUEST', list(map(str, [column, day-1, *times]))))
            self.stage = 4
        elif self.stage == 4:
            if len(values) != self.nodes + 12:
                raise ValueError('Incomplete candidate day state')
            self.submit(tuple(map(float, values)))
        else:
            raise ValueError('Invalid direct day kernel lifecycle')

    def submit(self, values):
        """Consume the existing binary64 reply without a decimal round trip."""
        if self.cancelled:
            raise TimeoutError('Direct day kernel cancelled')
        if self.done or self.stage != 4:
            raise ValueError('Invalid direct day kernel reply lifecycle')
        if len(values) != self.nodes + 12:
            raise ValueError('Incomplete candidate day state')
        reply = (c.c_double * len(values))(*values)
        result, status = (c.c_double * 4)(), c.c_int()
        self.lib.dk_apply(self.handle, self.column, self.day, len(values), reply,
                          result, c.byref(status))
        self.checked(status, (0, 1))
        key = 'DAILY_ACCEPTED' if status.value == 1 else 'DAILY_REFUSED'
        self.queue.append((key, list(map(str, [self.column, self.day, int(result[0]),
                                               result[1], result[2]]))))
        self.stage = 3

    def receive(self, prefixes):
        if self.cancelled:
            raise TimeoutError('Direct day kernel cancelled')
        if not self.queue or self.queue[0][0] not in prefixes:
            raise RuntimeError('Missing expected direct day reply')
        key, values = self.queue.pop(0)
        self.log.write(key + ' ' + ' '.join(values) + '\n')
        self.log.flush()
        return key, {key: values}


def selected(project):
    return project.model == MODEL and not project.macro and not project.input_directory


def library_path(bundle):
    return Path(bundle) / ('direct_day_kernel.dll' if os.name == 'nt' else 'direct_day_kernel.so')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build(bundle, sources, adapter, flags, project):
    if not selected(project):
        return None
    library = library_path(bundle)
    command = ['gfortran', *flags, '-shared', *(['-fPIC'] if os.name != 'nt' else []),
               *map(str, sources), str(adapter), str(APP/'direct_day_kernel.f90'), '-o', str(library)]
    subprocess.run(command, cwd=bundle, check=True)
    return dict(protocol=PROTOCOL, model=MODEL, bridge_sha256=sha(APP/'direct_day_kernel.f90'),
                host_sha256=sha(Path(__file__)), library_sha256=sha(library), command=command)


def validate(bundle, identity, project):
    if not selected(project):
        if identity is not None:
            raise ValueError('Unselected direct day kernel')
        return
    if not identity or identity.get('protocol') != PROTOCOL or identity.get('model') != MODEL:
        raise ValueError('Missing or foreign direct day kernel; rebuild without rebinding')
    for key, path in [('bridge_sha256', APP/'direct_day_kernel.f90'),
                      ('host_sha256', Path(__file__)), ('library_sha256', library_path(bundle))]:
        if identity.get(key) != sha(path):
            raise ValueError('Direct day kernel source/build differs: ' + key)
