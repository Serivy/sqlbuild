$connection = "Server=(localdb)\MSSQLLocalDB;Database=master;Integrated Security=true;"
$dllname = "sqlbuild.restore"
$dbName = "model"

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
function DropDatabase {
    param ( [string]$Db )
    Invoke-Sqlcmd -Query "ALTER DATABASE [$Db] SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE [$Db] SET ONLINE; DROP DATABASE [$Db];"
}


# Test powershell
. ./dist/sqlbuild.restore.ps1
SqlBuild-RestoreDatabase -ConnectionString $connection -Database "$dbName.restored" -BackupPath "$PSScriptRoot/obj/sqlbackup-powershell.bak"
SqlBuild-RestoreDatabase -ConnectionString $connection -Database "$dbName.restored.zip" -BackupPath "$PSScriptRoot/obj/sqlbackup-powershell.bak.zip" -Compressed $true
# SqlBuild-RestoreDatabase -ConnectionString $connection -Database "restored-powershell" -BackupPath "$PSScriptRoot/obj/backup-powershell.bak"


# Test csharp
& ./csc.cmd /t:exe /out:"$PSScriptRoot/obj/$dllname.exe" "dist/$dllname.cs"
& "$PSScriptRoot/obj/$dllname.exe" "$connection" "$dbName.cs" "$PSScriptRoot/obj/sqlbackup-cs.bak" false
& "$PSScriptRoot/obj/$dllname.exe" "$connection" "$dbName.cs.zip" "$PSScriptRoot/obj/sqlbackup-cs.bak.zip" true

DropDatabase -Db "$dbName.restored"
DropDatabase -Db "$dbName.restored.zip"
DropDatabase -Db "$dbName.cs"
DropDatabase -Db "$dbName.cs.zip"