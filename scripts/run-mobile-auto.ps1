param(
  [string]$DeviceId,
  [string]$ApiHost,
  [int]$ApiPort,
  [string]$ApiPath = '/api/v1',
  [switch]$SkipAdbReverse,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'

function Get-WorkspaceRoot {
  return Split-Path -Parent $PSScriptRoot
}

function Get-BackendPort {
  param([string]$WorkspaceRoot)

  if ($ApiPort) {
    return $ApiPort
  }

  $envPath = Join-Path $WorkspaceRoot 'backend\.env'
  if (Test-Path $envPath) {
    $portLine = Get-Content $envPath | Where-Object { $_ -match '^PORT=' } | Select-Object -First 1
    if ($portLine) {
      $parsed = ($portLine -replace '^PORT=', '').Trim().Trim('"')
      $port = 0
      if ([int]::TryParse($parsed, [ref]$port)) {
        return $port
      }
    }
  }

  return 4000
}

function Get-LanIpAddress {
  if ($ApiHost) {
    return $ApiHost
  }

  try {
    $socket = New-Object System.Net.Sockets.Socket(
      [System.Net.Sockets.AddressFamily]::InterNetwork,
      [System.Net.Sockets.SocketType]::Dgram,
      [System.Net.Sockets.ProtocolType]::Udp
    )
    $socket.Connect('8.8.8.8', 65530)
    $endpoint = [System.Net.IPEndPoint]$socket.LocalEndPoint
    $socket.Dispose()

    if ($endpoint.Address.IPAddressToString) {
      return $endpoint.Address.IPAddressToString
    }
  } catch {
  }

  $privateAddress = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
      $_.IPAddress -notlike '127.*' -and
      $_.IPAddress -notlike '169.254.*' -and
      ($_.IPAddress -like '192.168.*' -or $_.IPAddress -like '10.*' -or $_.IPAddress -like '172.1[6-9].*' -or $_.IPAddress -like '172.2[0-9].*' -or $_.IPAddress -like '172.3[0-1].*')
    } |
    Sort-Object InterfaceMetric |
    Select-Object -First 1

  if ($privateAddress) {
    return $privateAddress.IPAddress
  }

  throw 'Impossible de determiner automatiquement l''IP LAN du PC. Utilise -ApiHost x.x.x.x.'
}

function Get-FlutterDevices {
  $raw = flutter devices --machine | Out-String
  if ([string]::IsNullOrWhiteSpace($raw)) {
    throw 'Aucun resultat retourne par flutter devices.'
  }

  return @($raw | ConvertFrom-Json)
}

function Select-AndroidDevice {
  param([object[]]$Devices)

  $flattenedDevices = foreach ($entry in $Devices) {
    if ($null -eq $entry) {
      continue
    }

    if ($entry -is [System.Array]) {
      foreach ($nestedEntry in $entry) {
        if ($null -ne $nestedEntry) {
          $nestedEntry
        }
      }
      continue
    }

    $entry
  }

  $androidDevices = @($flattenedDevices | Where-Object { $_.targetPlatform -like 'android*' })
  if ($androidDevices.Count -eq 0) {
    throw 'Aucun appareil Android detecte par Flutter.'
  }

  if ($DeviceId) {
    $selected = $androidDevices | Where-Object { $_.id -eq $DeviceId } | Select-Object -First 1
    if (-not $selected) {
      throw "DeviceId '$DeviceId' introuvable parmi les appareils Android connectes."
    }
    return $selected
  }

  if ($androidDevices.Count -eq 1) {
    return $androidDevices[0]
  }

  $deviceList = $androidDevices | ForEach-Object { "- $($_.name) [$($_.id)]" }
  throw "Plusieurs appareils Android sont connectes. Relance avec -DeviceId. `n$($deviceList -join "`n")"
}

function Get-ConnectionMode {
  param([object]$Device)

  $deviceId = $Device.id.ToString()
  if ($Device.emulator -eq $true -or $deviceId -like 'emulator-*') {
    return 'emulator'
  }

  if ($deviceId -match '^\d+\.\d+\.\d+\.\d+:\d+$') {
    return 'wifi'
  }

  return 'usb'
}

function Ensure-AdbReverse {
  param(
    [string]$DeviceSerial,
    [int]$Port
  )

  if ($SkipAdbReverse) {
    return
  }

  & adb -s $DeviceSerial reverse "tcp:$Port" "tcp:$Port" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "adb reverse a echoue pour l'appareil $DeviceSerial sur le port $Port."
  }
}

function Join-ApiBaseUrl {
  param(
    [string]$ApiServerHost,
    [int]$Port,
    [string]$Path
  )

  $normalizedPath = if ([string]::IsNullOrWhiteSpace($Path)) { '/api/v1' } elseif ($Path.StartsWith('/')) { $Path } else { "/$Path" }
  return "http://$ApiServerHost`:$Port$normalizedPath"
}

$workspaceRoot = Get-WorkspaceRoot
$resolvedPort = Get-BackendPort -WorkspaceRoot $workspaceRoot
$devices = Get-FlutterDevices
$device = Select-AndroidDevice -Devices $devices
$mode = Get-ConnectionMode -Device $device

switch ($mode) {
  'emulator' {
    $baseUrl = Join-ApiBaseUrl -ApiServerHost '10.0.2.2' -Port $resolvedPort -Path $ApiPath
  }
  'usb' {
    Ensure-AdbReverse -DeviceSerial $device.id -Port $resolvedPort
    $baseUrl = Join-ApiBaseUrl -ApiServerHost '127.0.0.1' -Port $resolvedPort -Path $ApiPath
  }
  'wifi' {
    $lanIp = Get-LanIpAddress
    $baseUrl = Join-ApiBaseUrl -ApiServerHost $lanIp -Port $resolvedPort -Path $ApiPath
  }
  default {
    throw "Mode de connexion inconnu: $mode"
  }
}

Write-Host "Bahibo mobile auto-run"
Write-Host "- Device: $($device.name) [$($device.id)]"
Write-Host "- Mode: $mode"
Write-Host "- API: $baseUrl"

Push-Location $workspaceRoot
try {
  $runArgs = @(
    'run'
    '-d'
    $device.id
    "--dart-define=BAHIBO_API_BASE_URL=$baseUrl"
  )

  if ($FlutterArgs) {
    $runArgs += $FlutterArgs
  }

  & flutter @runArgs
  exit $LASTEXITCODE
} finally {
  Pop-Location
}