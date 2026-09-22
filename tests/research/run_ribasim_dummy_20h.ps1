$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$Root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $Root

$Base = "c710308b473485a95b400f1389ca78b9c8effc56"
$ImodPin = "8907fb13f8301ba1e0f32dd90a64ea475d4896d6"
$ImodRoot = if ($env:RIBASIM_DUMMY_20H_IMOD_COUPLER_ROOT) {
    (Resolve-Path $env:RIBASIM_DUMMY_20H_IMOD_COUPLER_ROOT).Path
} else {
    (Resolve-Path (Join-Path $Root ".imod-coupler-pin")).Path
}

function Fail([string]$Message) {
    Write-Error "RIBASIM_DUMMY_20H_FAIL $Message"
    exit 73
}

git merge-base --is-ancestor $Base HEAD
if ($LASTEXITCODE -ne 0) { Fail "branch is not descended from DUMMY-20H preregistration base" }

$srcDelta = @(git diff --name-only "$Base..HEAD" -- src)
if ($srcDelta.Count -gt 0) { Fail "production src delta is forbidden: $($srcDelta -join ', ')" }
$refDelta = @(git diff --name-only "$Base..HEAD" -- reference)
if ($refDelta.Count -gt 0) { Fail "reference delta is forbidden: $($refDelta -join ', ')" }

$allowed = @(
    ".github/workflows/ribasim-dummy-01.yml",
    "integration/research/RIBASIM_DUMMY_20H_PREREGISTRATION.json",
    "integration/research/RIBASIM_DUMMY_20H_CONCEPT.md",
    "integration/research/RIBASIM_DUMMY_20H_STATUS.json",
    "integration/research/RIBASIM_DUMMY_20H_RESULT.json",
    "integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json",
    "tests/research/test_ribasim_dummy_20h_active_river_management.py",
    "tests/research/run_ribasim_dummy_20h.ps1"
)
$delta = @(git diff --name-only "$Base..HEAD")
foreach ($path in $delta) {
    if (($path -ne "") -and ($allowed -notcontains $path)) {
        Fail "unexpected DUMMY-20H branch delta: $path"
    }
}
Write-Output "RIBASIM_DUMMY_20H_SOURCE_SCOPE=PASS"

if (-not (Test-Path (Join-Path $ImodRoot ".git"))) { Fail "pinned iMOD Coupler checkout missing" }
$ActualPin = (git -C $ImodRoot rev-parse HEAD).Trim()
if ($ActualPin -ne $ImodPin) { Fail "iMOD Coupler checkout mismatch: $ActualPin" }
Write-Output "RIBASIM_DUMMY_20H_IMOD_COUPLER_PIN=PASS sha=$ActualPin"

$CollectorParent = Join-Path $ImodRoot ".imod_collector/develop"
New-Item -ItemType Directory -Force -Path $CollectorParent | Out-Null

Set-Location $ImodRoot
pixi run -e dev fetch-ribasim
if ($LASTEXITCODE -ne 0) { Fail "fetch-ribasim failed" }
pixi run -e dev fetch-modflow
if ($LASTEXITCODE -ne 0) { Fail "fetch-modflow failed" }

$ModflowDll = (Resolve-Path (Join-Path $ImodRoot ".imod_collector/develop/modflow6/libmf6.dll")).Path
$RibasimDll = (Resolve-Path (Join-Path $ImodRoot ".imod_collector/develop/ribasim/bin/libribasim.dll")).Path
$RibasimDep = (Resolve-Path (Join-Path $ImodRoot ".imod_collector/develop/ribasim/bin")).Path
$WorkRoot = Join-Path $ImodRoot "generated_testmodels/swap5_dummy_20h"
if (Test-Path $WorkRoot) { Remove-Item -Recurse -Force $WorkRoot }

pixi run -e dev python "$Root/tests/research/test_ribasim_dummy_20h_active_river_management.py" --work-root "$WorkRoot" --modflow-dll "$ModflowDll" --ribasim-dll "$RibasimDll" --ribasim-dep "$RibasimDep"
if ($LASTEXITCODE -ne 0) { Fail "active-river management-boundary product test failed" }

Write-Output "RIBASIM_DUMMY_20H_REAL_PRODUCT_RUNTIME_TESTS=PASS"
Write-Output "RIBASIM_DUMMY_20H_GATE=PASS"
