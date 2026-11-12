"""F-WOF-EXT01: transport/transaction feasibility only, NOT a PCSE or SWAP integration.

Run: python3 -m unittest -v tests.fwof.ext01.test_external_crop_contract
"""
import hashlib
import json
import subprocess
import sys
import unittest


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def fingerprint(value):
    return hashlib.sha256(encoded(value)).hexdigest()


# Deliberately simple model in lieu of PCSE: test only process boundary mechanics.
WORKER = r'''
import json,sys
request=json.loads(sys.stdin.readline())
assert request["schema"] == "F-WOF-EXT01/1"
assert request["t1"] - request["t0"] == 1
s=request["state"].copy()
s["dvs"]=round(s["dvs"]+0.03, 12)
s["lai"]=round(s["lai"]+0.15, 12)
reply={"schema":"F-WOF-EXT01/1","event":request["event"],
       "candidate":s,"crop_view":{"dvs":s["dvs"],"lai":s["lai"]}}
sys.stdout.write(json.dumps(reply,sort_keys=True)+"\n")
'''


class CropBoundary:
    def __init__(self, state):
        self.state = state.copy()
        self.receipt = None

    def prepare(self, event, t0, t1):
        if self.receipt == event:
            raise ValueError("duplicate committed event")
        payload = dict(schema="F-WOF-EXT01/1", event=event, t0=t0, t1=t1,
                       state=self.state.copy())
        result = subprocess.run([sys.executable, "-c", WORKER], input=encoded(payload)+b"\n",
                                capture_output=True, check=True)
        response = json.loads(result.stdout)
        if response["event"] != event or response["schema"] != payload["schema"]:
            raise ValueError("foreign candidate")
        return response["candidate"]

    def commit(self, event, candidate):
        if self.receipt == event:
            raise ValueError("duplicate committed event")
        self.state = candidate.copy()
        self.receipt = event

    def snapshot(self):
        return dict(schema="F-WOF-EXT01/1", state=self.state.copy(), receipt=self.receipt)

    @classmethod
    def restore(cls, snapshot):
        if snapshot["schema"] != "F-WOF-EXT01/1":
            raise ValueError("incompatible schema")
        restored = cls(snapshot["state"])
        restored.receipt = snapshot["receipt"]
        return restored


class TestExternalBoundary(unittest.TestCase):
    def test_discard_recompute_commit_and_restart(self):
        a = CropBoundary(dict(dvs=0.2, lai=1.0))
        original = fingerprint(a.snapshot())
        first = a.prepare("accepted-window-42", 42, 43)
        self.assertEqual(fingerprint(a.snapshot()), original, "prepare mutated committed")
        retry = a.prepare("accepted-window-42", 42, 43)
        self.assertEqual(first, retry)
        self.assertEqual(fingerprint(a.snapshot()), original, "discard changed committed")
        a.commit("accepted-window-42", retry)
        self.assertEqual(a.state, dict(dvs=0.23, lai=1.15))
        with self.assertRaises(ValueError):
            a.prepare("accepted-window-42", 42, 43)
        restored = CropBoundary.restore(json.loads(encoded(a.snapshot())))
        self.assertEqual(fingerprint(restored.snapshot()), fingerprint(a.snapshot()))
        b1 = a.prepare("accepted-window-43", 43, 44)
        b2 = restored.prepare("accepted-window-43", 43, 44)
        self.assertEqual(b1, b2)
        a.commit("accepted-window-43", b1)
        restored.commit("accepted-window-43", b2)
        self.assertEqual(fingerprint(a.snapshot()), fingerprint(restored.snapshot()))

    def test_failed_worker_never_commits(self):
        a = CropBoundary(dict(dvs=0.1, lai=0.3))
        baseline = fingerprint(a.snapshot())
        with self.assertRaises(subprocess.CalledProcessError):
            a.prepare("bad-day", 5, 7)
        self.assertEqual(fingerprint(a.snapshot()), baseline)

    def test_schema_rejection(self):
        with self.assertRaises(ValueError):
            CropBoundary.restore(dict(schema="unknown", state={}, receipt=None))


if __name__ == "__main__":
    unittest.main()
