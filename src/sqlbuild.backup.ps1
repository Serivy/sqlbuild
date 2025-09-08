# Backup the database.
function SqlBuild-BackupDatabase {
    param ( [string]$ConnectionString, [string]$Database, [string]$BackupPath, [bool]$Compress = $false)
    $conn = New-Object System.Data.SQLClient.SQLConnection
    $conn.ConnectionString = $ConnectionString
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message };
    $conn.add_InfoMessage($handler); 
    $conn.FireInfoMessageEventOnUserErrors = $true;
    $conn.Open()
    $command = $conn.CreateCommand()
    $command.CommandText = "{sqlbuild.backup.sql}"
    $backupParam = New-Object System.Data.SQLClient.SqlParameter "@backup", VarBinary, -1
    $backupParam.Direction = [System.Data.ParameterDirection]::Output
    $nameParam = New-Object System.Data.SQLClient.SqlParameter "@name", $Database
    $command.Parameters.Add($nameParam) > $null
    $command.Parameters.Add($backupParam) > $null
    $compressParam = New-Object System.Data.SQLClient.SqlParameter "@compress", $Compress
    $command.Parameters.Add($compressParam) > $null
    $command.CommandType = [System.Data.CommandType]::Text
    $command.ExecuteNonQuery() > $null
    $conn.Close()
    [System.IO.File]::WriteAllBytes($BackupPath, $backupParam.Value) > $null
}