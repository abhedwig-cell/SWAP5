$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap-irr-dcs1-scheduled-' + [guid]::NewGuid().ToString('N'))
$sources = @('src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90',
    'src/process/mod_irrigation_process.f90','src/process/mod_ppa_irr_dcs1_depth.f90',
    'src/process/mod_ppa_irr_water_deficit.f90','src/process/mod_ppa_irr_dcs1_composition.f90')
$flags = @('-std=f2008','-Wall','-Wextra','-Werror','-Wno-error=unused-dummy-argument',
    '-fcheck=all','-ffpe-trap=invalid,zero,overflow')
foreach ($opt in @('O0','O2')) {
    $dir = Join-Path $build $opt
    New-Item -ItemType Directory $dir | Out-Null
    foreach ($test in @('ppa_irr_dcs1_scheduled','ppa_irr_dcs1_depth_source_oracle','ppa_irr_water_deficit_source_oracle')) {
        $paths = @($sources | ForEach-Object { Join-Path $repo $_ })
        $paths += Join-Path $PSScriptRoot "test_$test.f90"
        $exe = Join-Path $dir "$test.exe"
        & gfortran @flags "-$opt" -J $dir -I $dir @paths -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Compile failed $test $opt" }
        $output = @(& $exe 2>&1)
        $exitCode = $LASTEXITCODE
        $output | Set-Content (Join-Path $dir "$test.txt")
        if ($exitCode -ne 0) { throw "Run failed $test $opt : $output" }
        if (($output -join "`n") -notmatch '=PASS') { throw "Missing PASS $test $opt" }
        if ($opt -eq 'O2' -and (Get-Content -Raw (Join-Path $dir "$test.txt")) -cne `
            (Get-Content -Raw (Join-Path $build "O0/$test.txt"))) { throw "O0/O2 differs $test" }
        "$test $opt=PASS"
    }
}
'PPA_IRR_DCS1_SCHEDULED_O0_O2=PASS'
"BUILD=$build"
