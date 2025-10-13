$connection = "Server=(localdb)\MSSQLLocalDB;Database=master;Integrated Security=true;"
$dllname = "sqlbuild.backup"
$dbName = "model"

# Test powershell
. ./dist/sqlbuild.backup.ps1
New-Item -Path obj -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
SqlBuild-BackupDatabase -ConnectionString $connection -Database "$dbName" -BackupPath "$PSScriptRoot/obj/sqlbackup-powershell.bak"
SqlBuild-BackupDatabase -ConnectionString $connection -Database "$dbName" -BackupPath "$PSScriptRoot/obj/sqlbackup-powershell.bak.zip" -Compress $true
# SqlBuild-RestoreDatabase -ConnectionString $connection -Database "restored-powershell" -BackupPath "$PSScriptRoot/obj/backup-powershell.bak"
# Invoke-Sqlcmd -Query "ALTER DATABASE [restored-powershell] SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE [restored-powershell] SET ONLINE; DROP DATABASE [restored-powershell];"
# Invoke-Sqlcmd -Query (Get-Content -path "src/sql.uninstall.sql" -Raw)

# Test csharp
& ./csc.cmd /t:exe /out:"$PSScriptRoot/obj/$dllname.exe" "dist/$dllname.cs"
& "$PSScriptRoot/obj/$dllname.exe" "$connection" $dbName "$PSScriptRoot/obj/sqlbackup-cs.bak" false
& "$PSScriptRoot/obj/$dllname.exe" "$connection" $dbName "$PSScriptRoot/obj/sqlbackup-cs.bak.zip" true