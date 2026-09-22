# Membangun reference/functions/*.md untuk Pine Script v6.
#
# Dua sumber digabung karena keduanya saling melengkapi:
#  1. File asli repo (ta.md, request.md) - punya bagian Syntax + Arguments yang
#     rinci, tapi 4 file lain kosong 1 byte dan request.md kurang 4 fungsi.
#  2. pinescriptv6_complete_reference.md - memuat 457 fungsi, tapi tanpa
#     Syntax/Arguments (hanya deskripsi, Returns, Remarks, Code Example).
#
# Aturan gabung: kalau satu fungsi ada di dua sumber, ambil body yang lebih
# panjang. Ini mempertahankan Syntax/Arguments dari file asli sekaligus menambal
# fungsi yang cuma ada di monolith. request.footprint() misalnya hanya ada di
# file asli, sedangkan request.economic() hanya ada di monolith.
#
# File ini HANYA memuat fungsi (nama berakhiran "()"). Entri non-fungsi seperti
# color.red atau strategy.position_size sudah punya rumah di constants.md dan
# variables.md, jadi tidak diduplikasi ke sini.
param(
    [string]$Root = 'C:\Users\alfin\Documents\IDX\Tradingview'
)

$ErrorActionPreference = 'Stop'

$docs = Join-Path $Root 'refs\pine-v6-docs'
$monolith = Join-Path $docs 'pinescriptv6_complete_reference.md'
$outDir = Join-Path $docs 'reference\functions'

if (-not (Test-Path $monolith)) { throw "Tidak ditemukan: $monolith" }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# --- Pembaca entri generik ----------------------------------------------------
# Memecah markdown pada heading level tertentu, mengembalikan nama -> body.
function Read-Entries {
    param([string]$Text, [string]$HeadingLevel)

    $rx = '(?m)^' + $HeadingLevel + '[ \t]+(?<name>.+?)[ \t]*\r?$'
    $m = [regex]::Matches($Text, $rx)
    $out = [ordered]@{}
    for ($i = 0; $i -lt $m.Count; $i++) {
        $start = $m[$i].Index
        $end = if ($i -lt $m.Count - 1) { $m[$i + 1].Index } else { $Text.Length }
        $name = $m[$i].Groups['name'].Value.Trim()
        $body = $Text.Substring($start, $end - $start).Trim()
        # Buang separator "---" di ujung body
        $body = ($body -replace '(?m)\r?\n---\s*$', '').TrimEnd()
        if (-not $out.Contains($name)) { $out[$name] = $body }
    }
    return $out
}

# Menyeragamkan heading entri ke level 2, dan sub-bagiannya ke level 3.
function Set-EntryHeadingLevel {
    param([string]$Body, [string]$Name)

    $b = $Body -replace ('(?m)^#{2,4}[ \t]+' + [regex]::Escape($Name) + '[ \t]*$'), ('## ' + $Name)
    # Di file asli, "Syntax"/"Arguments"/dst kadang berupa paragraf biasa tanpa "#"
    $b = $b -replace '(?m)^(Syntax|Arguments|Returns|Remarks|See also|Type|Example|Code Example)\s*$', '### $1'
    $b = $b -replace '(?m)^#{4,}[ \t]+(Syntax|Arguments|Returns|Remarks|See also|Type|Example|Code Example)[ \t]*$', '### $1'
    return $b.TrimEnd()
}

$monoText = Get-Content -Raw -Encoding UTF8 $monolith
$monoEntries = Read-Entries -Text $monoText -HeadingLevel '##'

# --- Routing per namespace ----------------------------------------------------
$route = [ordered]@{
    'ta'          = @{ File = 'ta.md';          Title = 'Technical Analysis Functions';              Prefix = @('ta') }
    'request'     = @{ File = 'request.md';     Title = 'Request / External Data Functions';         Prefix = @('request') }
    'strategy'    = @{ File = 'strategy.md';    Title = 'Strategy / Backtesting Functions';          Prefix = @('strategy', 'order') }
    'collections' = @{ File = 'collections.md'; Title = 'Collections: Array, Matrix, Map';           Prefix = @('array', 'matrix', 'map') }
    'drawing'     = @{ File = 'drawing.md';     Title = 'Drawing & Plotting Functions';              Prefix = @('plot', 'line', 'label', 'box', 'polyline', 'linefill', 'table', 'color') }
    'general'     = @{ File = 'general.md';     Title = 'General: Math, String, Input, Alert, Time'; Prefix = @('math', 'str', 'input', 'ticker', 'runtime', 'log', 'alert', 'timeframe', 'chart', 'syminfo') }
}

# Fungsi tanpa namespace, dirutekan manual
$exact = @{
    'strategy()'       = 'strategy'
    'plot()'           = 'drawing'
    'plotarrow()'      = 'drawing'
    'plotbar()'        = 'drawing'
    'plotcandle()'     = 'drawing'
    'plotchar()'       = 'drawing'
    'plotshape()'      = 'drawing'
    'fill()'           = 'drawing'
    'hline()'          = 'drawing'
    'bgcolor()'        = 'drawing'
    'barcolor()'       = 'drawing'
    'line()'           = 'drawing'
    'label()'          = 'drawing'
    'box()'            = 'drawing'
    'table()'          = 'drawing'
    'color()'          = 'drawing'
    'linefill()'       = 'drawing'
    'alert()'          = 'general'
    'alertcondition()' = 'general'
    'indicator()'      = 'general'
    'library()'        = 'general'
    'input()'          = 'general'
    'int()'            = 'general'
    'float()'          = 'general'
    'bool()'           = 'general'
    'string()'         = 'general'
    'na()'             = 'general'
    'nz()'             = 'general'
    'fixnan()'         = 'general'
    'max_bars_back()'  = 'general'
    'time()'           = 'general'
    'time_close()'     = 'general'
    'timestamp()'      = 'general'
    'year()'           = 'general'
    'month()'          = 'general'
    'weekofyear()'     = 'general'
    'dayofmonth()'     = 'general'
    'dayofweek()'      = 'general'
    'hour()'           = 'general'
    'minute()'         = 'general'
    'second()'         = 'general'
}

function Get-Bucket([string]$name) {
    if ($exact.ContainsKey($name)) { return $exact[$name] }
    $prefix = if ($name -match '^([A-Za-z_][A-Za-z0-9_]*)\.') { $matches[1] } else { $null }
    if ($prefix) {
        foreach ($k in $route.Keys) {
            if ($route[$k].Prefix -contains $prefix) { return $k }
        }
    }
    return 'general'
}

# --- Kumpulkan fungsi dari file asli repo sebelum ditimpa ----------------------
$upstream = @{}
foreach ($k in $route.Keys) {
    $p = Join-Path $outDir $route[$k].File
    if (-not (Test-Path $p)) { continue }
    if ((Get-Item $p).Length -le 8) { continue }   # file kosong 1 byte

    $text = Get-Content -Raw -Encoding UTF8 $p
    # Level heading entri berbeda antar file asli: ta.md pakai ##, request.md ###
    $lvl = if ([regex]::IsMatch($text, '(?m)^##[ \t]+[a-z_]+\.\S')) { '##' } else { '###' }
    foreach ($e in (Read-Entries -Text $text -HeadingLevel $lvl).GetEnumerator()) {
        if ($e.Key -notlike '*()') { continue }
        $upstream[$e.Key] = $e.Value
    }
}
Write-Output ("Fungsi terbaca dari file asli repo : {0}" -f $upstream.Count)

# --- Gabung kedua sumber ------------------------------------------------------
$names = @($monoEntries.Keys | Where-Object { $_ -like '*()' }) + @($upstream.Keys) |
    Select-Object -Unique | Sort-Object

$merged = @{}
$fromUpstream = 0
$fromMono = 0
$onlyUpstream = @()
$onlyMono = @()

foreach ($n in $names) {
    $u = if ($upstream.ContainsKey($n)) { Set-EntryHeadingLevel -Body $upstream[$n] -Name $n } else { $null }
    $m = if ($monoEntries.Contains($n)) { $monoEntries[$n] } else { $null }

    if ($u -and -not $m) { $merged[$n] = $u; $fromUpstream++; $onlyUpstream += $n }
    elseif ($m -and -not $u) { $merged[$n] = $m; $fromMono++; $onlyMono += $n }
    elseif ($u.Length -ge $m.Length) { $merged[$n] = $u; $fromUpstream++ }
    else { $merged[$n] = $m; $fromMono++ }
}

Write-Output ("Body diambil dari file asli        : {0} (lebih rinci, ada Syntax/Arguments)" -f $fromUpstream)
Write-Output ("Body diambil dari monolith         : {0}" -f $fromMono)
if ($onlyUpstream.Count -gt 0) { Write-Output ("Hanya ada di file asli            : {0}" -f ($onlyUpstream -join ', ')) }
if ($onlyMono.Count -gt 0 -and $onlyMono.Count -le 8) { Write-Output ("Hanya ada di monolith             : {0}" -f ($onlyMono -join ', ')) }

# --- Tulis per bucket ---------------------------------------------------------
$buckets = @{}
foreach ($n in $names) {
    $b = Get-Bucket $n
    if (-not $buckets.ContainsKey($b)) { $buckets[$b] = @() }
    $buckets[$b] += $n
}

$utf8 = New-Object System.Text.UTF8Encoding $false
$total = 0

Write-Output ''
foreach ($k in $route.Keys) {
    if (-not $buckets.ContainsKey($k)) { Write-Warning "Bucket $k kosong."; continue }

    $items = $buckets[$k] | Sort-Object
    $path = Join-Path $outDir $route[$k].File

    # Anchor GitHub membuang "()" sehingga "ta.vwap" dan "ta.vwap()" bertabrakan.
    # Tabrakan diberi sufiks -1, -2 mengikuti perilaku GitHub.
    $seen = @{}
    $anchors = @{}
    foreach ($n in $items) {
        $a = ($n.ToLower() -replace '[^a-z0-9 _-]', '' -replace '\s+', '-')
        if ($seen.ContainsKey($a)) { $seen[$a]++; $anchors[$n] = "$a-$($seen[$a])" }
        else { $seen[$a] = 0; $anchors[$n] = $a }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# $($route[$k].Title)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Pine Script v6 - $($items.Count) fungsi.")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Dibangun oleh `tools/build-function-reference.ps1`, menggabungkan file asli repo')
    [void]$sb.AppendLine('codenamedevan/pinescriptv6 dengan `pinescriptv6_complete_reference.md`. Di repo asal,')
    [void]$sb.AppendLine('`collections.md`, `drawing.md`, `general.md`, dan `strategy.md` kosong (1 byte).')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Hanya memuat fungsi. Konstanta seperti `color.red` ada di `../constants.md`,')
    [void]$sb.AppendLine('variabel seperti `strategy.position_size` dan `ta.obv` ada di `../variables.md`.')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Daftar isi')
    [void]$sb.AppendLine()
    foreach ($n in $items) {
        [void]$sb.AppendLine("- [$n](#$($anchors[$n]))")
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    foreach ($n in $items) {
        [void]$sb.AppendLine($merged[$n])
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('---')
        [void]$sb.AppendLine()
    }

    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8)

    $check = Get-Content -Raw -Encoding UTF8 $path
    $have = ([regex]::Matches($check, '(?m)^##[ \t]+\S')).Count - 1   # minus "Daftar isi"
    $syn = ([regex]::Matches($check, '(?m)^###[ \t]+Syntax')).Count
    $total += $items.Count
    Write-Output ("WROTE  {0,-16} {1,4} fungsi (h2={2,4}, Syntax={3,4})  {4,9:N0} bytes" -f $route[$k].File, $items.Count, $have, $syn, (Get-Item $path).Length)
}

Write-Output ''
Write-Output ("Total fungsi tertulis : {0}" -f $total)
