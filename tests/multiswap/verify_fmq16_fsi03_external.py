import argparse
import pathlib

EXPECTED_ADAPTER_BLOB = "84366a4b312a86806cc3aa78a7257c3a7a95d2f1"


def fail(message):
    raise SystemExit(message)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adapter", required=True)
    parser.add_argument("--fsi03-test", required=True)
    args = parser.parse_args()

    adapter = pathlib.Path(args.adapter).read_text()
    test = pathlib.Path(args.fsi03_test).read_text()

    required_adapter_tokens = (
        "type, extends(soil_water_solver_t), public :: reference_richards_legacy_solver_t",
        "type, extends(soil_water_solver_workspace_base_t), public :: reference_richards_legacy_workspace_t",
        "call headcalc(ws%legacy_worker)",
        "result%candidate_state%pressure_head = h(1:numnod)",
        "h(1:numnod) = h_saved",
        "theta(1:numnod) = theta_saved",
        "qtop = qtop_saved",
        "qbot = qbot_saved",
        "result%unrounded_mass_balance_residual = ieee_value(0.0_real64, ieee_quiet_nan)",
        "legacy-macropore-deferred",
        "legacy-implicit-k-deferred",
    )
    for token in required_adapter_tokens:
        if token not in adapter:
            fail(f"missing F-SI03 adapter token: {token}")

    forbidden_adapter_tokens = (
        "result%interface_sensitivity%available = .true.",
        "result%unrounded_mass_balance_residual = 0.0_real64",
    )
    for token in forbidden_adapter_tokens:
        if token in adapter:
            fail(f"unexpected admitted capability in unqualified F-SI03 adapter: {token}")

    if "== 0.0_real64" not in test:
        fail("expected strict REAL equality comparison signature not found in F-SI03 test")

    print("FMQ16_FSI03_EXTERNAL_BARRIER PASS")


if __name__ == "__main__":
    main()
