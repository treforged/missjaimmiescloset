<#
    verify-domain.ps1 - is missjaimmiescloset.com actually serving THIS repo?

    Run this ONLY after Tre reports the Cloudflare/DNS move is done. It answers
    one question and refuses to guess at it.

    WHY IT CHECKS THREE TLS STACKS. On 2026-09-15 the domain refused https in
    Chrome (ERR_SSL_VERSION_OR_CIPHER_MISMATCH) and in schannel
    (SEC_E_ILLEGAL_MESSAGE). One stack failing can be a local quirk; three
    independent stacks agreeing is a fact about the server.

    WHY THE POSITIVE CONTROL. A run where everything fails is ambiguous - the
    site may be down, or this machine may simply have no egress. treforged.com
    is fetched in the SAME run, so a failure there means the instrument is
    blind and this script says so instead of blaming the site.

    WHY IT COMPARES THE BODY. The domain previously answered http 200 with a
    583-byte Square placeholder reading "Thanks for purchasing". A 200 is a
    fact about the HTTP layer, not about whose page came back.

    Exit codes:  0 = serving this repo   1 = not serving it   2 = cannot tell
#>

param(
    # Overridable ONLY so the script's own pass/fail paths can be proven. Left
    # at the defaults it answers the real question about the real domain.
    [string]$Domain  = 'https://missjaimmiescloset.com/',
    [string]$Control = 'https://treforged.com/'
)

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Marker  = 'MissJaimmie'          # appears in this repo's page, not in the placeholder
$results = @()

function Add-Result($stack, $ok, $detail) {
    $script:results += [pscustomobject]@{ Stack = $stack; Ok = $ok; Detail = $detail }
}

# --- stack 1: .NET HttpWebRequest (schannel), no redirect follow ------------
# no-follow on purpose: a followed 200 is a fact about wherever you LANDED.
try {
    $r = [Net.HttpWebRequest]::Create($Domain + '?cb=' + [Guid]::NewGuid())
    $r.AllowAutoRedirect = $false; $r.UserAgent = 'Mozilla/5.0'; $r.Timeout = 20000
    $resp = $r.GetResponse()
    $code = [int]$resp.StatusCode
    $body = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
    Add-Result '.NET/schannel' ($code -eq 200) "status=$code loc=$($resp.Headers['Location']) bytes=$($body.Length)"
    $script:dotnetBody = $body
} catch { Add-Result '.NET/schannel' $false "ERR $($_.Exception.Message)" }

# --- stack 2: curl (its own schannel/OpenSSL build) ------------------------
$curl = (Get-Command curl.exe -ErrorAction SilentlyContinue)
if ($curl) {
    $out = & curl.exe -s -o NUL -w '%{http_code}' --max-time 20 $Domain 2>&1
    Add-Result 'curl' ($out -eq '200') "status=$out"
} else { Add-Result 'curl' $false 'curl.exe not found' }

# --- stack 3: python / OpenSSL --------------------------------------------
$py = (Get-Command python -ErrorAction SilentlyContinue)
if ($py) {
    $script = @'
import ssl,urllib.request,sys
try:
    r=urllib.request.urlopen(sys.argv[1],timeout=20)
    b=r.read().decode("utf-8","replace")
    print(f"status={r.status} bytes={len(b)}")
    sys.exit(0 if r.status==200 else 1)
except Exception as e:
    print(f"ERR {type(e).__name__}: {e}"); sys.exit(1)
'@
    $tmp = Join-Path $env:TEMP ("mjc_probe_{0}.py" -f [Guid]::NewGuid())
    [IO.File]::WriteAllText($tmp, $script, [Text.Encoding]::UTF8)
    $out = & python $tmp $Domain 2>&1 | Out-String
    Add-Result 'python/OpenSSL' ($LASTEXITCODE -eq 0) ($out.Trim())
    Remove-Item $tmp -ErrorAction SilentlyContinue
} else { Add-Result 'python/OpenSSL' $false 'python not found' }

# --- positive control: is this machine able to reach ANY https site? -------
$controlOk = $false
try {
    $r = [Net.HttpWebRequest]::Create($Control); $r.Timeout = 20000; $r.UserAgent = 'Mozilla/5.0'
    $resp = $r.GetResponse(); $controlOk = ([int]$resp.StatusCode -eq 200)
    Add-Result 'CONTROL treforged.com' $controlOk "status=$([int]$resp.StatusCode)"
} catch { Add-Result 'CONTROL treforged.com' $false "ERR $($_.Exception.Message)" }

# --- report ----------------------------------------------------------------
Write-Host "`n  $Domain - is it serving this repo?`n"
$results | Format-Table -AutoSize | Out-String | Write-Host

$examined = ($results | Where-Object { $_.Stack -notlike 'CONTROL*' }).Count
if ($examined -eq 0) { Write-Host "REFUSED: examined 0 stacks - nothing was measured."; exit 2 }

if (-not $controlOk) {
    Write-Host "CANNOT TELL: the positive control failed, so this machine could not reach a"
    Write-Host "known-good https site either. That is a fact about this network, not the domain."
    exit 2
}

$passed = ($results | Where-Object { $_.Stack -notlike 'CONTROL*' -and $_.Ok }).Count
Write-Host "https reachable on $passed of $examined stacks (control green)."

if ($passed -lt $examined) {
    Write-Host "`nNOT SERVING THIS REPO: at least one TLS stack was refused. On 2026-09-15 this"
    Write-Host "was ERR_SSL_VERSION_OR_CIPHER_MISMATCH - the domain pointed at Weebly"
    Write-Host "(199.34.228.66 / pages-custom-18.weebly.com) with no certificate for this name."
    exit 1
}

# every stack answered - now check WHOSE page answered
$repoFile = Join-Path $RepoRoot 'index.html'
if (-not (Test-Path $repoFile)) { Write-Host "REFUSED: cannot find index.html to compare against."; exit 2 }

if (-not $script:dotnetBody) { Write-Host "REFUSED: no body captured to compare."; exit 2 }

$isPlaceholder = $script:dotnetBody -match 'Thanks for purchasing|domain-placeholder-app'
$hasMarker     = $script:dotnetBody -match $Marker

if ($isPlaceholder) {
    Write-Host "`nNOT SERVING THIS REPO: https answered, but the body is the Square/Weebly"
    Write-Host "placeholder. A 200 is a fact about the HTTP layer, not about whose page it is."
    exit 1
}
if (-not $hasMarker) {
    Write-Host "`nNOT SERVING THIS REPO: https answered and it is not the known placeholder,"
    Write-Host "but the marker '$Marker' is absent - some third page is being served."
    exit 1
}

Write-Host "`nSERVING THIS REPO: https green on all $examined stacks and the body carries '$Marker'."
Write-Host "Remaining check a script cannot make: open it and look at it."
exit 0
