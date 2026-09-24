$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap-irr-dcs2-limit-' + [guid]::NewGuid().ToString('N'))
$sources = @('src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90',
    'src/process/mod_irrigation_process.f90')
$tests = @('ppa_irr_dcs2_limit','ppa_irr_scheduled_solute_overirrigation','ppa_irr_scheduled_rate_fallback',
    'ppa_irr_scheduled_split_retry','ppa_irr_tcs7_dcs2_source_oracle','ppa_irr_tcs8_dcs2_source_oracle')
$flags = @('-std=f2008','-Wall','-Wextra','-Werror','-Wno-error=unused-dummy-argument',
    '-fcheck=all','-ffpe-trap=invalid,zero,overflow')
foreach ($opt in @('O0','O2')) {
    $dir = Join-Path $build $opt
    New-Item -ItemType Directory $dir | Out-Null
    foreach ($test in $tests) {
        $paths = @($sources | ForEach-Object { Join-Path $repo $_ })
        $paths += Join-Path $PSScriptRoot "test_$test.f90"
        $exe = Join-Path $dir "$test.exe"
        & gfortran @flags "-$opt" -J $dir -I $dir @paths -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Compile failed $test $opt" }
        $output = @(& $exe 2>&1)
        $output | Set-Content (Join-Path $dir "$test.txt")
        if ($LASTEXITCODE -ne 0) { throw "Run failed $test $opt : $output" }
        if (($output -join "`n") -notmatch '=PASS') { throw "Missing PASS $test $opt" }
        if ($opt -eq 'O2') {
            $old = Get-Content -Raw (Join-Path $build "O0/$test.txt")
            if ($old -cne (Get-Content -Raw (Join-Path $dir "$test.txt"))) { throw "Transcript differs $test" }
        }
        "$test $opt=PASS"
    }
}
'PPA_IRR_DCS2_LIMIT_AND_PRESERVATION_O0_O2=PASS'
"BUILD=$build"
