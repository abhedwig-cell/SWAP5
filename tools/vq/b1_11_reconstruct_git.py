"""Run the existing B1.11 verifier from exact Git blobs, avoiding checkout EOL conversion."""
import argparse
import hashlib
import io
import re
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--ref", default="HEAD")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    commit = subprocess.check_output(
        ["git", "rev-parse", "--verify", args.ref + "^{commit}"], cwd=repo, text=True
    ).strip()
    archive = args.archive.resolve(strict=True)
    output = args.output_dir.resolve()
    if output.exists():
        raise SystemExit("Use a new output directory; existing reconstruction is preserved")
    raw = subprocess.check_output(
        ["git", "archive", "--format=tar", commit, "tools/vq", "reference/swap-4.3.1",
         "docs/verification"], cwd=repo
    )
    with tempfile.TemporaryDirectory(prefix="swap5-b111-git-") as temporary:
        root = Path(temporary)
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as source:
            source.extractall(root, filter="data")
        # Some branch blobs themselves contain CRLF. A scratch repair is allowed
        # only when it exactly reproduces the immutable snapshot's patch hash.
        snapshot = (root / "reference/swap-4.3.1/snapshots/B1.11.yml").read_text()
        pins = re.findall(r'patch_path: "([^"]+)"\s+patch_sha256: "([a-f0-9]{64})"', snapshot)
        if not pins:
            raise RuntimeError("No snapshot patch pins found")
        for relative, expected in pins:
            patch = (root / relative).resolve()
            if not patch.is_relative_to(root.resolve()):
                raise RuntimeError("Patch path escapes scratch directory")
            data = patch.read_bytes()
            if hashlib.sha256(data).hexdigest() != expected:
                normalized = data.replace(b"\r\n", b"\n")
                if hashlib.sha256(normalized).hexdigest() != expected:
                    raise RuntimeError(f"Patch cannot reproduce admitted bytes: {relative}")
                patch.write_bytes(normalized)
                print(f"SCRATCH_EOL_REPAIR={relative} ADMITTED_HASH_MATCH", flush=True)
        print(f"RECONSTRUCTION_TOOLING_COMMIT={commit}", flush=True)
        result = subprocess.run(
            [sys.executable, "-B", str(root / "tools/vq/b1_11_reconstruct.py"),
             "--archive", str(archive), "--output-dir", str(output)], check=False
        )
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
