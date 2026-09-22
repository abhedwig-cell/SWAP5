$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$Root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $Root

$Base = "888c879fb8b5590f4821e2dc2ffaba2419c2cf20"
$ImodPin = "8907fb13f8301ba1e0f32dd90a64ea475d4896d6"
$ImodRoot = if ($env:RIBASIM_DUMMY_20D_IMOD_COUPLER_ROOT) {
    (Resolve-Path $env:RIBASIM_DUMMY_20D_IMOD_COUPLER_ROOT).Path
} else {
    (Resolve-Path (Join-Path $Root ".imod-coupler-pin")).Path
}

function Fail([string]$Message) {
    Write-Error "RIBASIM_DUMMY_20D_FAIL $Message"
    exit 73
}

git merge-base --is-ancestor $Base HEAD
if ($LASTEXITCODE -ne 0) { Fail "branch is not descended from DUMMY-20D implementation-ready base" }

$srcDelta = @(git diff --name-only "$Base..HEAD" -- src)
if ($srcDelta.Count -gt 0) { Fail "production src delta is forbidden: $($srcDelta -join ', ')" }

$refDelta = @(git diff --name-only "$Base..HEAD" -- reference)
if ($refDelta.Count -gt 0) { Fail "reference delta is forbidden: $($refDelta -join ', ')" }

$allowed = @(
    ".github/workflows/ribasim-dummy-01.yml",
    "integration/research/RIBASIM_DUMMY_20D_PREREGISTRATION.json",
    "integration/research/RIBASIM_DUMMY_20D_CONCEPT.md",
    "integration/research/RIBASIM_DUMMY_20D_STATUS.json",
    "integration/research/RIBASIM_DUMMY_20D_RESULT.json",
    "integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json",
    "tests/research/test_ribasim_dummy_20d_real_ribamod_case.py",
    "tests/research/verify_ribasim_dummy_20d_clock_matrix.py",
    "tests/research/run_ribasim_dummy_20d.ps1"
)
$delta = @(git diff --name-only "$Base..HEAD")
foreach ($path in $delta) {
    if (($path -ne "") -and ($allowed -notcontains $path)) {
        Fail "unexpected DUMMY-20D branch delta: $path"
    }
}
Write-Output "RIBASIM_DUMMY_20D_SOURCE_SCOPE=PASS"

if (-not (Test-Path (Join-Path $ImodRoot ".git"))) { Fail "pinned iMOD Coupler checkout missing" }
$ActualPin = (git -C $ImodRoot rev-parse HEAD).Trim()
if ($ActualPin -ne $ImodPin) { Fail "iMOD Coupler checkout mismatch: $ActualPin" }
Write-Output "RIBASIM_DUMMY_20D_IMOD_COUPLER_PIN=PASS sha=$ActualPin"

Set-Location $ImodRoot
pixi run -e dev fetch-ribasim
if ($LASTEXITCODE -ne 0) { Fail "fetch-ribasim failed" }
pixi run -e dev fetch-modflow
if ($LASTEXITCODE -ne 0) { Fail "fetch-modflow failed" }

$ModflowDll = (Resolve-Path (Join-Path $ImodRoot ".imod_collector/develop/modflow6/libmf6.dll")).Path
$RibasimDll = (Resolve-Path (Join-Path $ImodRoot ".imod_collector/develop/ribasim/bin/libribasim.dll")).Path
$RibasimDep = (Resolve-Path (Join-Path $ImodRoot ".imod_collector/develop/ribasim/bin")).Path
$WorkRoot = (Join-Path $ImodRoot "generated_testmodels/swap5_dummy_20d")
$ResultRoot = (Join-Path $ImodRoot "generated_testmodels/swap5_dummy_20d_results")
if (Test-Path $WorkRoot) { Remove-Item -Recurse -Force $WorkRoot }
if (Test-Path $ResultRoot) { Remove-Item -Recurse -Force $ResultRoot }
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
New-Item -ItemType Directory -Force -Path $ResultRoot | Out-Null

$Cases = @("A24_S24", "A24_S1", "A6_S24", "A6_S1")
foreach ($Case in $Cases) {
    $CaseRoot = Join-Path $WorkRoot $Case
    $ResultJson = Join-Path $ResultRoot "$Case.json"
    pixi run -e dev python "$Root/tests/research/test_ribasim_dummy_20d_real_ribamod_case.py" --case "$Case" --work-root "$CaseRoot" --modflow-dll "$ModflowDll" --ribasim-dll "$RibasimDll" --ribasim-dep "$RibasimDep" --result-json "$ResultJson"
    if ($LASTEXITCODE -ne 0) { Fail "actual RibaMod matrix case failed: $Case" }
}

pixi run -e dev python "$Root/tests/research/verify_ribasim_dummy_20d_clock_matrix.py" --result-root "$ResultRoot"
if ($LASTEXITCODE -ne 0) { Fail "clock ownership matrix verification failed" }

Write-Output "RIBASIM_DUMMY_20D_REAL_PRODUCT_RUNTIME_TESTS=PASS"
Write-Output "RIBASIM_DUMMY_20D_GATE=PASS"
