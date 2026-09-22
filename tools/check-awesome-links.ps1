# Memverifikasi seluruh link di refs/awesome-pinescript/README.md, lalu:
#  - menulis laporan ke refs/awesome-pinescript/DEAD-LINKS.md
#  - menandai link mati langsung di README.md (aslinya disimpan sbg README.original.md)
# Jalankan ulang kapan saja untuk cek ulang: link komersial cepat usang.
param(
    [string]$Root = 'C:\Users\alfin\Documents\IDX\Tradingview',
    [int]$TimeoutSec = 15
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dir = Join-Path $Root 'refs\awesome-pinescript'
$readme = Join-Path $dir 'README.md'
$original = Join-Path $dir 'README.original.md'
$report = Join-Path $dir 'DEAD-LINKS.md'

if (-not (Test-Path $original)) { Copy-Item $readme $original }
$src = Get-Content -Raw -Encoding UTF8 $original

$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'

$urls = [regex]::Matches($src, '\]\((https?://[^)\s]+)\)') |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -notmatch 'shields\.io|komarev\.com|awesome\.re' } |
    Select-Object -Unique

Write-Output "Memeriksa $($urls.Count) link unik..."

$results = foreach ($u in $urls) {
    $status = $null
    $verdict = 'ok'
    $note = ''

    try {
        $r = Invoke-WebRequest -Uri $u -UseBasicParsing -UserAgent $ua -TimeoutSec $TimeoutSec -MaximumRedirection 5 -ErrorAction Stop
        $status = [int]$r.StatusCode
    }
    catch {
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            # 403/405 umumnya anti-bot, bukan link mati
            if ($status -in 401, 403, 405, 429) {
                $verdict = 'unverified'
                $note = "HTTP $status - diblokir bot, cek manual di browser"
            }
            else {
                $verdict = 'dead'
                $note = "HTTP $status"
            }
        }
        else {
            $msg = ($_.Exception.Message -replace '\s+', ' ').Trim()
            if ($msg -match 'remote name could not be resolved|No such host') {
                $verdict = 'dead'
                $note = 'Domain tidak ada (DNS gagal)'
            }
            else {
                $verdict = 'unverified'
                $note = $msg
            }
        }
    }

    # Untuk repo GitHub, API lebih dapat dipercaya daripada scraping HTML.
    # Kalau kena rate limit (403), pertahankan hasil dari cek HTTP biasa.
    if ($u -match '^https?://github\.com/([^/]+)/([^/#?]+)/?$') {
        try {
            $null = Invoke-RestMethod "https://api.github.com/repos/$($matches[1])/$($matches[2])" -Headers @{ 'User-Agent' = 'link-check' } -TimeoutSec $TimeoutSec -ErrorAction Stop
            $verdict = 'ok'; $note = ''
        }
        catch {
            if ($_.Exception.Response) {
                $sc = [int]$_.Exception.Response.StatusCode
                if ($sc -eq 404) { $verdict = 'dead'; $note = 'Repo GitHub sudah dihapus (API 404)' }
            }
        }
    }

    [pscustomobject]@{ Url = $u; Status = $status; Verdict = $verdict; Note = $note }
}

$dead = @($results | Where-Object { $_.Verdict -eq 'dead' })
$unver = @($results | Where-Object { $_.Verdict -eq 'unverified' })
$ok = @($results | Where-Object { $_.Verdict -eq 'ok' })

# --- Laporan ------------------------------------------------------------------
$utf8 = New-Object System.Text.UTF8Encoding $false
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# Hasil verifikasi link - awesome-pinescript')
[void]$sb.AppendLine()
[void]$sb.AppendLine("Dicek pada $(Get-Date -Format 'yyyy-MM-dd') oleh ``tools/check-awesome-links.ps1``.")
[void]$sb.AppendLine()
[void]$sb.AppendLine("- Total link unik: **$($results.Count)**")
[void]$sb.AppendLine("- Hidup: **$($ok.Count)**")
[void]$sb.AppendLine("- Mati: **$($dead.Count)**")
[void]$sb.AppendLine("- Tidak terverifikasi (anti-bot / TLS): **$($unver.Count)**")
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Link mati')
[void]$sb.AppendLine()
if ($dead.Count -eq 0) {
    [void]$sb.AppendLine('Tidak ada.')
}
else {
    [void]$sb.AppendLine('| URL | Masalah |')
    [void]$sb.AppendLine('|---|---|')
    foreach ($d in ($dead | Sort-Object Url)) {
        [void]$sb.AppendLine("| ``$($d.Url)`` | $($d.Note) |")
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Catatan: beberapa link script TradingView di daftar ini punya ID berurutan')
    [void]$sb.AppendLine('(``2j6YH6gD``, ``3j6YH6gD``, ``4j6YH6gD``, ``8j6YH6gD``, ``10j6YH6gD``). Pola begitu')
    [void]$sb.AppendLine('bukan format ID TradingView asli, jadi kemungkinan besar link karangan yang lolos')
    [void]$sb.AppendLine('lewat pull request. Jangan cari padanannya, entri itu memang tidak pernah ada.')
}
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Tidak terverifikasi dari skrip')
[void]$sb.AppendLine()
[void]$sb.AppendLine('Situs berikut memblokir permintaan otomatis atau menolak handshake TLS.')
[void]$sb.AppendLine('Kemungkinan besar normal saat dibuka di browser; cek manual kalau perlu.')
[void]$sb.AppendLine()
if ($unver.Count -eq 0) {
    [void]$sb.AppendLine('Tidak ada.')
}
else {
    [void]$sb.AppendLine('| URL | Keterangan |')
    [void]$sb.AppendLine('|---|---|')
    foreach ($d in ($unver | Sort-Object Url)) {
        [void]$sb.AppendLine("| ``$($d.Url)`` | $($d.Note) |")
    }
}
[System.IO.File]::WriteAllText($report, $sb.ToString(), $utf8)

# --- Tandai di README ---------------------------------------------------------
$annotated = $src
foreach ($d in $dead) {
    $esc = [regex]::Escape($d.Url)
    $annotated = [regex]::Replace($annotated, "\]\($esc\)", "]($($d.Url)) **[LINK MATI: $($d.Note)]**")
}

$banner = @"
> **Catatan lokal:** link mati sudah ditandai ``**[LINK MATI: ...]**`` di dalam daftar ini.
> Ringkasannya ada di [DEAD-LINKS.md](DEAD-LINKS.md). Versi asli tanpa penanda ada di
> [README.original.md](README.original.md). Cek ulang kapan saja dengan
> ``tools/check-awesome-links.ps1`` - banyak entri di bagian Closed Source adalah
> layanan komersial yang cepat usang.

"@

# Sisipkan banner setelah judul pertama
$lines = $annotated -split "`r?`n"
$idx = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^#\s') { $idx = $i + 1; break }
}
$new = @()
$new += $lines[0..$idx]
$new += ''
$new += ($banner -split "`r?`n")
if ($idx + 1 -lt $lines.Count) { $new += $lines[($idx + 1)..($lines.Count - 1)] }

[System.IO.File]::WriteAllText($readme, ($new -join "`r`n"), $utf8)

Write-Output ''
Write-Output ("WROTE  DEAD-LINKS.md   {0} mati, {1} tak terverifikasi, {2} hidup" -f $dead.Count, $unver.Count, $ok.Count)
Write-Output ("ANNOT  README.md       {0} penanda disisipkan (asli -> README.original.md)" -f $dead.Count)
foreach ($d in ($dead | Sort-Object Url)) { Write-Output ("       DEAD  {0}  ({1})" -f $d.Url, $d.Note) }
