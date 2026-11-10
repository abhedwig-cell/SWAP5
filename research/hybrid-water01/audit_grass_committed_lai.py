"""Check daily crop publication against committed Grassgrowth restart state."""
import argparse
import csv
from hashlib import sha256
from io import StringIO
import json
from math import fsum
from pathlib import Path
import struct
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/dataqual15"))
from checkpoint_layout import layout, payload


def rows(raw):
    return list(csv.DictReader(line for line in StringIO(raw.decode())
                               if line.strip() and not line.startswith("*")))


def read(folder, filename):
    return rows((folder / filename).read_bytes())


def lai(raw):
    state = layout(raw)
    crop = state["actual"]
    n = crop["leaves"]
    # Three living organ stocks, three mortality diagnostics, LAIEXP,
    # and two retained-dead stocks precede the three cohort arrays.
    offset = crop["start"] + 12
    _, stem, pod = struct.unpack_from("=3d", raw, offset)
    masses = struct.unpack_from(f"={n}d", raw, offset + 72)
    areas = struct.unpack_from(f"={n}d", raw, offset + 72 + 8*n)
    value = fsum(m*a for m,a in zip(masses,areas,strict=True)) + 0.0004*stem + 0.0*pod
    return int(state["clock"]), value


def residuals(budget, crop, original):
    fields = {"water_stock_cm":(budget,"water_end_cm","WTOT"),
              "uptake_cm":(budget,"uptake_cm","TACT"), "oxygen_loss_cm":(budget,"oxygen_cm","TREDWET"),
              "leaf_biomass_kg_ha":(crop,"wlv","WLV")}
    values = {}
    for label,(native,new,old) in fields.items():
        d,row = max(enumerate(native,1),
                    key=lambda item:abs(float(item[1][new])-float(original[item[0]][old])))
        values[label] = {"day":d,"date":original[d]["DATE"],
                         "native_minus_original":float(row[new])-float(original[d][old])}
    return values


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ("full","resume","predecessor","build"):
        parser.add_argument("--"+name,type=Path,required=True)
    args=parser.parse_args()
    capsule=ROOT/"integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz"
    archive_sha=sha256(capsule.read_bytes()).hexdigest()
    manifest=json.loads((ROOT/"integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json").read_text())
    assert archive_sha==manifest["evidence_sha256"]
    with tarfile.open(capsule) as t:
        prefix="dq15-union-oxygen-full-O2"
        old_crop=rows(t.extractfile(prefix+"/crop.csv").read())
        old_water=rows(t.extractfile(prefix+"/budget.csv").read())
        original=rows(t.extractfile("dq15-original-nodal-reference/original/result_output.csv").read())
        assert len(old_crop)==len(old_water)==1827 and len(original)==1828
        historical=[]
        for day in (126,127,140,918,1827):
            filename="checkpoint.bin" if day==1827 else f"checkpoint-{day}.bin"
            d,committed=lai(t.extractfile(f"{prefix}/{filename}").read())
            assert d==day
            historical.append({"day":day,"published_lai":float(old_crop[d-1]["lai"]),
                               "committed_lai":committed,"original_lai":float(original[d]["LAI"])})

    full,resume=args.full,args.resume
    for name in ("crop.csv","budget.csv","conductive_budget.csv"):
        assert read(full,name)[126:]==read(resume,name),name
    assert (full/"checkpoint.bin").read_bytes()==(resume/"checkpoint.bin").read_bytes()
    crop=read(full,"crop.csv")
    assert [int(row["day"]) for row in crop]==list(range(1,129))
    local=[]
    for day in (126,127,128):
        path=full/("checkpoint.bin" if day==128 else f"checkpoint-{day}.bin")
        d,expected=lai(path.read_bytes())
        actual=float(crop[day-1]["lai"])
        assert d==day and abs(actual-expected)<1e-12
        local.append({"day":day,"published_lai":actual,"committed_lai":expected,
                      "original_lai":float(original[day]["LAI"]),
                      "leaf_biomass_kg_ha":float(crop[day-1]["wlv"])})
    assert local[0]["published_lai"]>local[1]["published_lai"]==local[2]["published_lai"]
    assert read(full,"budget.csv")==read(args.predecessor,"budget.csv")[:128]
    assert payload((full/"checkpoint-126.bin").read_bytes())==payload((args.predecessor/"checkpoint-126.bin").read_bytes())
    predecessor=read(args.predecessor,"crop.csv")[:128]
    differences={name:max(abs(float(a[name])-float(b[name])) for a,b in zip(crop,predecessor,strict=True))
                 for name in crop[0] if name!="lai"}
    assert max(differences.values())<1e-10
    build=json.loads((args.build/"BUILD.json").read_text())
    print(json.dumps({
        "archive_sha256":archive_sha,"archived_committed_lai_examples":historical,
        "retained_remaining_differences":residuals(old_water,old_crop,original),
        "candidate_mowing_window":local,"own_day126_restart_exact":True,
        "predecessor_water_budget_and_day126_physical_payload_exact":True,
        "maximum_other_crop_field_differences_vs_previous_default":differences,
        "candidate_build":{"compiler":build["compiler"],"executable_sha256":build["executable_sha256"],
                           "input_sha256":build["original_inputs_sha256"]},
    },indent=2))


if __name__=="__main__":
    main()
