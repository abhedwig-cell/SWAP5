#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=f49e17c6627717d5dea181808a122f2e35960739
PRODUCTION=8109946c462286ef75d2ad33bbbb9faa782d19fa
UPSTREAM_SCRIPT=tests/fmq/run_fmq27_restart_requalification.sh
TMP_SCRIPT="${TMPDIR:-/tmp}/swap5-fmr24-fmq27-$$.sh"
trap 'rm -f "$TMP_SCRIPT"' EXIT

fail() { echo "FMR24_OWNER_GATE_FAIL $*" >&2; exit 1; }

[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_committed_restart.f90)" == "19ea410e0ed48e65b5d73887a8e1dba59c7c4f37" ]] || fail 'committed restart blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_restart_state_contract.f90)" == "f1359f97d02408d8b700b0c93fe961a6ba46742c" ]] || fail 'restart state contract blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_runtime_core.f90)" == "adc2b7514cc062c0cde4e71582ba8ed7776a7335" ]] || fail 'canonical runtime core drift'
[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_committed_persistence.f90)" == "ffd886c3401fc12739a456fe60a8741c12b9848b" ]] || fail 'canonical persistence contract drift'
[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == "f1acff10dd99c308a00f434440d6a9ef14632f0d" ]] || fail 'canonical transaction kernel drift'
[[ "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" == "2fd932b74dbd0ffc0ec089f49e632b7ac8852df4" ]] || fail 'canonical transaction reference drift'
[[ "$(git rev-parse HEAD:tests/fmr/test_fmr19_process_restart.f90)" == "c9f42747a00b317797a3a42859cab50d921c26fc" ]] || fail 'F-MQ27 process test provenance drift'
[[ "$(git rev-parse HEAD:tests/fmq/test_fmq27_restart_contract_requalification.f90)" == "cb5e6973a8a5d207e6dffa657d2539224826072d" ]] || fail 'F-MQ27 negative test provenance drift'
[[ "$(git rev-parse HEAD:$UPSTREAM_SCRIPT)" == "bc286201b40722b40ddb6083666603872c6fa065" ]] || fail 'F-MQ27 runner provenance drift'

mapfile -t src_delta < <(git diff --name-only "$BASE".."$PRODUCTION" -- src | sort)
printf '%s\n' "${src_delta[@]}" > "${TMP_SCRIPT}.src"
printf '%s\n' src/runtime/mod_fmr_committed_restart.f90 src/runtime/mod_fmr_restart_state_contract.f90 | sort > "${TMP_SCRIPT}.expected"
cmp -s "${TMP_SCRIPT}.src" "${TMP_SCRIPT}.expected" || { cat "${TMP_SCRIPT}.src" >&2; rm -f "${TMP_SCRIPT}.src" "${TMP_SCRIPT}.expected"; fail 'production delta is not exactly two restart files'; }
rm -f "${TMP_SCRIPT}.src" "${TMP_SCRIPT}.expected"
[[ -z "$(git diff --name-only "$PRODUCTION"..HEAD -- src)" ]] || fail 'production source drift after recomposition commit'
echo 'FMR24_EXACT_CANONICAL_TWO_FILE_RECOMPOSITION=PASS'
echo 'FMR24_EXACT_FMR21_PRODUCTION_BLOB_IDENTITY=PASS'
echo 'FMR24_CANONICAL_CORE_DEPENDENCY_LOCK=PASS'
echo 'FMR24_EXACT_FMQ27_TEST_PROVENANCE=PASS'

cp "$UPSTREAM_SCRIPT" "$TMP_SCRIPT"
sed -i \
  -e 's/CANDIDATE=9064004f815e81f95eb4bdee218af29cb95039c1/CANDIDATE=8109946c462286ef75d2ad33bbbb9faa782d19fa/' \
  -e 's/OLD=dfffd8535b3345b105b2d71537d8149225f35c54/OLD=f49e17c6627717d5dea181808a122f2e35960739/' \
  -e 's/"$CANDIDATE":tests\/fmr\/test_fmr19_process_restart.f90/HEAD:tests\/fmr\/test_fmr19_process_restart.f90/' \
  "$TMP_SCRIPT"
chmod +x "$TMP_SCRIPT"

bash "$TMP_SCRIPT"
echo 'FMR24_OWNER_CANONICAL_RECOMPOSITION_GATE=PASS'
