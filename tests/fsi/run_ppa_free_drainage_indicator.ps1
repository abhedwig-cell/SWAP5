$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$build = Join-Path $env:TEMP ('swap-free-drainage-' + [guid]::NewGuid())
New-Item -ItemType Directory $build | Out-Null
$gate = Get-Content -Raw (Join-Path $PSScriptRoot 'run_fsi38_prescribed_qbot_temporal_certificate_gate.sh')
$sources = [regex]::Match($gate, '(?s)MODULE_SRC=\((.*?)\)').Groups[1].Value.Trim() -split '\s+'
$sources = @($sources | ForEach-Object {
    if ($_ -eq 'src/runtime/mod_a23bu_worker_execution_context.f90') {
        'src/solver/mod_soil_water_accepted_step_direction_contract.f90'
        'src/transaction/mod_accepted_trajectory_directional_sensitivity.f90'
    }
    if ($_ -eq 'src/solver/mod_reference_richards_temporal_indicator.f90') {
        'src/solver/mod_b110_root_sink_provider.f90'
    }
    $_
})
$flags = @('-g','-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow')
$tests = @('test_ppa_free_drainage_indicator','test_fsi38_prescribed_qbot_temporal_certificate','test_fsi25_reference_indicator_production_seam')
foreach ($opt in 0,2) {
    $out = Join-Path $build "O$opt"
    New-Item -ItemType Directory $out | Out-Null
    $objects = @()
    foreach ($source in $sources) {
        $obj = Join-Path $out (([IO.Path]::GetFileNameWithoutExtension($source))+'.o')
        & gfortran @flags "-O$opt" -J $out -I $out -c (Join-Path $root $source) -o $obj
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $source" }
        $objects += $obj
    }
    foreach ($test in $tests) {
        $exe = Join-Path $out "$test.exe"
        & gfortran @flags "-O$opt" -J $out -I $out (Join-Path $PSScriptRoot "$test.f90") @objects -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Test compilation failed: $test" }
        $argsForTest = @()
        if ($test -like 'test_fsi25*') { $argsForTest = @('-75.0','0.01') }
        $lines = & $exe @argsForTest
        if ($LASTEXITCODE -ne 0) { $lines; throw "Test failed: $test O$opt" }
        if (($lines -join "`n") -notmatch 'PASS') { throw "Missing PASS: $test" }
        $lines | Set-Content (Join-Path $out "$test.txt")
        $lines
    }
}
foreach ($test in $tests) {
    if ((Get-Content -Raw (Join-Path $build "O0/$test.txt")) -cne (Get-Content -Raw (Join-Path $build "O2/$test.txt"))) {
        throw "O0/O2 transcript mismatch: $test"
    }
}
Write-Output 'FREE_DRAINAGE_INDICATOR_O0_O2_PRESERVATION=PASS'
Write-Output "BUILD=$build"
