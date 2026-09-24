# Windows replay of the source list, fixture identity and gates in the shell runner.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap-fapp07-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $build | Out-Null
$script = Get-Content (Join-Path $PSScriptRoot 'run_fapp07_tcs1_dcs2_process.sh') -Raw
$list = [regex]::Match($script,'(?ms)^COMPOSITION_SRC=\(\r?\n(.*?)^\)')
if (!$list.Success) { throw 'Missing canonical source list' }
$sources = @($list.Groups[1].Value -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($source in $sources) {
    if ($source -notmatch '^src/[A-Za-z0-9_./-]+\.f90$') { throw 'Invalid source path' }
}
$processPath = Join-Path $repo 'src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90'
$processText = Get-Content -Raw $processPath
if (!$processText.Contains('pure subroutine evaluate_tcs1_dcs2_sprinkling_interval')) { throw 'Missing pure process' }
if ($processText -match '(?i)open\s*\(|read\s*\(|write\s*\(|mod_rutter|mod_fmr|headcalc|timecontrol') {
    throw 'Forbidden process dependency or IO'
}
$binding = Get-Content -Raw (Join-Path $repo 'src/runtime/mod_fmr_hupsel_irrigation_application_binding.f90')
foreach ($name in @('fmr_bind_tcs1_sprinkling_to_rutter','fmr_bind_rutter_net_irrigation_to_dynamic_top',
    'fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top')) {
    if (!$binding.Contains($name)) { throw "Missing binding $name" }
}
$fixture = Join-Path $PSScriptRoot 'fixtures/hupsel_irrigation_active_intervals_b111.csv.gz'
if ((Get-FileHash $fixture).Hash.ToLowerInvariant() -ne 'aa2b900691f124701b3f98d3c660f3b27291b3da4a94754db64c86b36252eaec') {
    throw 'Compressed fixture identity drift'
}
$csv = Join-Path $build 'irrigation.csv'
$inputStream = [IO.File]::OpenRead($fixture)
$gzip = [IO.Compression.GZipStream]::new($inputStream,[IO.Compression.CompressionMode]::Decompress)
$outputStream = [IO.File]::Create($csv)
try { $gzip.CopyTo($outputStream) } finally { $outputStream.Dispose(); $gzip.Dispose(); $inputStream.Dispose() }
if ((Get-FileHash $csv).Hash.ToLowerInvariant() -ne '98c7031e28f134e3f1f2ddee788788f4b8855d4f38f178777bbc5e24721dd63b') {
    throw 'Expanded fixture identity drift'
}
$flags = @('-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-fcheck=all',
    '-fbacktrace','-ffpe-trap=invalid,zero,overflow')
foreach ($opt in @('O0','O2')) {
    $dir = Join-Path $build $opt
    New-Item -ItemType Directory $dir | Out-Null
    foreach ($kind in @('process','composition')) {
        $exe = Join-Path $dir "$kind.exe"
        if ($kind -eq 'process') {
            & gfortran @flags -Werror -pedantic-errors "-$opt" -J $dir -I $dir $processPath `
                (Join-Path $PSScriptRoot 'test_tcs1_dcs2_sprinkling_process.f90') -o $exe
        } else {
            $objects = @()
            foreach ($source in $sources) {
                $obj = Join-Path $dir (([IO.Path]::GetFileNameWithoutExtension($source)) + '.o')
                $extra = @()
                if ($source -match '(mod_fmr_hupsel_irrigation_application_binding|mod_tcs1_dcs2_sprinkling_irrigation_process)') {
                    $extra = @('-Werror','-pedantic-errors')
                }
                & gfortran @flags @extra "-$opt" -J $dir -I $dir -c (Join-Path $repo $source) -o $obj
                if ($LASTEXITCODE -ne 0) { throw "Compile failed $source $opt" }
                $objects += $obj
            }
            & gfortran @flags -Wno-error=compare-reals "-$opt" -J $dir -I $dir @objects `
                (Join-Path $PSScriptRoot 'test_hupsel_irrigation_composition.f90') -o $exe
        }
        if ($LASTEXITCODE -ne 0) { throw "Link failed $kind $opt" }
        $arguments = @()
        if ($kind -eq 'composition') { $arguments = @($csv) }
        $output = @(& $exe @arguments 2>&1)
        $exitCode = $LASTEXITCODE
        $output | Set-Content (Join-Path $dir "$kind.txt")
        if ($exitCode -ne 0) { throw "Run failed $kind $opt : $output" }
        $markers = @('F_APP07_TCS1_DCS2_HUPSEL_PROCESS=PASS','F_APP07_TCS1_DCS2_SPLIT_REPLAY=PASS',
            'F_APP07_TCSFIX_DAYFIX=PASS')
        if ($kind -eq 'composition') {
            $markers = @('F_APP07_EXACT_ACTIVE_INTERVALS=110','F_APP07_SWINTER0_INTERVALS=18',
                'F_APP07_SWINTER3_INTERVALS=92','F_APP07_IRRIGATION_RUTTER_DYNAMIC_TOP_COMPOSITION=PASS')
        }
        foreach ($marker in $markers) { if (!($output -contains $marker)) { throw "Missing $marker" } }
        if ($opt -eq 'O2' -and (Get-Content -Raw (Join-Path $dir "$kind.txt")) -cne `
            (Get-Content -Raw (Join-Path $build "O0/$kind.txt"))) { throw "O0/O2 differs $kind" }
        "$kind $opt=PASS"
    }
}
'F_APP07_WINDOWS_PROCESS_AND_EXACT_110_INTERVAL_COMPOSITION=PASS'
"BUILD=$build"
