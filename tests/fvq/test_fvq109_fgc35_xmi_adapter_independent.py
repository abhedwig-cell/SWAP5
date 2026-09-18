from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "src" / "adapter" / "modflow6_xmi_package_adapter.py"
SPEC = importlib.util.spec_from_file_location("fvq109_adapter", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MOD = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MOD
SPEC.loader.exec_module(MOD)

Adapter = MOD.Modflow6XmiPackageAdapter
Status = MOD.Modflow6XmiAdapterStatus


class Buffer:
    def __init__(self, values: list[Any], dtype: str) -> None:
        self._v = list(values)
        self.dtype = dtype
    def __len__(self) -> int:
        return len(self._v)
    def __getitem__(self, i: int) -> Any:
        return self._v[i]
    def __setitem__(self, i: int, value: Any) -> None:
        self._v[i] = value
    def snapshot(self) -> tuple[Any, ...]:
        return tuple(self._v)


class Kernel:
    def __init__(self) -> None:
        self.address_log: list[tuple[str,str,str]] = []
        self.ptr_log: list[str] = []
        self.cycle = 0
        self.views = self._new_views(short_node=True)

    def _new_views(self, short_node: bool=False) -> dict[str, Buffer]:
        n = 1 if short_node else 3
        return {
            "NODELIST": Buffer([-900] * n, "int32"),
            "HCOF": Buffer([0.0,0.0,0.0], "float64"),
            "RHS": Buffer([0.0,0.0,0.0], "float64"),
            "MAXBOUND": Buffer([3], "int32"),
            "NBOUND": Buffer([0], "int32"),
        }

    def get_var_address(self, var: str, model: str, package: str="") -> str:
        self.address_log.append((var,model,package))
        return f"{model}|{package}|{var}"

    def get_value_ptr(self, addr: str) -> Buffer:
        self.ptr_log.append(addr)
        return self.views[addr.split("|")[-1]]

    def host_prepare(self) -> dict[str, Buffer]:
        old=self.views
        self.cycle += 1
        self.views=self._new_views(short_node=False)
        return old


def require(ok: bool, msg: str) -> None:
    if not ok:
        raise AssertionError(msg)


def success_publisher(expected_kernel: Kernel, seen: list[tuple[Any,...]]):
    def pub(bindings: Any, terms: Any, maxbound: int, nodelist: Buffer,
            hcof: Buffer, rhs: Buffer, nbound: Buffer) -> int:
        seen.append((bindings,terms,maxbound,nodelist,hcof,rhs,nbound))
        require(maxbound == 3, "maxbound forwarding")
        require(nodelist is expected_kernel.views["NODELIST"], "NODELIST not current live view")
        require(hcof is expected_kernel.views["HCOF"], "HCOF not current live view")
        require(rhs is expected_kernel.views["RHS"], "RHS not current live view")
        require(nbound is expected_kernel.views["NBOUND"], "NBOUND not current live view")
        nodelist[0]=101; nodelist[1]=102; nodelist[2]=103
        hcof[0]=1.0; hcof[1]=2.0; hcof[2]=3.0
        rhs[0]=11.0; rhs[1]=12.0; rhs[2]=13.0
        nbound[0]=3
        return 0
    return pub


def lifecycle_generation_oracle() -> None:
    k=Kernel()
    a=Adapter(k,"MODEL_A","API_BND")
    require(a.acquire_after_initialize() == Status.OK, a.last_error)
    require(not a.publication_open, "initial acquire opened window")

    expected=["NODELIST","HCOF","RHS","MAXBOUND","NBOUND"]
    require(k.address_log == [(v,"MODEL_A","API_BND") for v in expected], "address contract")
    initial_ptr_count=len(k.ptr_log)

    bindings=object(); terms=object(); seen=[]
    require(a.publish_via_fgc34(bindings,terms,success_publisher(k,seen)) == Status.PUBLICATION_WINDOW_CLOSED,
            "publish before host prepare admitted")

    pre=k.host_prepare()
    require(a.refresh_after_prepare_time_step() == Status.OK, a.last_error)
    require(a.generation == 1 and a.publication_open, "generation 1 not opened")
    require(k.ptr_log[initial_ptr_count:] == [f"MODEL_A|API_BND|{v}" for v in expected], "refresh address reuse")

    pub=success_publisher(k,seen)
    require(a.publish_via_fgc34(bindings,terms,pub) == Status.OK, a.last_error)
    require(seen[-1][0] is bindings and seen[-1][1] is terms, "payload transformed")
    require(pre["NODELIST"].snapshot() == (-900,), "stale initial node view mutated")
    require(a.close_before_prepare_solve() == Status.OK, a.last_error)

    old_live=k.host_prepare()
    require(a.refresh_after_prepare_time_step() == Status.OK, a.last_error)
    require(a.generation == 2, "generation did not advance")
    require(a.close_before_prepare_solve() == Status.MISSING_PUBLICATION,
            "previous generation satisfied new solve boundary")
    require(old_live["NBOUND"].snapshot() == (3,), "prior live buffer unexpectedly changed")

    print("FVQ109_GENERATION_ISOLATION_ORACLE=PASS")
    print("FVQ109_LIVE_POINTER_IDENTITY_ORACLE=PASS")
    print("FVQ109_EXACT_ADDRESS_REUSE_ORACLE=PASS")


def failure_state_oracle() -> None:
    k=Kernel()
    a=Adapter(k,"MODEL_A","API_BND")
    require(a.acquire_after_initialize() == Status.OK, a.last_error)
    k.host_prepare()
    require(a.refresh_after_prepare_time_step() == Status.OK, a.last_error)

    before={name:buf.snapshot() for name,buf in k.views.items()}

    def reject(*args: Any) -> int:
        return 41

    require(a.publish_via_fgc34(object(),object(),reject) == Status.PUBLISHER_FAILED,
            "nonzero publisher accepted")
    require(a.last_publisher_status == 41, "publisher code not retained")
    require(a.close_before_prepare_solve() == Status.MISSING_PUBLICATION,
            "failed publication opened solve boundary")
    after={name:buf.snapshot() for name,buf in k.views.items()}
    require(before == after, "adapter mutated package on rejected publisher")

    # Invalid refreshed pointer must close the publication window.
    k.host_prepare()
    k.views["RHS"] = Buffer([0.0], "float64")
    require(a.refresh_after_prepare_time_step() == Status.INVALID_POINTERS, "short RHS accepted")
    require(not a.publication_open, "invalid pointer refresh left window open")

    print("FVQ109_FAILED_PUBLICATION_STATE_ORACLE=PASS")
    print("FVQ109_INVALID_REFRESH_FAIL_CLOSED=PASS")


def main() -> None:
    lifecycle_generation_oracle()
    failure_state_oracle()
    print("FVQ109_INDEPENDENT_XMI_ADAPTER_GATE=PASS")


if __name__ == "__main__":
    main()
