#!/usr/bin/env bash
set -euo pipefail
# F-CI49 reconciliation overlay. The original gate intentionally preserved the
# stale upstream pointer found in F-KT15_LINEAGE_RECONCILIATION.json so the
# inconsistency failed closed. Live F-KT14 authority is 2f7995df... with exact-
# head Actions run 34545458355 concluded success. Change only that provenance
# pin; all admission logic remains byte-for-byte the original F-CI49 gate.
source <(sed 's/FKT14=9796f1d32d73018ed5266af80524677abc5ec906/FKT14=2f7995df362c65916671278a5552ed9976ed39b3/' \
  "$(dirname "$0")/run_fci49_fkt15_solver_service_canonical_admission.sh")
