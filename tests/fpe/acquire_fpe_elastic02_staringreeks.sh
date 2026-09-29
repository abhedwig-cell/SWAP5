#!/usr/bin/env bash
set -euo pipefail
URL="https://nhi.nu/documents/224/staringreeks_1.0.0.zip"
TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic02-source-$$"
mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
ZIP="$TMP/staringreeks_1.0.0.zip"
curl --fail --location --retry 3 --silent --show-error "$URL" -o "$ZIP"
echo "F_PE_ELASTIC02_ZIP_SHA256=$(sha256sum "$ZIP" | awk '{print $1}')"
echo "F_PE_ELASTIC02_ZIP_BYTES=$(wc -c < "$ZIP")"
unzip -Z1 "$ZIP" | tee "$TMP/members.txt"
mapfile -t CANDIDATES < <(grep -iE '(^|/)staringreeks_2018\.csv$' "$TMP/members.txt" || true)
if [ "${#CANDIDATES[@]}" -ne 1 ]; then
  printf 'F_PE_ELASTIC02_CANDIDATE=%s\n' "${CANDIDATES[@]}"
  echo "F_PE_ELASTIC02_FAIL=expected exactly one staringreeks_2018.csv" >&2
  exit 1
fi
printf 'F_PE_ELASTIC02_CANDIDATE=%s\n' "${CANDIDATES[@]}"
FOUND=""
for m in "${CANDIDATES[@]}"; do
  out="$TMP/$(basename "$m")"
  unzip -p "$ZIP" "$m" > "$out"
  python3 - "$out" <<'PY' && { FOUND="$out"; break; } || true
import csv,sys
p=sys.argv[1]
text=open(p,encoding='utf-8-sig',errors='replace').read().splitlines()
if not text: raise SystemExit(1)
dialect=csv.Sniffer().sniff("\n".join(text[:5]),delimiters=",;\t")
rows=list(csv.DictReader(text,dialect=dialect))
names=[]
years=[]
for r in rows:
    low={str(k).strip().lower():v for k,v in r.items() if k is not None}
    name=(low.get("name") or low.get("naam") or low.get("bouwsteen") or low.get("soil") or low.get("code") or "").strip().upper()
    if name: names.append(name)
    if "year" in low and low["year"] is not None: years.append(str(low["year"]).strip())
want=[f"B{i:02d}" for i in range(1,19)]+[f"O{i:02d}" for i in range(1,19)]
if len(rows)!=36 or sorted(names)!=sorted(want) or len(set(names))!=36:
    raise SystemExit(1)
if years and set(years)!={"2018"}:
    raise SystemExit(1)
required={"wcr","wcs","alpha","npar","lambda","ksfit"}
header={h.strip().lower() for h in (rows[0].keys() if rows else []) if h}
if not required.issubset(header):
    raise SystemExit(1)
print("F_PE_ELASTIC02_VALIDATED_CSV=YES")
raise SystemExit(0)
PY
done
if [ -z "$FOUND" ]; then
  echo "F_PE_ELASTIC02_FAIL=no exact 36-material CSV found" >&2
  exit 1
fi
echo "F_PE_ELASTIC02_CSV_FILE=$(basename "$FOUND")"
echo "F_PE_ELASTIC02_CSV_SHA256=$(sha256sum "$FOUND" | awk '{print $1}')"
echo "F_PE_ELASTIC02_CSV_BYTES=$(wc -c < "$FOUND")"
echo "F_PE_ELASTIC02_CSV_HEADER=$(head -n1 "$FOUND" | tr -d '\r')"
echo "F_PE_ELASTIC02_CSV_ROWS=$(($(wc -l < "$FOUND")-1))"
echo "F_PE_ELASTIC02_SOURCE=PASS"
