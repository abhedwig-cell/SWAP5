#!/usr/bin/env python3
"""Fail-closed raw-byte B1.11 MOD_meteo extractor from exact B0 SWAP.ZIP."""
import hashlib
import io
import sys
import zipfile
from pathlib import Path

ARCHIVE_SHA = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
SOURCE_SHA = "5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822"
CORRECTED_SHA = "99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f"
MEMBER = "SWAP/MOD_meteo.f90"
OLD = (
 b"         i = 1\r\n"
 b"         do while (tend - cropstart(i) > 0.d0)\r\n"
 b"            if (cropstart(i) < 1.d0) exit\r\n"
 b"            if (tend + 0.1d0 > cropstart(i) .AND. tstart - 0.1d0 < cropend(i)) then\r\n"
 b"               if (croptype(i) == 2) fl_loadmeteodata = .TRUE.\r\n"
 b"            end if\r\n"
 b"            i = i + 1\r\n"
 b"         end do\r\n"
)
NEW = (
 b"         do i = 1, ifnd\r\n"
 b"            if (tend - cropstart(i) <= 0.0d0) exit\r\n"
 b"            if (cropstart(i) < 1.0d0) exit\r\n"
 b"            if (tend + 0.1d0 > cropstart(i) .AND. tstart - 0.1d0 < cropend(i)) then\r\n"
 b"               if (croptype(i) == 2) fl_loadmeteodata = .TRUE.\r\n"
 b"            end if\r\n"
 b"         end do\r\n"
)
def sha(blob):
    return hashlib.sha256(blob).hexdigest()

def extract(raw_zip):
    if sha(raw_zip) != ARCHIVE_SHA:
        raise ValueError("B0 source archive SHA mismatch")
    with zipfile.ZipFile(io.BytesIO(raw_zip)) as z:
        names = [i.filename for i in z.infolist() if not i.is_dir()]
        if len(names) != len(set(names)) or len(names) != 63 or MEMBER not in names:
            raise ValueError("B0 source member census mismatch")
        data = z.read(MEMBER)
    if len(data) != 85550 or sha(data) != SOURCE_SHA:
        raise ValueError("B0 MOD_meteo member identity mismatch")
    if data.count(OLD) != 1:
        raise ValueError("SWAP-006 unique preimage absent")
    corrected = data.replace(OLD, NEW, 1)
    if len(corrected) != 85541 or sha(corrected) != CORRECTED_SHA:
        raise ValueError("B1.11 corrected member identity mismatch")
    return corrected

def main(argv):
    if len(argv) != 3:
        raise ValueError("usage: extract_b111_meteo.py exact_SWAP.ZIP output.f90")
    original, output = map(Path, argv[1:])
    if not original.is_file():
        raise ValueError("B0 archive missing")
    result = extract(original.read_bytes())
    if output.exists() and output.read_bytes() != result:
        raise ValueError("refusing to overwrite different existing output")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(result)
    print("B111_METEO_SOURCE_VERIFIED=" + sha(result))

if __name__ == "__main__":
    try:
        main(sys.argv)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print("B111_METEO_SOURCE_REJECTED: " + str(exc), file=sys.stderr)
        sys.exit(2)
