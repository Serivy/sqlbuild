function SqlBuild-RestoreDatabase {
    param ( [string]$ConnectionString, [string]$Database, [string]$BackupPath, [bool]$Compressed = $false)
    $backupBytes = [System.IO.File]::ReadAllBytes($BackupPath)
    $conn = New-Object System.Data.SQLClient.SQLConnection
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message };
    $conn.add_InfoMessage($handler); 
    $conn.FireInfoMessageEventOnUserErrors = $true;
    $conn.ConnectionString = $ConnectionString
    $conn.Open()
    $command = $conn.CreateCommand()
    $command.CommandText = "{sqlbuild.restore.sql}"
    $command.Parameters.Add($(New-Object System.Data.SQLClient.SqlParameter "@backup", $backupBytes)) > $null    
    $command.Parameters.Add($(New-Object System.Data.SQLClient.SqlParameter "@name", $Database)) > $null
    $command.Parameters.Add($(New-Object System.Data.SQLClient.SqlParameter "@compressed", $Compressed)) > $null
    $command.ExecuteNonQuery() > $null
    $conn.Close()
}