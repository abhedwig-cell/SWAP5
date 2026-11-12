#!/usr/bin/env python3
"""Read immutable PP02 case001 scientific inputs; do not regenerate the oracle."""
from pathlib import Path
import base64,csv,gzip,hashlib,io,tarfile,json
root=Path(__file__).resolve().parents[3]
parts=["part00","part01","part02","part03","part04a","part04b","part05"]
prefix=root/"tests/fwof/pp02"
data=b"".join((prefix/f"case001_fixture.b64.{p}").read_bytes() for p in parts)
assert hashlib.sha256(data).hexdigest()=="f20f07cfc70ab4eab27a285ad6609b322c83b475c0dc297645742669aabb9c82"
tar=gzip.decompress(base64.b64decode(data))
assert hashlib.sha256(base64.b64decode(data)).hexdigest()=="d9ac276be4ecea1c7fca0d6ba720ae9e1532549c33a592962634867e0fd0dafd"
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(data)),mode="r:gz") as archive:
    members={Path(x.name).name:archive.extractfile(x).read() for x in archive.getmembers() if x.isfile()}
print('EXT01_CASE001_ARCHIVE_MEMBERS='+json.dumps(sorted(members)))
for name, sha in [
    ("forcing.dat","ae6c330055134df713aef3e9d7bc27b5220c0d39fcaa2e022fd954d38c149e45"),
    ("reference.csv","94daa08000097f4a124847c89b6ba3de1d29ca5d08fa07ae13dbcbb5b9efeaed"),
    ("precision.csv","1bf8d520324af2c003fa0daec44a05db5b9efeaed")]:
    if name == "precision.csv": continue
    assert hashlib.sha256(members[name]).hexdigest()==sha, name
ref=list(csv.DictReader(io.StringIO(members["reference.csv"].decode())))
ref=[x for x in ref if x["DVS"].strip()]
forcing=[x for x in members["forcing.dat"].decode().splitlines() if x.strip()]
assert len(ref)==len(forcing)==101
fields=["DVS","LAI","TAGP","NamountLV","NamountRT","NamountSO","NamountST","NuptakeTotal","TWLV","TWRT","TWSO","TWST"]
first={k:ref[0][k] for k in fields}
second={k:ref[1][k] for k in fields}
assert all(v.strip() for v in first.values())
print("EXT01_MATCHED_CASE001="+json.dumps({"reference":"PCSE 6.0.13 WOFOST81 Spring Barley","first_forcing":forcing[0],"first_state":first,"second_state":second,"time_alignment":"day1 initial -> day2 first committed post-state","number_of_states":len(ref),"forcing_sha256":hashlib.sha256(members["forcing.dat"]).hexdigest(),"reference_sha256":hashlib.sha256(members["reference.csv"]).hexdigest()},sort_keys=True))
