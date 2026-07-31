[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_.-]+$')]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$BackupPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z][a-z0-9_]*_restore_drill$')]
    [string]$TargetDatabase,

    [Parameter(Mandatory = $true)]
    [switch]$ConfirmRestore
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $ConfirmRestore) {
    throw 'Restore drill requires -ConfirmRestore.'
}
$resolvedBackup = (Resolve-Path -LiteralPath $BackupPath).Path
$temporaryName = "/tmp/esquilospeak-$([guid]::NewGuid().ToString('N')).dump"

try {
    docker cp $resolvedBackup "${ContainerName}:${temporaryName}"
    if ($LASTEXITCODE -ne 0) {
        throw 'docker cp failed.'
    }
    $databaseUser = (docker exec $ContainerName printenv POSTGRES_USER).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($databaseUser)) {
        throw 'Could not resolve POSTGRES_USER from the container.'
    }
    docker exec $ContainerName dropdb `
        --if-exists `
        "--username=$databaseUser" `
        $TargetDatabase
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not reset the restore drill database.'
    }
    docker exec $ContainerName createdb `
        "--username=$databaseUser" `
        $TargetDatabase
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not create the restore drill database.'
    }
    docker exec $ContainerName pg_restore `
        "--username=$databaseUser" `
        "--dbname=$TargetDatabase" `
        --no-owner `
        --no-privileges `
        $temporaryName
    if ($LASTEXITCODE -ne 0) {
        throw 'pg_restore failed.'
    }
    $flywayQuery = "select 'flyway=' || coalesce(max(version), 'none') from flyway_schema_history where success"
    docker exec $ContainerName psql `
        "--username=$databaseUser" `
        "--dbname=$TargetDatabase" `
        --tuples-only `
        --no-align `
        "--command=$flywayQuery"
    if ($LASTEXITCODE -ne 0) {
        throw 'Flyway validation query failed.'
    }
    $attemptQuery = "select 'attempts=' || count(*) from attempts"
    docker exec $ContainerName psql `
        "--username=$databaseUser" `
        "--dbname=$TargetDatabase" `
        --tuples-only `
        --no-align `
        "--command=$attemptQuery"
    if ($LASTEXITCODE -ne 0) {
        throw 'Attempt validation query failed.'
    }
}
finally {
    docker exec $ContainerName rm -f $temporaryName 2>$null
}
