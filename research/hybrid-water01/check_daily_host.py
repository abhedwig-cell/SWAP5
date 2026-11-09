"""Check independent clocks and column-local refusal in the hybrid daily host."""

import argparse
import contextlib
import json
from pathlib import Path

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'app/hybrid_water'))
from daily_host import ColumnStart, DailyHost, build, checkpoint_identity, verify_checkpoint

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path, required=True, help="Day-19 package with continuous receipts through day 22")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reference = args.reference_work.resolve()
    package = args.checkpoint.resolve()
    root = args.output.resolve()
    output = root / "mixed"
    output.mkdir(parents=True)
    donor, kernel, case, inputs, identity = build(reference, output, budget_retry=True,
        shared_pond_transfer=True, refresh_macro_final=True, runtime_checkpoint=True)
    binding = checkpoint_identity(inputs, identity, budget_retry=True,
                                  shared_pond_transfer=True, refresh_macro_final=True)
    origin = output/"verified"
    receipt = verify_checkpoint(package, 19, binding, origin)
    with contextlib.ExitStack() as stack:
        host = DailyHost(stack, donor, kernel, case, output,
                         [ColumnStart(name="cold"), ColumnStart(day=19, origin=origin, receipt=receipt, name="restart")],
                         checkpoint_enabled=True, runtime=True)
        schedule = [2, 1, 1, 2, 1, 2]
        actual = [host.step(column) for column in schedule]
        host.close()
    before = [json.loads(row) for row in (package.parent/"daily.jsonl").read_text().splitlines()]
    for row in actual:
        reference_row = before[row["day"]-1]
        assert dict(row, column=1, revision=reference_row["revision"]) == reference_row
    assert [(row["column"], row["day"]) for row in actual] == [(2,20),(1,1),(1,2),(2,21),(1,3),(2,22)]
    (output/"RESULT.json").write_text(json.dumps(actual, indent=2)+"\n")
    print("Mixed clocks: six receipts exact")

    output = root / "refusal"
    output.mkdir()
    donor, kernel, case, _, _ = build(reference, output, runtime_checkpoint=True)
    with contextlib.ExitStack() as stack:
        host = DailyHost(stack, donor, kernel, case, output,
                         [ColumnStart(name="first"), ColumnStart(name="second")],
                         checkpoint_enabled=True, runtime=True, binding={})
        first = [host.step(1) for _ in range(14)]
        control = host.step(2)
        rejected = host.step(1, checkpoint=True)
        assert not rejected["committed"] and rejected["day"] == 15 and rejected["revision"] == 14
        assert host.columns[0].day == 14 and host.columns[0].stocks == first[-1]["stock_end_cm"]
        try:
            host.step(1)
        except ValueError:
            pass
        else:
            raise AssertionError("Refused column was accepted again")
        after = host.step(2)
        assert dict(control, column=1) == first[0] and dict(after, column=1) == first[1]
        assert not list(output.glob("accepted-*.zip"))
        host.close()
    (output/"RESULT.json").write_text(json.dumps({"refused": rejected, "other_column_after": after}, indent=2)+"\n")
    print("Day-15 refusal: no publication; other column continues exactly")


if __name__ == "__main__":
    main()
