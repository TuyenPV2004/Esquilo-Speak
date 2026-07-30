[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_.-]+$')]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$outputParent = Split-Path -Parent $OutputPath
if ([string]::IsNullOrWhiteSpace($outputParent)) {
    $outputParent = '.'
}
$resolvedParent = (Resolve-Path -LiteralPath $outputParent).Path
$resolvedOutput = Join-Path $resolvedParent (Split-Path -Leaf $OutputPath)
if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Backup output already exists: $resolvedOutput"
}

$temporaryName = "/tmp/esquilospeak-$([guid]::NewGuid().ToString('N')).dump"
try {
    $databaseUser = (docker exec $ContainerName printenv POSTGRES_USER).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($databaseUser)) {
        throw 'Could not resolve POSTGRES_USER from the container.'
    }
    $databaseName = (docker exec $ContainerName printenv POSTGRES_DB).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($databaseName)) {
        throw 'Could not resolve POSTGRES_DB from the container.'
    }
    docker exec $ContainerName pg_dump `
        "--username=$databaseUser" `
        "--dbname=$databaseName" `
        --format=custom `
        --no-owner `
        --no-privileges `
        "--file=$temporaryName"
    if ($LASTEXITCODE -ne 0) {
        throw 'pg_dump failed.'
    }
    docker cp "${ContainerName}:${temporaryName}" $resolvedOutput
    if ($LASTEXITCODE -ne 0) {
        throw 'docker cp failed.'
    }
    $hash = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash.ToLowerInvariant()
    [pscustomobject]@{
        BackupPath = $resolvedOutput
        Sha256 = $hash
        CreatedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    } | ConvertTo-Json
}
finally {
    docker exec $ContainerName rm -f $temporaryName 2>$null
}
