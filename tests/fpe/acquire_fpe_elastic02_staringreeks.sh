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
mapfile -t CANDIDATES < <(grep -iE 'staring.*(pars|param).*2018.*\.csv$|staringreek.*\.csv$' "$TMP/members.txt" || true)
if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  mapfile -t CANDIDATES < <(grep -iE '\.csv$' "$TMP/members.txt" || true)
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
for r in rows:
    for k,v in r.items():
        if k and k.strip().lower() in {"name","naam","bouwsteen","soil","code"} and v:
            names.append(v.strip().upper())
            break
want=[f"B{i:02d}" for i in range(1,19)]+[f"O{i:02d}" for i in range(1,19)]
if len(rows)==36 and sorted(names)==sorted(want) and len(set(names))==36:
    print("F_PE_ELASTIC02_VALIDATED_CSV=YES")
    raise SystemExit(0)
raise SystemExit(1)
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
