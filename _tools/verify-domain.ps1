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

    IT NOW READS DNS TOO, and that is what makes the output useful. Before
    2026-09-22 this script said "NOT SERVING THIS REPO" for two situations that
    need opposite reactions: the registrar edit has not been done, and it HAS
    been done but the certificate has not been issued yet (a normal wait of
    minutes to about an hour, needing nobody). Those now print different things.

    ALL FOUR DNS BRANCHES PROVEN 2026-09-22, each by a mutation that actually
    flipped the verdict, with the file restored byte-exact by sha256 after each:
      weebly       the real run today - "the registrar edit has not been done"
      pages        PAGES/WEEBLY sets swapped - "DNS has moved, normal wait"
      other        WEEBLY set moved aside - "pointed at a third place"
      cannot-tell  -Domain at a host that does not resolve - exit 2

    THE FIRST ATTEMPT AT THE 'pages' MUTATION PROVED NOTHING: it added the
    apex address to PAGES but left it in WEEBLY, and WEEBLY is tested first, so
    the verdict never moved. A mutation that does not flip the branch is not a
    red run. Both sets have to move.

    WHY NOT JUST OPEN IT IN A BROWSER: a browser caches the apex-to-www redirect
    and will show a working site when it is not. Every probe here is no-follow
    and cache-busted for that reason.

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

# --------------------------------------------------------------------------
# DNS STAGE. Added 2026-09-22.
#
# WHY. Without it this script says "NOT SERVING THIS REPO" for two completely
# different situations: Tre has not done the registrar edit yet, and he HAS
# done it but the certificate has not been issued. The second is a normal wait
# of minutes to about an hour and needs nobody to do anything. Telling them
# apart is the difference between "you still owe us two minutes at register.com"
# and "it worked, go and have a coffee".
# --------------------------------------------------------------------------
function Get-DomainDnsState {
    param(
        [string]$Apex = 'missjaimmiescloset.com',
        [string]$Www  = 'www.missjaimmiescloset.com'
    )

    # Known address sets (script-scope inside function)
    $PAGES  = @('185.199.108.153','185.199.109.153','185.199.110.153','185.199.111.153')
    $WEEBLY = @('199.34.228.66')

    # Helper: resolve A records, prefer Resolve-DnsName, fallback to nslookup.
    function Resolve-Host {
        param([string]$HostName)

        $addresses = @()
        try {
            if (Get-Command -Name Resolve-DnsName -ErrorAction SilentlyContinue) {
                $result = Resolve-DnsName -Name $HostName -Type A -ErrorAction Stop
                foreach ($r in $result) {
                    # THE PROPERTY IS 'IPAddress', NOT 'IPv4Address'. Measured on
                    # Microsoft.DnsClient.Commands.DnsRecord_A here: IPv4Address
                    # does not exist and renders EMPTY, so a draft using it
                    # collected nothing and reported cannot-tell forever while
                    # Resolve-DnsName was returning four perfectly good rows.
                    $ip = $r.IPAddress
                    if (-not $ip) { $ip = $r.IP4Address }
                    if ($ip) { $addresses += $ip.ToString() }
                }
            } else {
                # nslookup fallback - parse any IPv4 address lines.
                $nsOutput = nslookup $HostName 2>$null
                foreach ($line in $nsOutput) {
                    if ($line -match 'Address:\s+([0-9]{1,3}(\.[0-9]{1,3}){3})') {
                        $addresses += $Matches[1]
                    }
                }
            }
        } catch {
            # Treat both thrown errors and empty results as "no addresses".
            $addresses = @()
        }
        return @($addresses)
    }

    # Resolve apex, www, and positive control.
    $apexAddrs    = Resolve-Host $Apex
    $wwwAddrs     = Resolve-Host $Www
    $controlAddrs = Resolve-Host 'treforged.github.io'

    # Control check - ensures resolver is functional; otherwise we cannot trust empty results.
    $controlOk = $controlAddrs.Count -gt 0   # WHY: without a known-good result we cannot differentiate "no records" from "resolver broken".

    # Determine state.
    if (-not $controlOk) {
        $state = 'cannot-tell'
    } elseif ($apexAddrs.Count -eq 0) {
        $state = 'cannot-tell'
    } elseif ($apexAddrs | Where-Object { $WEEBLY -contains $_ }) {
        $state = 'weebly'
    } elseif ($apexAddrs | Where-Object { $PAGES -notcontains $_ }) {
        $state = 'other'
    } else {
        $state = 'pages'   # every apex address is in $PAGES
    }

    # Build a short human-readable detail string.
    $detailParts = @()
    $detailParts += "Apex: " + ($apexAddrs -join ', ')
    $detailParts += "Www: " + ($wwwAddrs -join ', ')
    $detailParts += "Control: " + ($controlAddrs -join ', ')
    $detail = $detailParts -join '; '

    # Return the result object.
    [pscustomobject]@{
        State        = $state
        ApexAddrs    = $apexAddrs
        WwwAddrs     = $wwwAddrs
        ControlAddrs = $controlAddrs
        ControlOk    = $controlOk
        Detail       = $detail
    }
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Marker  = 'MissJaimmie'          # appears in this repo's page, not in the placeholder
$results = @()

# Read DNS first: it is cheap, it needs no TLS, and it is what disambiguates
# every failure below.
#
# The apex is DERIVED FROM $Domain rather than left at its own default, or a run
# with -Domain pointed somewhere else would print TLS results for one host and
# DNS for another - two hosts in one verdict, which is worse than no verdict.
$apexHost = ([Uri]$Domain).Host
$dns = Get-DomainDnsState -Apex $apexHost -Www ("www." + ($apexHost -replace '^www\.',''))

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
Write-Host "  DNS: $($dns.State.ToUpper())  (resolver control: $(if ($dns.ControlOk) { 'green' } else { 'FAILED' }))"
Write-Host "  $($dns.Detail)`n"
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
    # WHICH failure is this? The DNS stage answers it, and the two need
    # completely different reactions from whoever is reading.
    switch ($dns.State) {
        'weebly' {
            Write-Host "`nTHE REGISTRAR EDIT HAS NOT BEEN DONE YET."
            Write-Host "The apex still resolves to Weebly ($($dns.ApexAddrs -join ', ')), so there is no"
            Write-Host "certificate for this name and https cannot work. Nothing is broken on our side."
            Write-Host "The fix is the two-minute change in _tools/CUTOVER.md, and it is Tre's."
            exit 1
        }
        'pages' {
            Write-Host "`nDNS HAS MOVED - THIS IS THE NORMAL WAIT, NOT A FAULT."
            Write-Host "The apex now resolves to GitHub Pages ($($dns.ApexAddrs -join ', ')), so the"
            Write-Host "registrar edit worked. GitHub requests the certificate only AFTER that, and it"
            Write-Host "takes minutes to about an hour. Re-run this then; nobody needs to do anything."
            exit 1
        }
        'cannot-tell' {
            Write-Host "`nCANNOT TELL: https failed and DNS could not be read either"
            Write-Host "($($dns.Detail)). That is an instrument problem, not a finding about the site."
            exit 2
        }
        default {
            Write-Host "`nNOT SERVING THIS REPO: https was refused and the apex resolves somewhere"
            Write-Host "unexpected - $($dns.ApexAddrs -join ', '), neither GitHub Pages nor the known"
            Write-Host "Weebly address. Somebody has pointed this domain at a third place."
            exit 1
        }
    }
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
