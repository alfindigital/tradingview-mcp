# Mengunduh ulang ketiga repo referensi ke refs/, lalu menjalankan semua
# post-processing (perbaikan file kosong, dedupe, katalog indikator, cek link).
#
# refs/ sengaja tidak di-commit (lihat .gitignore) karena isinya kode pihak ketiga
# dengan lisensi berbeda - everget GPL-3.0, sedangkan proyek ini MIT.
# Jalankan skrip ini untuk membangunnya dari nol.
#
#   powershell -ExecutionPolicy Bypass -File tools/fetch-refs.ps1
param(
    [string]$Root = 'C:\Users\alfin\Documents\IDX\Tradingview',
    [switch]$SkipLinkCheck
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$refs = Join-Path $Root 'refs'
$tools = Join-Path $Root 'tools'
New-Item -ItemType Directory -Force -Path $refs | Out-Null

$sources = @(
    @{
        Dest   = 'indicators-everget'
        Repo   = 'everget/tradingview-pinescript-indicators'
        Branch = 'master'
        Inner  = 'tradingview-pinescript-indicators-master'
        Note   = '210 indikator Pine, GPL-3.0'
    },
    @{
        Dest   = 'awesome-pinescript'
        Repo   = 'pAulseperformance/awesome-pinescript'
        Branch = 'master'
        Inner  = 'awesome-pinescript-master'
        Note   = 'daftar link kurasi, MIT'
    },
    @{
        Dest   = 'pine-v6-docs'
        Repo   = 'codenamedevan/pinescriptv6'
        Branch = 'main'
        Inner  = 'pinescriptv6-main'
        Note   = 'dokumentasi Pine v6 untuk LLM, tanpa lisensi'
    }
)

$tmp = Join-Path $env:TEMP ('tvrefs-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

try {
    foreach ($s in $sources) {
        $url = "https://codeload.github.com/$($s.Repo)/zip/refs/heads/$($s.Branch)"
        $zip = Join-Path $tmp ($s.Dest + '.zip')

        Write-Output "FETCH  $($s.Repo) [$($s.Branch)] - $($s.Note)"
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip

        $ex = Join-Path $tmp $s.Dest
        Expand-Archive -Path $zip -DestinationPath $ex -Force

        $inner = Join-Path $ex $s.Inner
        if (-not (Test-Path $inner)) {
            # Nama folder di dalam zip bisa berubah kalau default branch berganti
            $inner = (Get-ChildItem -Directory $ex | Select-Object -First 1).FullName
        }

        $dest = Join-Path $refs $s.Dest
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Recurse -Force (Join-Path $inner '*') $dest

        # Catat commit yang sedang dipakai supaya versinya bisa dilacak.
        # Feed atom dipakai lebih dulu karena tidak kena rate limit 60 req/jam
        # seperti API publik GitHub.
        $sha = '(tidak tersedia)'
        $cdate = '(tidak tersedia)'
        try {
            $atom = "https://github.com/$($s.Repo)/commits/$($s.Branch).atom"
            $x = [xml](Invoke-WebRequest -UseBasicParsing -Uri $atom -TimeoutSec 20 -ErrorAction Stop).Content
            $e = @($x.feed.entry)[0]
            $sha = ($e.id -split '/')[-1]
            $cdate = $e.updated
        }
        catch {
            try {
                $c = Invoke-RestMethod "https://api.github.com/repos/$($s.Repo)/commits?sha=$($s.Branch)&per_page=1" -Headers @{ 'User-Agent' = 'fetch-refs' } -ErrorAction Stop
                $sha = $c[0].sha
                $cdate = $c[0].commit.author.date
            }
            catch {
                $why = if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 403) {
                    'rate limit API GitHub (60 req/jam per IP)'
                }
                else { ($_.Exception.Message -replace '\s+', ' ').Trim() }
                Write-Warning "Info commit $($s.Repo) tidak terambil: $why"
                $sha = "(gagal: $why)"
            }
        }

        $stamp = "repo:    $($s.Repo)`r`nbranch:  $($s.Branch)`r`ncommit:  $sha`r`ndate:    $cdate`r`nfetched: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
        [System.IO.File]::WriteAllText((Join-Path $dest '.source-info'), $stamp, (New-Object System.Text.UTF8Encoding $false))

        $n = (Get-ChildItem -Recurse -File $dest).Count
        Write-Output "       -> refs\$($s.Dest)  ($n file)"
    }
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

Write-Output ''
Write-Output '--- Post-processing ---'

$steps = @(
    @{ Script = 'build-function-reference.ps1'; Desc = 'Isi ulang reference/functions/*.md dari monolith 884 entri' },
    @{ Script = 'repair-variables.ps1';         Desc = 'Pulihkan 26 variabel yang terpotong (close, bar_index, dll)' },
    @{ Script = 'dedupe-v6-docs.ps1';           Desc = 'Pindahkan file duplikat ke _duplicates/' },
    @{ Script = 'build-indicator-index.ps1';    Desc = 'Bangun katalog 210 indikator' }
)
if (-not $SkipLinkCheck) {
    $steps += @{ Script = 'check-awesome-links.ps1'; Desc = 'Verifikasi 97 link awesome-pinescript' }
}

foreach ($st in $steps) {
    $p = Join-Path $tools $st.Script
    if (-not (Test-Path $p)) { Write-Warning "Tidak ada: tools\$($st.Script)"; continue }
    Write-Output ''
    Write-Output "RUN    tools\$($st.Script) - $($st.Desc)"
    & $p -Root $Root
}

Write-Output ''
Write-Output 'Selesai. Baca refs\README.md untuk panduan pemakaian.'
