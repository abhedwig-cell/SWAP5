# Windows replay of the existing owner gate; the shell runner remains the
# single source of the static Python checks, compilation flags and source list.
param([ValidateSet('IrrigationHalfSource','IrrigationSource','HydraulicCopy','Composition','Guards','Receipts','Windows','WindowRejection','GashWindows','GashBranchRejection','GashReceipts','Atm02','Atm02Events','Atm02Dense')][string]$Scope = 'Composition', [switch]$StableStorageExperiment, [switch]$StableStorage, [switch]$LocalOriginDiagnostic, [switch]$ConvergenceTrace)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if ($ConvergenceTrace -and $Scope -notin @('IrrigationSource','IrrigationHalfSource')) {
    throw 'ConvergenceTrace is restricted to irrigation source diagnostics'
}
if ($LocalOriginDiagnostic -and $Scope -ne 'IrrigationHalfSource') {
    throw 'LocalOriginDiagnostic is restricted to IrrigationHalfSource'
}
if ($Scope -in @('HydraulicCopy','IrrigationSource','IrrigationHalfSource') -and ($StableStorage -or $StableStorageExperiment)) {
    throw 'HydraulicCopy/IrrigationSource select their numerical profile inside the test; do not override with storage flags'
}
if ($Scope -eq 'Atm02Dense' -and !$StableStorage) { throw 'Atm02Dense requires explicit StableStorage' }
if ($Scope -eq 'Atm02Events' -and !$StableStorage) { throw 'Atm02Events requires explicit StableStorage' }
if ($Scope -eq 'Atm02' -and !$StableStorage) { throw 'Atm02 requires explicit StableStorage' }
if ($Scope -eq 'GashReceipts' -and !$StableStorage) { throw 'GashReceipts requires explicit StableStorage' }
if ($Scope -eq 'Receipts' -and !$StableStorage) { throw 'Receipts qualification requires explicit StableStorage' }
if ($Scope -eq 'Windows' -and !$StableStorage) { throw 'Windows qualification requires explicit StableStorage' }
if ($Scope -eq 'WindowRejection' -and !$StableStorage) { throw 'WindowRejection requires explicit StableStorage' }
if ($Scope -eq 'GashWindows' -and !$StableStorage) { throw 'GashWindows requires explicit StableStorage' }
if ($Scope -eq 'GashBranchRejection' -and !$StableStorage) { throw 'GashBranchRejection requires explicit StableStorage' }
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script = Get-Content (Join-Path $PSScriptRoot 'run_ppa_wu01_production_application_bootstrap.sh') -Raw
$static = [regex]::Match($script, "(?ms)^python3 - <<'PY'\r?\n(.*?)^PY\r?$")
$sources = [regex]::Match($script, '(?ms)^MODULE_SRC=\(\r?\n(.*?)^\)\r?$')
$flags = [regex]::Match($script, '(?m)^COMMON=\(([^\r\n]*)\)\r?$')
if (!$static.Success -or !$sources.Success -or !$flags.Success) { throw 'Unrecognized owner gate layout' }
$sourcePaths = @($sources.Groups[1].Value -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($source in $sourcePaths) {
    if ($source -notmatch '^(src|tests)/[A-Za-z0-9_./-]+\.f90$') { throw "Unsupported source entry: $source" }
}
$sourcePaths += @('src/adapter/mod_ppa_free_drainage_stiffness.f90', 'src/solver/mod_ppa_mvg_storage_difference.f90','src/adapter/mod_ppa_mvg_storage_binding.f90','src/adapter/mod_ppa_forcing_event_derivative.f90','src/adapter/mod_ppa_free_drainage_temporal_indicator.f90')
$common = @($flags.Groups[1].Value -split '\s+' | Where-Object { $_ })
$sourcePaths += @('src/process/mod_ppa_irr_water_deficit.f90',
    'src/process/mod_ppa_irr_dcs1_composition.f90','src/runtime/mod_ppa_irrigation_event_state.f90',
    'src/adapter/mod_ppa_irrigation_source_binding.f90',
    'src/process/mod_ppa_irr_tcs1_4_timing.f90','src/process/mod_ppa_irr_tcs1_4_composition.f90',
    'src/process/mod_ppa_irr_tcs1_4_dcs1.f90',
    'src/process/mod_ppa_irr_tcs6_weekly_timing.f90','src/process/mod_ppa_irr_tcs6_composition.f90',
    'src/process/mod_ppa_irr_weekly_identity.f90','src/process/mod_ppa_irr_tcs6_daily.f90',
    'src/adapter/mod_ppa_irr_tcs6_source.f90',
    'src/adapter/mod_ppa_irr_tcs1_4_source.f90',
    'src/process/mod_ppa_irr_tcsfix_filter.f90','src/process/mod_ppa_irr_tcsfix_composition.f90',
    'src/process/mod_ppa_irr_tcsfix_identity.f90',
    'src/adapter/mod_ppa_irr_tcsfix_source.f90','src/adapter/mod_ppa_bootstrap_irrigation.f90')
if (@($common | Where-Object { $_ -notmatch '^-[A-Za-z0-9_=,-]+$' }).Count) { throw 'Unsupported compiler option' }
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap-ppa-wu01-' + [guid]::NewGuid().ToString('N'))
$stable = @{}
if ($ConvergenceTrace) {
    New-Item -ItemType Directory $build -Force | Out-Null
    $candidate = Join-Path $build 'headcalc_convergence_trace.f90'
    & (Join-Path $PSScriptRoot '../fsi/new_ppa_convergence_trace.ps1') `
        -Source (Join-Path $repo 'src/legacy/b1_10_port/headcalc.f90') -Destination $candidate
}
if ($StableStorageExperiment) {
    New-Item -ItemType Directory $build -Force | Out-Null
    $candidate = Join-Path $build 'headcalc_storage_experiment.f90'
    & (Join-Path $PSScriptRoot '../fsi/new_ppa_storage_experiment.ps1') `
        -Source (Join-Path $repo 'src/legacy/b1_10_port/headcalc.f90') -Destination $candidate
    $sourcePaths = @($sourcePaths | ForEach-Object {
        if ($_ -eq 'src/legacy/b1_10_port/headcalc.f90') {
            'src/solver/mod_ppa_mvg_storage_difference.f90'
            'src/adapter/mod_ppa_mvg_storage_binding.f90'
        }
        if ($_ -notin @('src/solver/mod_ppa_mvg_storage_difference.f90','src/adapter/mod_ppa_mvg_storage_binding.f90')) { $_ }
    })
}
$tests = @('ppa_free_drainage_owner')
if ($Scope -eq 'All') { $tests += 'ppa_wu01_production_application_bootstrap' }
Push-Location $repo
try {
    New-Item -ItemType Directory $build -Force | Out-Null
    $staticPath = Join-Path $build 'static_checks.py'
    Set-Content -Path $staticPath -Value $static.Groups[1].Value -NoNewline
    & python $staticPath
    if ($LASTEXITCODE -ne 0) { throw 'Static owner checks failed' }
    foreach ($opt in @('O0','O2')) {
        $dir = Join-Path $build $opt
        New-Item -ItemType Directory $dir -Force | Out-Null
        $objects = @()
        foreach ($source in $sourcePaths) {
            $obj = Join-Path $dir (([IO.Path]::GetFileNameWithoutExtension($source)) + '.o')
            if ($objects -contains $obj) { throw "Duplicate object basename: $source" }
            $sourcePath = Join-Path $repo $source
            if ($StableStorageExperiment -and $source -eq 'src/legacy/b1_10_port/headcalc.f90') { $sourcePath = $candidate }
            if ($ConvergenceTrace -and $source -eq 'src/legacy/b1_10_port/headcalc.f90') { $sourcePath = $candidate }
            & gfortran @common "-$opt" -J $dir -I $dir -c $sourcePath -o $obj
            if ($LASTEXITCODE -ne 0) { throw "Compile failed $opt $source" }
            $objects += $obj
        }
        foreach ($test in $tests) {
            $obj = Join-Path $dir "$test.o"
            $exe = Join-Path $dir "$test.exe"
            & gfortran @common "-$opt" -J $dir -I $dir -c (Join-Path $PSScriptRoot "test_$test.f90") -o $obj
            if ($LASTEXITCODE -ne 0) { throw "Test compile failed $opt $test" }
            & gfortran -fopenmp "-$opt" @objects $obj -o $exe
            if ($LASTEXITCODE -ne 0) { throw "Link failed $opt $test" }
            $testArguments = @()
            if ($Scope -eq 'Guards') { $testArguments = @('--guards') }
            if ($Scope -eq 'HydraulicCopy') { $testArguments = @('--hydraulic-copy') }
            if ($Scope -eq 'IrrigationSource') { $testArguments = @('--irrigation-source') }
            # Diagnostic reproduction: currently fails; do not convert failure to PASS.
            if ($Scope -eq 'IrrigationHalfSource') { $testArguments = @('--irrigation-half-source') }
            if ($LocalOriginDiagnostic) { $testArguments += '--local-origin' }
            if ($StableStorage) {
                $testArguments = @('--stable-storage')
                if ($Scope -eq 'Guards') { $testArguments = @('--stable-guards') }
                if ($Scope -eq 'Receipts') { $testArguments = @('--stable-receipts') }
                if ($Scope -eq 'GashReceipts') { $testArguments = @('--gash-receipts') }
                if ($Scope -eq 'Atm02') { $testArguments = @('--atm02') }
                if ($Scope -eq 'Atm02Events') { $testArguments = @('--atm02-events') }
                if ($Scope -eq 'Atm02Dense') { $testArguments = @('--atm02-dense') }
                if ($Scope -eq 'Windows') { $testArguments = @('--stable-windows') }
                if ($Scope -eq 'WindowRejection') { $testArguments = @('--window-rejection') }
                if ($Scope -eq 'GashWindows') { $testArguments = @('--gash-windows') }
                if ($Scope -eq 'GashBranchRejection') { $testArguments = @('--gash-branch-rejection') }
            }
            $stdoutPath = Join-Path $dir "$test.stdout.txt"
            $stderrPath = Join-Path $dir "$test.stderr.txt"
            $process = Start-Process -FilePath $exe -ArgumentList $testArguments -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -NoNewWindow -Wait -PassThru
            $output = @(Get-Content $stdoutPath)
            if ($process.ExitCode -ne 0) {
                $output | Set-Content (Join-Path $dir "$test.failed.txt")
                throw "Runtime failed $opt $test : $((Get-Content $stderrPath | Select-Object -Last 20) -join "`n")"
            }
            $textOutput = $output -join "`n"
            $textOutput | Set-Content (Join-Path $dir "$test.txt")
            if ($test -eq 'ppa_output_canon_application_binding') {
                foreach ($marker in @('PPA_OUTPUT_CANON_APPLICATION_BYTE_IDENTITY=PASS',
                    'PPA_OUTPUT_CANON_APPLICATION_READ_ONLY_SNAPSHOT=PASS')) {
                    if (!$textOutput.Contains($marker)) { throw "Missing $marker $opt" }
                }
                $prefix = '^PPA_OUTPUT_CANON_'
            } else {
                $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_COMPOSITION=PASS'
                if ($Scope -eq 'Guards') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_GUARDS=PASS' }
                if ($Scope -eq 'HydraulicCopy') { $requiredMarker = 'PPA_OWNER_HYDRAULIC_COPY=PASS' }
                if ($Scope -eq 'IrrigationSource') { $requiredMarker = 'PPA_OWNER_DCS1_SOURCE_ACCEPTED_MASS=PASS' }
                if ($Scope -eq 'IrrigationHalfSource') { $requiredMarker = 'PPA_OWNER_DCS1_SOURCE_ACCEPTED_MASS=PASS' }
                if ($Scope -eq 'Receipts') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_SOURCE_RECEIPT_RESTART=PASS' }
                if ($Scope -eq 'GashReceipts') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_GASH_SOURCE_RECEIPT_RESTART=PASS' }
                if ($Scope -eq 'Atm02') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_ATM02=PASS' }
                if ($Scope -eq 'Atm02Events') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_ATM02_EVENTS=PASS' }
                if ($Scope -eq 'Atm02Dense') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_ATM02_DENSE=PASS' }
                if ($Scope -eq 'Windows') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_CHANGING_WINDOWS=PASS' }
                if ($Scope -eq 'WindowRejection') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_WINDOW_REJECTION=PASS' }
                if ($Scope -eq 'GashWindows') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_GASH_WINDOWS=PASS' }
                if ($Scope -eq 'GashBranchRejection') { $requiredMarker = 'PPA_FREE_DRAINAGE_OWNER_GASH_BRANCH_REJECTION=PASS' }
                if (!$textOutput.Contains($requiredMarker)) {
                    throw "Missing bootstrap success marker $opt"
                }
                if ($Scope -eq 'GashBranchRejection' -and !$textOutput.Contains('PPA_FREE_DRAINAGE_OWNER_GASH_LOW_RAIN_DENSE_RESTART=PASS')) {
                    throw 'Missing explicit dense-retry low-rain restart qualification'
                }
                if ($Scope -in @('Receipts','GashReceipts') -and !$textOutput.Contains('PPA_FREE_DRAINAGE_OWNER_FAILED_REPLAY_NO_PUBLICATION=PASS')) {
                    throw 'Missing actual failed hydraulic replay marker'
                }
                if ($Scope -in @('Receipts','GashReceipts') -and !$textOutput.Contains('PPA_FREE_DRAINAGE_OWNER_PARTIAL_REPLAY_NO_PUBLICATION=PASS')) {
                    throw 'Missing partially accepted interval rollback marker'
                }
                $prefix = '^PPA_FREE_DRAINAGE_OWNER_'
            }
            $stable["$test-$opt"] = (@($output | Where-Object { $_ -match $prefix }) -join "`n")
            if ($StableStorageExperiment -or $StableStorage -or $Scope -in @('HydraulicCopy','IrrigationSource','IrrigationHalfSource')) {
                # Compare numerical diagnostics as well as success markers.
                $stable["$test-$opt"] = $textOutput
            }
            if ($opt -eq 'O2' -and $stable["$test-O0"] -cne $stable["$test-O2"]) {
                throw "O0/O2 output differs: $test"
            }
            "$test $opt=PASS"
        }
    }
    & git diff --check -- src/runtime/mod_fmr_production_application_bootstrap.f90 `
        tests/fapp/test_ppa_wu01_production_application_bootstrap.f90 `
        tests/fapp/run_ppa_wu01_production_application_bootstrap.sh `
        tests/fapp/run_ppa_wu01_production_application_bootstrap.ps1
    if ($LASTEXITCODE -ne 0) { throw 'Owner gate diff check failed' }
    "PPA_FREE_DRAINAGE_OWNER_${Scope}_O0_O2_IDENTITY=PASS"
    if ($Scope -eq 'All') {
        'PPA_WU01_O0_O2_OUTPUT_IDENTITY=PASS'
        'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS'
    }
} finally {
    Pop-Location
    "Build artifacts retained at $build"
}
