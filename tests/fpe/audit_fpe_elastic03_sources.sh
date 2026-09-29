#!/usr/bin/env bash
set -euo pipefail
URL="https://nhi.nu/documents/224/staringreeks_1.0.0.zip"
TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic03-source-$$"
mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
ZIP="$TMP/staringreeks_1.0.0.zip"
curl --fail --location --retry 3 --silent --show-error "$URL" -o "$ZIP"

for member in   staringreeks/Data/unit_properties_2018.csv   staringreeks/Data/allsamples_2018.csv   staringreeks/Data/staringreeks_2018.csv
do
  out="$TMP/$(basename "$member")"
  unzip -p "$ZIP" "$member" > "$out"
  echo "F_PE_ELASTIC03_MEMBER=$member"
  echo "F_PE_ELASTIC03_SHA256=$(sha256sum "$out" | awk '{print $1}')"
  echo "F_PE_ELASTIC03_BYTES=$(wc -c < "$out")"
  echo "F_PE_ELASTIC03_HEADER=$(head -n1 "$out" | tr -d '\r')"
  echo "F_PE_ELASTIC03_ROWS=$(($(wc -l < "$out")-1))"
done

echo "F_PE_ELASTIC03_UNIT_PROPERTIES_BEGIN"
cat "$TMP/unit_properties_2018.csv"
echo "F_PE_ELASTIC03_UNIT_PROPERTIES_END"

python3 - "$TMP/allsamples_2018.csv" <<'PY'
import csv,json,sys
p=sys.argv[1]
with open(p,encoding="utf-8-sig",errors="replace",newline="") as f:
    rows=list(csv.DictReader(f))
print("F_PE_ELASTIC03_ALLSAMPLES_COLUMNS="+json.dumps(list(rows[0].keys()) if rows else []))
print("F_PE_ELASTIC03_ALLSAMPLES_SAMPLE="+json.dumps(rows[:3],separators=(",",":"),sort_keys=True))
PY
echo "F_PE_ELASTIC03_SOURCE_AUDIT=PASS"
