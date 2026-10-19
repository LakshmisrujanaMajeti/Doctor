param (
    [int]$Port = 54321
)

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Look for web directory
$Candidates = @(
    (Join-Path $BaseDir "web_app"),
    (Join-Path $BaseDir "frontend\build\web"),
    (Join-Path $BaseDir "desktop\web")
)

$TargetDir = $null
foreach ($c in $Candidates) {
    if (Test-Path (Join-Path $c "index.html")) {
        $TargetDir = $c
        break
    }
}

if (-not $TargetDir) {
    Write-Host "[ERROR] Compiled web application not found!" -ForegroundColor Red
    Write-Host "Checked locations:" -ForegroundColor Gray
    foreach ($c in $Candidates) {
        Write-Host " - $c" -ForegroundColor Gray
    }
    exit 1
}

$MimeTypes = @{
    ".html"  = "text/html; charset=utf-8"
    ".js"    = "text/javascript; charset=utf-8"
    ".css"   = "text/css; charset=utf-8"
    ".wasm"  = "application/wasm"
    ".json"  = "application/json; charset=utf-8"
    ".png"   = "image/png"
    ".jpg"   = "image/jpeg"
    ".svg"   = "image/svg+xml"
    ".ttf"   = "font/ttf"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
}

$Listener = New-Object System.Net.HttpListener
$Prefix = "http://127.0.0.1:$Port/"
$Listener.Prefixes.Add($Prefix)

try {
    $Listener.Start()
} catch {
    Write-Host "[✓] Port $Port already active or in use. Existing session will be used." -ForegroundColor Yellow
    exit 0
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "   SRI MANAKULA VINAYAGAR MEDICAL COLLEGE & HOSPITAL - OPD CONNECT" -ForegroundColor Cyan
Write-Host "   Windows PowerShell Local Workstation Server" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [*] Serving Directory : $TargetDir" -ForegroundColor Gray
Write-Host " [*] Active Endpoint   : $Prefix" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

while ($Listener.IsListening) {
    try {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response

        $RawPath = $Request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($RawPath)) {
            $RawPath = "index.html"
        }

        $FilePath = Join-Path $TargetDir $RawPath
        if (-not (Test-Path $FilePath) -or (Test-Path $FilePath -PathType Container)) {
            $FilePath = Join-Path $TargetDir "index.html"
        }

        $Ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $ContentType = "application/octet-stream"
        if ($MimeTypes.ContainsKey($Ext)) {
            $ContentType = $MimeTypes[$Ext]
        }

        $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $Response.ContentType = $ContentType
        $Response.ContentLength64 = $Bytes.Length
        $Response.AddHeader("Access-Control-Allow-Origin", "*")
        $Response.AddHeader("Cross-Origin-Embedder-Policy", "credentialless")
        $Response.AddHeader("Cross-Origin-Opener-Policy", "same-origin")
        $Response.AddHeader("Cache-Control", "no-cache")

        $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
        $Response.OutputStream.Close()
    } catch {
        # continue serving
    }
}
