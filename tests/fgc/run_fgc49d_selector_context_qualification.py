"""Compile existing boundary suites with the private FGC49D module projection."""

import os
from pathlib import Path
import shlex
import subprocess
import sys
from tempfile import TemporaryDirectory

from fgc49d_oxygen_context_projection import project as project_oxygen
from fgc49d_selector_context_projection import project as project_selector


def qualify(root):
    with TemporaryDirectory(prefix="fgc49d-selectors-") as temp:
        projection = Path(temp) / "projection"
        project_oxygen(root / "src/physics/oxygen", projection)
        project_selector(root / "src", projection)
        env = dict(os.environ, OMP_NUM_THREADS="1")
        env["FGC49D_SELECTOR_PROJECTION"] = str(projection)
        env["FGC49D_SELECTOR_COMPILER"] = env.get("FC", "gfortran")
        env["FC"] = shlex.join((sys.executable, "-B", str(Path(__file__).resolve()), "--compile"))
        for suite in ("low03a", "low08a"):
            env[f"{suite.upper()}_RESULT"] = str(Path(temp) / f"{suite}.json")
            subprocess.run(
                [sys.executable, "-B", f"tests/fmig431/run_{suite}_qualification.py"],
                cwd=root, env=env, check=True,
            )


def compile_projected(args):
    compiler = shlex.split(os.environ["FGC49D_SELECTOR_COMPILER"])
    if "-c" in args:
        index = args.index("-c") + 1
        source = Path(args[index]).resolve()
        root = Path(__file__).resolve().parents[2]
        source_root = root / "src"
        if source.is_relative_to(source_root):
            relative = source.relative_to(source_root)
            if relative.parent == Path("physics/oxygen"):
                relative = Path(relative.name)
            projected = Path(os.environ["FGC49D_SELECTOR_PROJECTION"]) / relative
            if projected.is_file():
                args[index] = str(projected)
    return subprocess.call([*compiler, *args])


if __name__ == "__main__":
    if sys.argv[1:2] == ["--compile"]:
        sys.exit(compile_projected(sys.argv[2:]))
    qualify(Path(__file__).resolve().parents[2])
