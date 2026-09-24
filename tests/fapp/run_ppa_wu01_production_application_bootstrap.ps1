# Windows replay of the existing owner gate; the shell runner remains the
# single source of the static Python checks, compilation flags and source list.
$ErrorActionPreference = 'Stop'
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
$common = @($flags.Groups[1].Value -split '\s+' | Where-Object { $_ })
if (@($common | Where-Object { $_ -notmatch '^-[A-Za-z0-9_=,-]+$' }).Count) { throw 'Unsupported compiler option' }
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap-ppa-wu01-' + [guid]::NewGuid().ToString('N'))
$stable = @{}
Push-Location $repo
try {
    & python -c $static.Groups[1].Value
    if ($LASTEXITCODE -ne 0) { throw 'Static owner checks failed' }
    foreach ($opt in @('O0','O2')) {
        $dir = Join-Path $build $opt
        New-Item -ItemType Directory $dir -Force | Out-Null
        $objects = @()
        foreach ($source in $sourcePaths) {
            $obj = Join-Path $dir (([IO.Path]::GetFileNameWithoutExtension($source)) + '.o')
            if ($objects -contains $obj) { throw "Duplicate object basename: $source" }
            & gfortran @common "-$opt" -J $dir -I $dir -c (Join-Path $repo $source) -o $obj
            if ($LASTEXITCODE -ne 0) { throw "Compile failed $opt $source" }
            $objects += $obj
        }
        foreach ($test in @('ppa_output_canon_application_binding','ppa_wu01_production_application_bootstrap')) {
            $obj = Join-Path $dir "$test.o"
            $exe = Join-Path $dir "$test.exe"
            & gfortran @common "-$opt" -J $dir -I $dir -c (Join-Path $PSScriptRoot "test_$test.f90") -o $obj
            if ($LASTEXITCODE -ne 0) { throw "Test compile failed $opt $test" }
            & gfortran -fopenmp "-$opt" @objects $obj -o $exe
            if ($LASTEXITCODE -ne 0) { throw "Link failed $opt $test" }
            $output = @(& $exe 2>&1)
            if ($LASTEXITCODE -ne 0) { throw "Runtime failed $opt $test : $($output -join "`n")" }
            $textOutput = $output -join "`n"
            if ($test -eq 'ppa_output_canon_application_binding') {
                foreach ($marker in @('PPA_OUTPUT_CANON_APPLICATION_BYTE_IDENTITY=PASS',
                    'PPA_OUTPUT_CANON_APPLICATION_READ_ONLY_SNAPSHOT=PASS')) {
                    if (!$textOutput.Contains($marker)) { throw "Missing $marker $opt" }
                }
                $prefix = '^PPA_OUTPUT_CANON_'
            } else {
                if (!$textOutput.Contains('PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP GATE PASS')) {
                    throw "Missing bootstrap success marker $opt"
                }
                $prefix = '^PPA_WU01_'
            }
            $stable["$test-$opt"] = (@($output | Where-Object { $_ -match $prefix }) -join "`n")
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
    'PPA_OUTPUT_CANON_APPLICATION_O0_O2_IDENTITY=PASS'
    'PPA_WU01_O0_O2_OUTPUT_IDENTITY=PASS'
    'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS'
} finally {
    Pop-Location
    "Build artifacts retained at $build"
}
