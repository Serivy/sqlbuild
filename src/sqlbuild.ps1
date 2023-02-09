# Install the sqlbuild scripts on the target database.
function SqlBuild-Install {
    param ( [string]$ConnectionString )
    $conn = New-Object System.Data.SQLClient.SQLConnection
    $conn.ConnectionString = $ConnectionString
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message };
    $conn.add_InfoMessage($handler); 
    $conn.FireInfoMessageEventOnUserErrors = $true;
    $conn.Open()
    $command = $conn.CreateCommand()
    $command.CommandText = "{sql.install.sql}"
    $command.ExecuteNonQuery() > $null
    $conn.Close()
}

# Backup the database.
function SqlBuild-BackupDatabase {
    param ( [string]$ConnectionString, [string]$Database, [string]$BackupPath )
    $conn = New-Object System.Data.SQLClient.SQLConnection
    $conn.ConnectionString = $ConnectionString
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message };
    $conn.add_InfoMessage($handler); 
    $conn.FireInfoMessageEventOnUserErrors = $true;
    $conn.Open()
    $command = $conn.CreateCommand()
    $command.CommandText = "master.dbo.CreateBackup"
    $backupParam = New-Object System.Data.SQLClient.SqlParameter "@backup", VarBinary, -1
    $backupParam.Direction = [System.Data.ParameterDirection]::Output
    $nameParam = New-Object System.Data.SQLClient.SqlParameter "@name", $Database
    $command.Parameters.Add($nameParam) > $null
    $command.Parameters.Add($backupParam) > $null
    $command.CommandType = [System.Data.CommandType]::StoredProcedure
    $command.ExecuteNonQuery() > $null
    $conn.Close()
    [System.IO.File]::WriteAllBytes($BackupPath, $backupParam.Value) > $null
}

# Restore the database.
function SqlBuild-RestoreDatabase {
    param ( [string]$ConnectionString, [string]$Database, [string]$BackupPath )
    $backupBytes = [System.IO.File]::ReadAllBytes($BackupPath)
    $conn = New-Object System.Data.SQLClient.SQLConnection
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message };
    $conn.add_InfoMessage($handler); 
    $conn.FireInfoMessageEventOnUserErrors = $true;
    $conn.ConnectionString = $ConnectionString
    $conn.Open()
    $command = $conn.CreateCommand()
    $command.CommandText = "exec dbo.RestoreBackup @name = '$Database', @backup = @data"
    $dataParam = New-Object System.Data.SQLClient.SqlParameter "@data", $backupBytes
    $command.Parameters.Add($dataParam) > $null
    $command.ExecuteNonQuery() > $null
    $conn.Close()
}