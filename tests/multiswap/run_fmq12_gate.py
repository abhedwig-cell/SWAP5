import subprocess
import sys


def main():
    cmd = [
        sys.executable,
        "-m",
        "unittest",
        "tests.multiswap.test_fmq12_fkt01_admission",
    ]
    result = subprocess.run(cmd, check=False)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
