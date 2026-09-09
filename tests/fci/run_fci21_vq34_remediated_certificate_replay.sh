#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SOURCE_COMMIT=a0331164a8dfc2642becdbe96cab969eabead392
POSTIMAGE=integration/f-ci/F-CI21_MATERIALIZED_SOURCE_POSTIMAGE.json
POSTIMAGE_BLOB=868cf8c52c02a6a9b40bd09ad9f51b7c0b635de4
AUTH_COMMIT=31e3f85ae83fe8bab9554da5467de0598446c0bd
AUTH_REF=refs/fci21-vq34-authority
AUTH_RUNNER=tests/fvq/run_fvq34_remediated_head_budget_certificate.sh
AUTH_RUNNER_BLOB=d72403e00ad1a1a9cb69fac89cc680e3dc847262
AUTH_PLAN=integration/f-vq/F-VQ34_QUALIFICATION_PLAN.json
AUTH_PLAN_BLOB=4f3f7c8883397ed96d3af2f6585f25698c58e7b4
AUTH_DRIVER=tests/fvq/test_fvq34_remediated_head_budget_certificate.f90
AUTH_DRIVER_BLOB=ad5657bebd16db006fa36b2495f3c643ef6eb0bf

fail() { echo "FCI21_VQ34_REPLAY_FAIL:$*" >&2; exit 1; }

git merge-base --is-ancestor "$SOURCE_COMMIT" HEAD || fail 'materialized source commit not in history'
[[ "$(git rev-parse HEAD:$POSTIMAGE)" == "$POSTIMAGE_BLOB" ]] || fail 'materialized-source postimage drift'
git diff --quiet "$SOURCE_COMMIT" HEAD -- src || fail 'production src drift after F-CI21 materialization'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == 9af5a494526810324dc00706b444e448e770cba9 ]] || fail 'remediated KT11 backend not materialized'
[[ "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" == 2fd932b74dbd0ffc0ec089f49e632b7ac8852df4 ]] || fail 'transaction core drift'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)" == fe8f87d11257d4c6bc019f1d628ac41ba3106d4e ]] || fail 'Richards indicator drift'
[[ "$(git rev-parse HEAD:tests/fsi/test_fsi25_reference_indicator_production_seam.f90)" == c125c6a2ab706920b7e2a5c6f1c855520b192223 ]] || fail 'F-SI25 direct driver drift'
echo 'FCI21_VQ34_POSTIMAGE_LOCK=PASS'

# Fetch the exact qualification head that produced the successful historical VQ34
# run. All restored helpers below are test/tool/evidence artifacts only.
git fetch --quiet --no-tags origin "$AUTH_COMMIT"
git update-ref "$AUTH_REF" FETCH_HEAD
[[ "$(git rev-parse "$AUTH_REF")" == "$AUTH_COMMIT" ]] || fail 'VQ34 authority commit drift'
[[ "$(git rev-parse "$AUTH_REF:$AUTH_RUNNER")" == "$AUTH_RUNNER_BLOB" ]] || fail 'VQ34 authority runner drift'
[[ "$(git rev-parse "$AUTH_REF:$AUTH_PLAN")" == "$AUTH_PLAN_BLOB" ]] || fail 'VQ34 authority plan drift'
[[ "$(git rev-parse "$AUTH_REF:$AUTH_DRIVER")" == "$AUTH_DRIVER_BLOB" ]] || fail 'VQ34 authority driver drift'
echo 'FCI21_VQ34_AUTHORITY_LOCK=PASS'

# Restore the exact historical qualification runner and its legacy regression
# helpers into the CI checkout. Production src is never copied from authority.
OVERLAY_SINGLE=(
  integration/f-vq/F-VQ34_QUALIFICATION_PLAN.json
  integration/f-vq/F-VQ32_CLOSEOUT.json
  integration/f-kt/F-KT10_CLOSEOUT.json
  tests/fvq/run_fvq34_remediated_head_budget_certificate.sh
  tests/fvq/test_fvq34_remediated_head_budget_certificate.f90
)
for path in "${OVERLAY_SINGLE[@]}"; do
  mkdir -p "$(dirname "$path")"
  git show "$AUTH_REF:$path" > "$path"
done

while IFS= read -r path; do
  mkdir -p "$(dirname "$path")"
  git show "$AUTH_REF:$path" > "$path"
done < <(git ls-tree -r --name-only "$AUTH_REF" -- tests/transaction tests/fkt tools/fkt)

chmod +x tests/fvq/run_fvq34_remediated_head_budget_certificate.sh
find tests/transaction tests/fkt -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} +

git config user.name 'F-CI21 qualification overlay'
git config user.email 'f-ci21-overlay@invalid.local'
git add "${OVERLAY_SINGLE[@]}" tests/transaction tests/fkt tools/fkt
git commit --quiet --no-gpg-sign -m 'ci-only: overlay exact VQ34 qualification helpers'

git diff --quiet "$SOURCE_COMMIT" HEAD -- src || fail 'VQ34 test overlay changed production src'
[[ "$(git rev-parse HEAD:$AUTH_RUNNER)" == "$AUTH_RUNNER_BLOB" ]] || fail 'overlaid VQ34 runner mismatch'
[[ "$(git rev-parse HEAD:$AUTH_PLAN)" == "$AUTH_PLAN_BLOB" ]] || fail 'overlaid VQ34 plan mismatch'
[[ "$(git rev-parse HEAD:$AUTH_DRIVER)" == "$AUTH_DRIVER_BLOB" ]] || fail 'overlaid VQ34 driver mismatch'
echo 'FCI21_VQ34_TEST_ONLY_OVERLAY=PASS'

bash "$AUTH_RUNNER"

echo 'FCI21_VQ34_REMEDIATED_CERTIFICATE_REPLAY=PASS'
