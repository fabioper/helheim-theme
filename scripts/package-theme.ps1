param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = Split-Path -Parent $PSScriptRoot
$resources = Join-Path $projectRoot 'resources'
$output = Join-Path $projectRoot 'dist'

# Validate the source files before packaging.
$descriptor = [System.Xml.XmlDocument]::new()
$descriptor.PreserveWhitespace = $true
$descriptor.Load((Join-Path $resources 'META-INF/plugin.xml'))
$descriptor.SelectSingleNode('/idea-plugin/version').InnerText = $Version
$themePath = $descriptor.SelectSingleNode('/idea-plugin/extensions/themeProvider').GetAttribute('path').TrimStart('/')
$theme = Get-Content -LiteralPath (Join-Path $resources $themePath) -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($theme.editorScheme)) {
    throw 'The theme must reference an editorScheme resource.'
}
$schemePath = Join-Path $resources $theme.editorScheme.TrimStart('/')
if (-not (Test-Path -LiteralPath $schemePath -PathType Leaf)) {
    throw "Editor scheme resource not found: $($theme.editorScheme)"
}
$scheme = [System.Xml.XmlDocument]::new()
$scheme.Load($schemePath)
if ($scheme.DocumentElement.LocalName -ne 'scheme') {
    throw 'The editor scheme XML must have a scheme root element.'
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$jarPath = Join-Path $output "helheim-$Version.jar"
$zipPath = Join-Path $output "helheim-$Version.zip"

# A resource-only JetBrains plugin is a JAR (ZIP) with META-INF/plugin.xml.
$jarStream = [System.IO.File]::Create($jarPath)
$jar = [System.IO.Compression.ZipArchive]::new($jarStream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $resources -Recurse -File) {
        $entryName = $file.FullName.Substring($resources.Length + 1).Replace('\', '/')
        if ($entryName -eq 'META-INF/plugin.xml') {
            $entry = $jar.CreateEntry($entryName)
            $entryStream = $entry.Open()
            try { $descriptor.Save($entryStream) } finally { $entryStream.Dispose() }
        }
        else {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($jar, $file.FullName, $entryName) | Out-Null
        }
    }
}
finally {
    $jar.Dispose()
    $jarStream.Dispose()
}

# Plugin distributions contain a plugin directory with a lib directory.
$zipStream = [System.IO.File]::Create($zipPath)
$zip = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $jarPath, "helheim/lib/helheim-$Version.jar") | Out-Null
}
finally {
    $zip.Dispose()
    $zipStream.Dispose()
}

Write-Output "Created $jarPath"
Write-Output "Created $zipPath"
