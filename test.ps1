$connection = "Server=(localdb)\MSSQLLocalDB;Database=master;Integrated Security=true;"

function Invoke-Sqlcmd {
    param ( [string]$Query )
    $conn = New-Object System.Data.SQLClient.SQLConnection
    $conn.ConnectionString = $connection
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message };
    $conn.add_InfoMessage($handler); 
    $conn.FireInfoMessageEventOnUserErrors = $true;
    $conn.Open()
    $command = $conn.CreateCommand()
    $command.CommandText = $Query
    $command.ExecuteNonQuery() > $null
    $conn.Close()
}

# Test MSBuild scripts.
& ./msbuild.cmd $PSScriptRoot/test.proj /p:DemoDatbaseName="restored-msbuild"`;BackupFile="$PSScriptRoot/obj/backup-msbuild.bak`;ConnectionString=`"$connection`""
Invoke-Sqlcmd -Query "ALTER DATABASE [restored-msbuild] SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE [restored-msbuild] SET ONLINE; DROP DATABASE [restored-msbuild];"
Invoke-Sqlcmd -Query (Get-Content -path "src/sql.uninstall.sql" -Raw)

# Test powershell
. ./dist/sqlbuild.ps1
SqlBuild-Install -ConnectionString $connection
SqlBuild-BackupDatabase -ConnectionString $connection -Database "master" -BackupPath "$PSScriptRoot/obj/backup-powershell.bak"
SqlBuild-RestoreDatabase -ConnectionString $connection -Database "restored-powershell" -BackupPath "$PSScriptRoot/obj/backup-powershell.bak"
Invoke-Sqlcmd -Query "ALTER DATABASE [restored-powershell] SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE [restored-powershell] SET ONLINE; DROP DATABASE [restored-powershell];"
Invoke-Sqlcmd -Query (Get-Content -path "src/sql.uninstall.sql" -Raw)