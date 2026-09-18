from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "src" / "adapter" / "modflow6_xmi_package_adapter.py"
SPEC = importlib.util.spec_from_file_location("fgc35_adapter", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MOD = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MOD
SPEC.loader.exec_module(MOD)

Adapter = MOD.Modflow6XmiPackageAdapter
Status = MOD.Modflow6XmiAdapterStatus


class FakeArray:
    def __init__(self, values: list[Any], dtype: str) -> None:
        self.values = list(values)
        self.dtype = dtype

    def __len__(self) -> int:
        return len(self.values)

    def __getitem__(self, index: int) -> Any:
        return self.values[index]

    def __setitem__(self, index: int, value: Any) -> None:
        self.values[index] = value

    def snapshot(self) -> tuple[Any, ...]:
        return tuple(self.values)


class FakeXmiKernel:
    def __init__(self) -> None:
        self.phase = "initialized"
        self.address_calls: list[tuple[str, str, str]] = []
        self.pointer_calls: list[str] = []
        self.prepared_generation = 0
        self.initial = self._make_views(node_values=[-1])
        self.prepared = self._make_views(node_values=[-1, -1])

    def _make_views(self, node_values: list[int]) -> dict[str, FakeArray]:
        return {
            "NODELIST": FakeArray(node_values, "int32"),
            "HCOF": FakeArray([0.0, 0.0], "float64"),
            "RHS": FakeArray([0.0, 0.0], "float64"),
            "MAXBOUND": FakeArray([2], "int32"),
            "NBOUND": FakeArray([0], "int32"),
        }

    def get_var_address(
        self, var_name: str, component_name: str, subcomponent_name: str = ""
    ) -> str:
        self.address_calls.append((var_name, component_name, subcomponent_name))
        return f"{component_name}/{subcomponent_name}/{var_name}"

    def get_value_ptr(self, address: str) -> FakeArray:
        self.pointer_calls.append(address)
        variable = address.rsplit("/", 1)[-1]
        views = self.initial if self.phase == "initialized" else self.prepared
        return views[variable]

    def host_prepare_time_step(self) -> None:
        # This represents external host ownership. The adapter never calls it.
        self.phase = "prepared"
        self.prepared_generation += 1
        self.prepared = self._make_views(node_values=[-1, -1])


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def make_publisher(expected_bindings: Any, expected_terms: Any, expected_kernel: FakeXmiKernel):
    calls: list[tuple[Any, ...]] = []

    def publisher(
        bindings: Any,
        terms: Any,
        maxbound: int,
        nodelist: FakeArray,
        hcof: FakeArray,
        rhs: FakeArray,
        nbound: FakeArray,
    ) -> int:
        calls.append((bindings, terms, maxbound, nodelist, hcof, rhs, nbound))
        require(bindings is expected_bindings, "bindings were copied/transformed")
        require(terms is expected_terms, "terms were copied/transformed")
        require(maxbound == 2, "MAXBOUND value was not forwarded")
        require(nodelist is expected_kernel.prepared["NODELIST"], "stale NODELIST view forwarded")
        require(hcof is expected_kernel.prepared["HCOF"], "stale HCOF view forwarded")
        require(rhs is expected_kernel.prepared["RHS"], "stale RHS view forwarded")
        require(nbound is expected_kernel.prepared["NBOUND"], "stale NBOUND view forwarded")

        # Minimal stand-in for the already-qualified F-GC34 publisher.
        nodelist[0] = 42
        nodelist[1] = 42
        hcof[0] = 250.0
        hcof[1] = 1750.0
        rhs[0] = -10.0
        rhs[1] = 1747.5
        nbound[0] = 2
        return 0

    return publisher, calls


def test_exact_address_and_pointer_acquisition() -> None:
    kernel = FakeXmiKernel()
    adapter = Adapter(kernel, "GWF_1", "API_SWAP")

    status = adapter.acquire_after_initialize()
    require(status == Status.OK, f"initial acquisition failed: {adapter.last_error}")

    expected_vars = ["NODELIST", "HCOF", "RHS", "MAXBOUND", "NBOUND"]
    require(
        kernel.address_calls
        == [(var, "GWF_1", "API_SWAP") for var in expected_vars],
        "unexpected get_var_address call set/order",
    )
    require(
        kernel.pointer_calls
        == [f"GWF_1/API_SWAP/{var}" for var in expected_vars],
        "unexpected initial get_value_ptr call set/order",
    )
    require(not adapter.publication_open, "initial acquisition opened publication window")

    print("FGC35_EXACT_XMI_ADDRESS_ACQUISITION=PASS")


def test_refresh_excludes_stale_nodelist_and_controls_window() -> None:
    kernel = FakeXmiKernel()
    adapter = Adapter(kernel, "GWF_1", "API_SWAP")
    require(adapter.acquire_after_initialize() == Status.OK, adapter.last_error)

    bindings = object()
    terms = object()
    publisher, calls = make_publisher(bindings, terms, kernel)

    status = adapter.publish_via_fgc34(bindings, terms, publisher)
    require(status == Status.PUBLICATION_WINDOW_CLOSED, "publication allowed before prepare refresh")
    require(kernel.initial["NODELIST"].snapshot() == (-1,), "pre-timestep NODELIST mutated")

    status = adapter.close_before_prepare_solve()
    require(status == Status.PUBLICATION_WINDOW_CLOSED, "close unexpectedly allowed before refresh")

    kernel.host_prepare_time_step()
    initial_pointer_call_count = len(kernel.pointer_calls)
    status = adapter.refresh_after_prepare_time_step()
    require(status == Status.OK, f"post-prepare refresh failed: {adapter.last_error}")
    require(adapter.publication_open, "refresh did not open publication window")
    require(adapter.generation == 1, "generation did not advance")
    require(
        kernel.pointer_calls[initial_pointer_call_count:]
        == [f"GWF_1/API_SWAP/{var}" for var in ["NODELIST", "HCOF", "RHS", "MAXBOUND", "NBOUND"]],
        "refresh did not reacquire all package views",
    )

    status = adapter.close_before_prepare_solve()
    require(status == Status.MISSING_PUBLICATION, "solve boundary accepted without F-GC34 publication")
    require(adapter.publication_open, "failed close incorrectly closed publication window")

    status = adapter.publish_via_fgc34(bindings, terms, publisher)
    require(status == Status.OK, f"publisher seam failed: {adapter.last_error}")
    require(len(calls) == 1, "publisher call count mismatch")
    require(adapter.published_generation == 1, "published generation not recorded")

    require(kernel.initial["NODELIST"].snapshot() == (-1,), "stale initial NODELIST was mutated")
    require(kernel.prepared["NODELIST"].snapshot() == (42, 42), "live NODELIST not published")
    require(kernel.prepared["HCOF"].snapshot() == (250.0, 1750.0), "live HCOF not published")
    require(kernel.prepared["RHS"].snapshot() == (-10.0, 1747.5), "live RHS not published")
    require(kernel.prepared["NBOUND"].snapshot() == (2,), "live NBOUND not published")

    status = adapter.close_before_prepare_solve()
    require(status == Status.OK, f"valid solve-boundary close failed: {adapter.last_error}")
    require(not adapter.publication_open, "publication window remained open before solve")

    status = adapter.publish_via_fgc34(bindings, terms, publisher)
    require(status == Status.PUBLICATION_WINDOW_CLOSED, "late publication allowed after solve boundary")

    print("FGC35_STALE_PRETIMESTEP_NODELIST_EXCLUDED=PASS")
    print("FGC35_FGC34_PUBLISHER_PASSTHROUGH=PASS")
    print("FGC35_PUBLICATION_WINDOW_GUARD=PASS")


def test_new_timestep_requires_new_publication() -> None:
    kernel = FakeXmiKernel()
    adapter = Adapter(kernel, "GWF_1", "API_SWAP")
    require(adapter.acquire_after_initialize() == Status.OK, adapter.last_error)

    bindings = object()
    terms = object()

    kernel.host_prepare_time_step()
    require(adapter.refresh_after_prepare_time_step() == Status.OK, adapter.last_error)
    publisher, _ = make_publisher(bindings, terms, kernel)
    require(adapter.publish_via_fgc34(bindings, terms, publisher) == Status.OK, adapter.last_error)
    require(adapter.close_before_prepare_solve() == Status.OK, adapter.last_error)

    kernel.host_prepare_time_step()
    require(adapter.refresh_after_prepare_time_step() == Status.OK, adapter.last_error)
    require(adapter.generation == 2, "second timestep generation not advanced")
    status = adapter.close_before_prepare_solve()
    require(status == Status.MISSING_PUBLICATION, "previous generation publication leaked into new timestep")

    print("FGC35_PER_TIMESTEP_PUBLICATION_REQUIRED=PASS")


def test_pointer_validation_fail_closed() -> None:
    # Malformed scalar view during acquisition.
    kernel = FakeXmiKernel()
    kernel.initial["MAXBOUND"] = FakeArray([], "int32")
    adapter = Adapter(kernel, "GWF_1", "API_SWAP")
    require(
        adapter.acquire_after_initialize() == Status.INVALID_POINTERS,
        "empty MAXBOUND was accepted",
    )
    require(not adapter.publication_open, "invalid acquisition opened publication window")

    # Insufficient refreshed NODELIST capacity.
    kernel = FakeXmiKernel()
    adapter = Adapter(kernel, "GWF_1", "API_SWAP")
    require(adapter.acquire_after_initialize() == Status.OK, adapter.last_error)
    kernel.host_prepare_time_step()
    kernel.prepared["NODELIST"] = FakeArray([-1], "int32")
    require(
        adapter.refresh_after_prepare_time_step() == Status.INVALID_POINTERS,
        "short NODELIST was accepted",
    )
    require(not adapter.publication_open, "invalid refresh opened publication window")

    # Wrong exposed dtype.
    kernel = FakeXmiKernel()
    adapter = Adapter(kernel, "GWF_1", "API_SWAP")
    require(adapter.acquire_after_initialize() == Status.OK, adapter.last_error)
    kernel.host_prepare_time_step()
    kernel.prepared["HCOF"] = FakeArray([0.0, 0.0], "float32")
    require(
        adapter.refresh_after_prepare_time_step() == Status.INVALID_POINTERS,
        "float32 HCOF was accepted",
    )
    require(not adapter.publication_open, "dtype failure opened publication window")

    # Failed F-GC34 result must not count as publication.
    kernel = FakeXmiKernel()
    adapter = Adapter(kernel, "GWF_1", "API_SWAP")
    require(adapter.acquire_after_initialize() == Status.OK, adapter.last_error)
    kernel.host_prepare_time_step()
    require(adapter.refresh_after_prepare_time_step() == Status.OK, adapter.last_error)

    def rejected_publisher(*args: Any) -> int:
        return 7

    require(
        adapter.publish_via_fgc34(object(), object(), rejected_publisher)
        == Status.PUBLISHER_FAILED,
        "nonzero F-GC34 status was accepted",
    )
    require(adapter.last_publisher_status == 7, "publisher status not retained")
    require(
        adapter.close_before_prepare_solve() == Status.MISSING_PUBLICATION,
        "failed F-GC34 publication satisfied solve-boundary guard",
    )

    print("FGC35_POINTER_VALIDATION_FAIL_CLOSED=PASS")
    print("FGC35_FAILED_PUBLISHER_NOT_ADMITTED=PASS")


def main() -> None:
    test_exact_address_and_pointer_acquisition()
    test_refresh_excludes_stale_nodelist_and_controls_window()
    test_new_timestep_requires_new_publication()
    test_pointer_validation_fail_closed()
    print("FGC35_XMI_PACKAGE_ADAPTER_GATE=PASS")


if __name__ == "__main__":
    main()
