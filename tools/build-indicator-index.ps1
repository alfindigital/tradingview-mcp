# Membuat katalog 210 indikator di refs/indicators-everget:
# nama file, versi Pine, judul study/indicator, dan status siap-pakai.
# Output: refs/INDICATOR-INDEX.md
param(
    [string]$Root = 'C:\Users\alfin\Documents\IDX\Tradingview'
)

$ErrorActionPreference = 'Stop'

$src = Join-Path $Root 'refs\indicators-everget'
$out = Join-Path $Root 'refs\INDICATOR-INDEX.md'

$files = Get-ChildItem -Recurse -File -Filter *.pine $src | Sort-Object FullName

$rows = foreach ($f in $files) {
    $text = Get-Content -Raw -Encoding UTF8 $f.FullName

    $ver = if ($text -match '@version\s*=\s*(\d+)') { [int]$matches[1] } else { 0 }

    # Judul dari study("...") / indicator("...") / strategy("...")
    $title = ''
    $tm = [regex]::Match($text, '(?m)^\s*(?:study|indicator|strategy)\s*\(\s*(?:title\s*=\s*)?["'']([^"'']+)["'']')
    if ($tm.Success) { $title = $tm.Groups[1].Value }
    if (-not $title) {
        $tm2 = [regex]::Match($text, '(?m)^\s*(?:study|indicator|strategy)\s*\(\s*["'']([^"'']+)["'']')
        if ($tm2.Success) { $title = $tm2.Groups[1].Value }
    }

    $short = ''
    $sm = [regex]::Match($text, 'shorttitle\s*=\s*["'']([^"'']+)["'']')
    if ($sm.Success) { $short = $sm.Groups[1].Value }

    $rel = $f.FullName.Substring($src.Length + 1) -replace '\\', '/'
    $folder = ($rel -split '/')[0]

    [pscustomobject]@{
        Folder = $folder
        Rel    = $rel
        Name   = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        Ver    = $ver
        Title  = $title
        Short  = $short
        Lines  = ($text -split "`n").Count
    }
}

$byVer = $rows | Group-Object Ver | Sort-Object Name
$folders = $rows | Group-Object Folder | Sort-Object Name

$folderDesc = @{
    'bands_and_channels' = 'Band & channel: envelope di sekitar harga (breakout, mean reversion)'
    'highlighters'       = 'Penanda visual di chart: sesi, hari, kuartal, tahun kabisat'
    'movings'            = 'Moving average & filter, termasuk banyak varian adaptif dan seri Ehlers'
    'oscillators'        = 'Oscillator momentum: RSI, stochastic, MACD, dan turunannya'
    'research'           = 'Eksperimen & utilitas: deteksi tipe chart, uji bug, clock UTC'
    'statistics'         = 'Statistik & data fundamental: z-score, kurtosis, EPS, DPS, yield'
    'trailing_stops'     = 'Trailing stop & pembalik arah: SuperTrend, Chandelier, HalfTrend, NRTR'
    'utils'              = 'Utilitas developer: unit testing framework, parser input sesi'
    'volatility'         = 'Ukuran volatilitas: ATR ternormalisasi, Ulcer Index, rasio volatilitas'
    'volume'             = 'Indikator berbasis volume: OBV, A/D line, PVT, NVI/PVI'
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# Katalog Indikator - everget/tradingview-pinescript-indicators')
[void]$sb.AppendLine()
[void]$sb.AppendLine("Total **$($rows.Count) indikator** di ``refs/indicators-everget/``. Lisensi GPL-3.0.")
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Peringatan versi Pine')
[void]$sb.AppendLine()
[void]$sb.AppendLine('Sebagian besar file masih memakai sintaks Pine lama dan **tidak bisa langsung ditempel**')
[void]$sb.AppendLine('ke Pine Editor. Konversi dulu, atau pakai sebagai referensi rumus saja.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| Versi | Jumlah | Status |')
[void]$sb.AppendLine('|---|---:|---|')
foreach ($g in $byVer) {
    $status = switch ([int]$g.Name) {
        6 { 'Siap pakai' }
        5 { 'Hampir siap; `//@version=5` masih diterima TradingView' }
        4 { 'Perlu konversi: `study()` -> `indicator()`, namespace `ta.`/`math.`' }
        3 { 'Perlu konversi berat: `input(type=integer)`, `transp=`, fungsi tanpa namespace' }
        default { 'Tanpa header versi' }
    }
    [void]$sb.AppendLine("| v$($g.Name) | $($g.Count) | $status |")
}
[void]$sb.AppendLine()
[void]$sb.AppendLine('### Yang sudah v6 (langsung jalan)')
[void]$sb.AppendLine()
foreach ($r in ($rows | Where-Object { $_.Ver -eq 6 } | Sort-Object Rel)) {
    $t = if ($r.Title) { $r.Title } else { $r.Name }
    [void]$sb.AppendLine("- [``$($r.Rel)``](indicators-everget/$($r.Rel)) - $t")
}
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Catatan: nama file kembar')
[void]$sb.AppendLine()
[void]$sb.AppendLine('Dua nama file muncul di dua folder dengan isi berbeda. Perhatikan folder saat mengambil:')
[void]$sb.AppendLine()
foreach ($g in ($rows | Group-Object Name | Where-Object { $_.Count -gt 1 })) {
    [void]$sb.AppendLine("- ``$($g.Name).pine`` -> " + (($g.Group | ForEach-Object { "``$($_.Rel)`` (v$($_.Ver))" }) -join ' dan '))
}
[void]$sb.AppendLine()
[void]$sb.AppendLine('---')
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Daftar per kategori')
[void]$sb.AppendLine()

foreach ($fg in $folders) {
    $desc = if ($folderDesc.ContainsKey($fg.Name)) { $folderDesc[$fg.Name] } else { '' }
    [void]$sb.AppendLine("### ``$($fg.Name)/`` - $($fg.Count) file")
    [void]$sb.AppendLine()
    if ($desc) {
        [void]$sb.AppendLine($desc)
        [void]$sb.AppendLine()
    }
    [void]$sb.AppendLine('| File | Ver | Judul | Baris |')
    [void]$sb.AppendLine('|---|:---:|---|---:|')
    foreach ($r in ($fg.Group | Sort-Object Name)) {
        $t = $r.Title
        if ($r.Short) { $t = "$t ($($r.Short))" }
        if (-not $t) { $t = '-' }
        $t = $t -replace '\|', '\|'
        $flag = if ($r.Ver -eq 6) { "**v6**" } else { "v$($r.Ver)" }
        [void]$sb.AppendLine("| [$($r.Name)](indicators-everget/$($r.Rel)) | $flag | $t | $($r.Lines) |")
    }
    [void]$sb.AppendLine()
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8)

Write-Output ("WROTE  refs\INDICATOR-INDEX.md  {0} indikator  {1:N0} bytes" -f $rows.Count, (Get-Item $out).Length)
foreach ($g in $byVer) { Write-Output ("       v{0} = {1}" -f $g.Name, $g.Count) }
