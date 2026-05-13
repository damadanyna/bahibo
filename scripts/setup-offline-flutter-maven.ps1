param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-LocalPropertiesValue {
    param(
        [string]$FilePath,
        [string]$Key
    )

    if (-not (Test-Path $FilePath)) {
        throw "Missing local.properties at $FilePath"
    }

    $match = Select-String -Path $FilePath -Pattern "^$([regex]::Escape($Key))=(.+)$" | Select-Object -First 1
    if ($null -eq $match) {
        throw "Missing '$Key' in $FilePath"
    }

    return $match.Matches[0].Groups[1].Value.Trim() -replace '\\\\', '\'
}

function Write-MinimalPom {
    param(
        [string]$PomPath,
        [string]$ArtifactId,
                [string]$Version,
                [array]$Dependencies = @()
    )

        $dependenciesXml = ''
        if ($Dependencies.Count -gt 0) {
                $dependencyLines = foreach ($dependency in $Dependencies) {
@"
        <dependency>
            <groupId>$($dependency.GroupId)</groupId>
            <artifactId>$($dependency.ArtifactId)</artifactId>
            <version>$($dependency.Version)</version>
        </dependency>
"@
                }

                $dependenciesXml = "`n  <dependencies>`n$($dependencyLines -join "`n")`n  </dependencies>"
        }

    $pomContent = @"
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>io.flutter</groupId>
  <artifactId>$ArtifactId</artifactId>
  <version>$Version</version>
    <packaging>jar</packaging>$dependenciesXml
</project>
"@
    Set-Content -Path $PomPath -Value $pomContent -Encoding UTF8
}

function New-FilteredJarFromFlutterJar {
    param(
        [string]$SourceJar,
        [string]$DestinationJar,
        [ValidateSet('embedding', 'native')]
        [string]$ArtifactKind
    )

    if (Test-Path $DestinationJar) {
        Remove-Item $DestinationJar -Force
    }

    $sourceArchive = [System.IO.Compression.ZipFile]::OpenRead($SourceJar)
    try {
        $destinationStream = [System.IO.File]::Open($DestinationJar, [System.IO.FileMode]::CreateNew)
        try {
            $destinationArchive = New-Object System.IO.Compression.ZipArchive($destinationStream, [System.IO.Compression.ZipArchiveMode]::Create)
            try {
                foreach ($entry in $sourceArchive.Entries) {
                    if ([string]::IsNullOrEmpty($entry.FullName)) {
                        continue
                    }

                    $isNativeEntry = $entry.FullName.StartsWith('lib/')
                    $shouldInclude = if ($ArtifactKind -eq 'native') {
                        $isNativeEntry
                    } else {
                        -not $isNativeEntry
                    }

                    if (-not $shouldInclude -or $entry.FullName.EndsWith('/')) {
                        continue
                    }

                    $destinationEntry = $destinationArchive.CreateEntry($entry.FullName, [System.IO.Compression.CompressionLevel]::NoCompression)
                    $sourceStream = $entry.Open()
                    try {
                        $targetStream = $destinationEntry.Open()
                        try {
                            $sourceStream.CopyTo($targetStream)
                        } finally {
                            $targetStream.Dispose()
                        }
                    } finally {
                        $sourceStream.Dispose()
                    }
                }
            } finally {
                $destinationArchive.Dispose()
            }
        } finally {
            $destinationStream.Dispose()
        }
    } finally {
        $sourceArchive.Dispose()
    }
}

$localPropertiesPath = Join-Path $ProjectRoot 'android\local.properties'
$flutterSdkPath = Get-LocalPropertiesValue -FilePath $localPropertiesPath -Key 'flutter.sdk'
$engineStampPath = Join-Path $flutterSdkPath 'bin\cache\engine.stamp'

if (-not (Test-Path $engineStampPath)) {
    throw "Missing engine.stamp at $engineStampPath"
}

$engineStamp = (Get-Content $engineStampPath -Raw).Trim()
$engineVersion = "1.0.0-$engineStamp"
$offlineRepoRoot = Join-Path $ProjectRoot '.flutter-offline-repo-v2\download.flutter.io\io\flutter'

$embeddingDependencies = @(
    @{ GroupId = 'androidx.annotation'; ArtifactId = 'annotation'; Version = '1.9.1' },
    @{ GroupId = 'androidx.core'; ArtifactId = 'core'; Version = '1.13.1' },
    @{ GroupId = 'androidx.fragment'; ArtifactId = 'fragment'; Version = '1.7.1' },
    @{ GroupId = 'androidx.lifecycle'; ArtifactId = 'lifecycle-common'; Version = '2.7.0' },
    @{ GroupId = 'androidx.lifecycle'; ArtifactId = 'lifecycle-common-java8'; Version = '2.7.0' },
    @{ GroupId = 'androidx.lifecycle'; ArtifactId = 'lifecycle-runtime'; Version = '2.7.0' },
    @{ GroupId = 'androidx.tracing'; ArtifactId = 'tracing'; Version = '1.2.0' },
    @{ GroupId = 'androidx.window'; ArtifactId = 'window-java'; Version = '1.2.0' },
    @{ GroupId = 'com.getkeepsafe.relinker'; ArtifactId = 'relinker'; Version = '1.4.5' }
)

$artifactMappings = @(
    @{ ArtifactId = 'armeabi_v7a_debug'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-arm\flutter.jar'; Kind = 'native' },
    @{ ArtifactId = 'arm64_v8a_debug'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-arm64\flutter.jar'; Kind = 'native' },
    @{ ArtifactId = 'x86_64_debug'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-x64\flutter.jar'; Kind = 'native' },
    @{ ArtifactId = 'armeabi_v7a_profile'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-arm-profile\flutter.jar'; Kind = 'native' },
    @{ ArtifactId = 'arm64_v8a_profile'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-arm64-profile\flutter.jar'; Kind = 'native' },
    @{ ArtifactId = 'x86_64_profile'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-x64-profile\flutter.jar'; Kind = 'native' },
    @{ ArtifactId = 'armeabi_v7a_release'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-arm-release\flutter.jar'; Kind = 'native' },
    @{ ArtifactId = 'arm64_v8a_release'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-arm64-release\flutter.jar'; Kind = 'native' },
    @{ ArtifactId = 'x86_64_release'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-x64-release\flutter.jar'; Kind = 'native' },
    @{ ArtifactId = 'flutter_embedding_debug'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-arm\flutter.jar'; Kind = 'embedding' },
    @{ ArtifactId = 'flutter_embedding_profile'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-arm-profile\flutter.jar'; Kind = 'embedding' },
    @{ ArtifactId = 'flutter_embedding_release'; Source = Join-Path $flutterSdkPath 'bin\cache\artifacts\engine\android-arm-release\flutter.jar'; Kind = 'embedding' }
)

foreach ($mapping in $artifactMappings) {
    if (-not (Test-Path $mapping.Source)) {
        throw "Missing Flutter engine artifact: $($mapping.Source)"
    }

    $artifactDirectory = Join-Path $offlineRepoRoot "$($mapping.ArtifactId)\$engineVersion"
    New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null

    $jarTarget = Join-Path $artifactDirectory "$($mapping.ArtifactId)-$engineVersion.jar"
    $pomTarget = Join-Path $artifactDirectory "$($mapping.ArtifactId)-$engineVersion.pom"

    New-FilteredJarFromFlutterJar -SourceJar $mapping.Source -DestinationJar $jarTarget -ArtifactKind $mapping.Kind
    $pomDependencies = if ($mapping.ArtifactId -like 'flutter_embedding_*') {
        $embeddingDependencies
    } else {
        @()
    }
    Write-MinimalPom -PomPath $pomTarget -ArtifactId $mapping.ArtifactId -Version $engineVersion -Dependencies $pomDependencies
}

Write-Host "Offline Flutter Maven repo prepared at $offlineRepoRoot for engine version $engineVersion"