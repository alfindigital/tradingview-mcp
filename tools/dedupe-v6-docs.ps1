# Membersihkan duplikat di refs/pine-v6-docs:
#  - "Pine Script language reference manual" (403 KB, tanpa ekstensi) = isi sama dgn
#    pinescriptv6_complete_reference.md, cuma beda header.
#  - concepts/colors_and_display.md identik byte-per-byte dgn visuals/colors.md.
#  - pine_script_execution_model.md (root, 106 KB) = hasil scrape lain dari halaman
#    yang sama dgn concepts/execution_model.md (121 KB, lebih rapi).
# File yang dibuang dipindah ke _duplicates/ supaya tidak hilang, bukan dihapus.
param(
    [string]$Root = 'C:\Users\alfin\Documents\IDX\Tradingview'
)

$ErrorActionPreference = 'Stop'

$docs = Join-Path $Root 'refs\pine-v6-docs'
$dupDir = Join-Path $docs '_duplicates'
New-Item -ItemType Directory -Force -Path $dupDir | Out-Null

$utf8 = New-Object System.Text.UTF8Encoding $false

$moves = @(
    @{
        From   = 'Pine Script language reference manual'
        Reason = 'Isi identik dengan pinescriptv6_complete_reference.md (hanya beda 4 baris header). Nama file tanpa ekstensi bikin tool markdown tidak mengenalinya.'
        Keep   = 'pinescriptv6_complete_reference.md'
    },
    @{
        From   = 'concepts\colors_and_display.md'
        Reason = 'Identik byte-per-byte (39.586 byte) dengan visuals/colors.md.'
        Keep   = 'visuals/colors.md'
    },
    @{
        From   = 'pine_script_execution_model.md'
        Reason = 'Hasil scrape terpisah dari halaman yang sama dengan concepts/execution_model.md, tapi lebih pendek (106 KB vs 121 KB) dan format headingnya lebih kacau.'
        Keep   = 'concepts/execution_model.md'
    }
)

$log = @()
foreach ($mv in $moves) {
    $src = Join-Path $docs $mv.From
    if (-not (Test-Path $src)) {
        Write-Output ("SKIP   {0} (tidak ada)" -f $mv.From)
        continue
    }
    $size = (Get-Item $src).Length
    $leaf = Split-Path $mv.From -Leaf
    Move-Item -Force $src (Join-Path $dupDir $leaf)
    Write-Output ("MOVED  {0,-45} -> _duplicates\  ({1:N0} bytes)" -f $mv.From, $size)
    $log += "## ``$($mv.From)``\n\n- **Ukuran:** $('{0:N0}' -f $size) bytes\n- **Alasan dipindah:** $($mv.Reason)\n- **Pakai ini sebagai gantinya:** ``$($mv.Keep)``\n"
}

if ($log.Count -gt 0) {
    $readme = "# File duplikat dari repo asal`r`n`r`n"
    $readme += "Folder ini menampung file dari codenamedevan/pinescriptv6 yang isinya duplikat.`r`n"
    $readme += "Sengaja dipindah, bukan dihapus, supaya tetap bisa dibandingkan kalau perlu.`r`n"
    $readme += "Jangan dipakai sebagai referensi; pakai file penggantinya.`r`n`r`n---`r`n`r`n"
    $readme += (($log -join "`r`n") -replace '\\n', "`r`n")
    [System.IO.File]::WriteAllText((Join-Path $dupDir 'README.md'), $readme, $utf8)
}

# Rapikan artefak separator ganda "---\n\n---" hasil penggabungan di variables.md
$vars = Join-Path $docs 'reference\variables.md'
if (Test-Path $vars) {
    $c = Get-Content -Raw -Encoding UTF8 $vars
    $before = ([regex]::Matches($c, '(?m)^---\s*\r?\n\s*\r?\n---\s*$')).Count
    if ($before -gt 0) {
        $c = [regex]::Replace($c, '(?m)^---\s*\r?\n\s*\r?\n---\s*$', '---')
        [System.IO.File]::WriteAllText($vars, $c, $utf8)
        Write-Output ("CLEAN  reference\variables.md: {0} separator ganda dirapikan" -f $before)
    }
}

Write-Output ''
Write-Output ("Sisa file di refs\pine-v6-docs : {0}" -f (Get-ChildItem -Recurse -File $docs | Where-Object { $_.DirectoryName -notlike "*_duplicates*" }).Count)
