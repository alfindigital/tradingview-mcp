# Memulihkan entri variabel bawaan yang terpotong di awal reference/variables.md.
# Repo asal codenamedevan/pinescriptv6 kehilangan 26 entri pertama secara alfabetis
# (ask s/d dividends.future_amount), termasuk `close` dan `bar_index`.
param(
    [string]$Root = 'C:\Users\alfin\Documents\IDX\Tradingview'
)

$ErrorActionPreference = 'Stop'

$docs = Join-Path $Root 'refs\pine-v6-docs'
$monolith = Join-Path $docs 'pinescriptv6_complete_reference.md'
$target = Join-Path $docs 'reference\variables.md'

$raw = Get-Content -Raw -Encoding UTF8 $monolith
$m = [regex]::Matches($raw, '(?m)^##[ \t]+(?<name>.+?)[ \t]*\r?$')

$entries = [ordered]@{}
for ($i = 0; $i -lt $m.Count; $i++) {
    $start = $m[$i].Index
    $end = if ($i -lt $m.Count - 1) { $m[$i + 1].Index } else { $raw.Length }
    $entries[$m[$i].Groups['name'].Value.Trim()] = $raw.Substring($start, $end - $start).TrimEnd()
}

$existing = Get-Content -Raw -Encoding UTF8 $target

# Kumpulkan nama yang sudah tercakup di seluruh file reference/ agar tidak dobel
$covered = @()
foreach ($f in 'variables', 'constants', 'keywords', 'types', 'operators', 'annotations') {
    $p = Join-Path $docs "reference\$f.md"
    if (Test-Path $p) {
        $c = Get-Content -Raw -Encoding UTF8 $p
        $covered += ([regex]::Matches($c, '(?m)^#{2,3}[ \t]+(.+?)[ \t]*$') | ForEach-Object { $_.Groups[1].Value })
    }
}

# Variabel = entri tanpa tanda "()", bukan operator/anotasi/keyword/tipe
$skip = @(
    'and', 'or', 'not', 'if', 'else', 'for', 'for...in', 'while', 'switch', 'var', 'varip',
    'export', 'import', 'method', 'type', 'enum',
    'array', 'bool', 'box', 'chart.point', 'color', 'const', 'float', 'footprint', 'int',
    'label', 'line', 'linefill', 'map', 'matrix', 'polyline', 'series', 'simple', 'string', 'table',
    'true', 'false'
)

$missing = @()
foreach ($name in $entries.Keys) {
    if ($name -like '*()') { continue }
    if ($name -match '^@') { continue }
    if ($name -notmatch '^[A-Za-z_]') { continue }
    if ($skip -contains $name) { continue }
    if ($covered -contains $name) { continue }
    $missing += $name
}

if ($missing.Count -eq 0) {
    Write-Output 'variables.md sudah lengkap, tidak ada yang dipulihkan.'
    return
}

# Ubah heading dari "## nama" menjadi "### nama" agar seragam dengan variables.md,
# dan turunkan sub-bagiannya satu level.
$restored = foreach ($name in $missing) {
    $body = $entries[$name]
    $body = $body -replace ('(?m)^##[ \t]+' + [regex]::Escape($name) + '[ \t]*$'), ('### ' + $name)
    $body = $body -replace '(?m)^###[ \t]+(Returns|Remarks|Code Example|See also|Type)[ \t]*$', '#### $1'
    $body.TrimEnd()
}

$header = @"
# Built-in Variables

Pine Script v6 - variabel bawaan (read-only).

$($missing.Count) entri pertama secara alfabetis (``$($missing[0])`` s/d ``$($missing[-1])``) hilang
dari repo asal codenamedevan/pinescriptv6 karena hasil scrape terpotong di bagian awal file;
entri tersebut dipulihkan di sini dari ``pinescriptv6_complete_reference.md`` oleh
``tools/repair-variables.ps1``. Termasuk ``close`` dan ``bar_index``.

---

"@

$utf8 = New-Object System.Text.UTF8Encoding $false
$content = $header + (($restored -join "`r`n`r`n---`r`n`r`n")) + "`r`n`r`n---`r`n`r`n" + $existing.TrimStart()
[System.IO.File]::WriteAllText($target, $content, $utf8)

$after = Get-Content -Raw -Encoding UTF8 $target
$count = ([regex]::Matches($after, '(?m)^###[ \t]+\S')).Count
Write-Output ("FIXED  variables.md  +{0} dipulihkan  total h3={1}  {2:N0} bytes" -f $missing.Count, $count, (Get-Item $target).Length)
Write-Output ("       dipulihkan: {0}" -f ($missing -join ', '))
