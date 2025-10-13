$connection = "Server=(localdb)\MSSQLLocalDB;Database=master;Integrated Security=true;"
$dllname = "sqlbuild.bulkinsert"
$dbName = "model"

function Invoke-Sqlcmd {
    param ( [string]$Query, [string]$ConnectionString = $connection )
    $conn = New-Object System.Data.SQLClient.SQLConnection
    $conn.ConnectionString = $ConnectionString
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message };
    $conn.add_InfoMessage($handler); 
    $conn.FireInfoMessageEventOnUserErrors = $true;
    $conn.Open()
    $command = $conn.CreateCommand()
    $command.CommandText = $Query
    $command.ExecuteNonQuery() > $null
    $conn.Close()
}

function Invoke-Count {
    param ( [string]$Query, [string]$ConnectionString = $connection )
    $conn = New-Object System.Data.SQLClient.SQLConnection
    $conn.ConnectionString = $ConnectionString
    $conn.Open()
    $command = $conn.CreateCommand()
    $command.CommandText = $Query
    $res = $command.ExecuteScalar()
    $conn.Close()
    return $res
}


function CheckTable {
    param ( [string]$ConnectionString, [string]$TableName, [int]$ExpectedCount )
    $total = Invoke-Count -ConnectionString $ConnectionString -Query "SELECT COUNT(*) FROM [$TableName]"
    #Write-Host "Total rows in $TableName : $total"

    if ($total -ne $ExpectedCount) {
        Write-Host "Expected $ExpectedCount rows in $TableName, but found $total."
    }
}


# for ($i = 1; $i -le 5; $i++) {
#     $file = "$PSScriptRoot/TestTable.csv"
#     if (Test-Path $file) { Remove-Item $file }
#     1..1000 | ForEach-Object { "$([Guid]::NewGuid()),Name $i - Item $_" } | Out-File -FilePath $file -Encoding utf8
# }

$numberOfTables = 10
$numberOfColumns = 10
$rowsPerTable = 100
#$rowsPerTable = 100000

$csvData = (1..$rowsPerTable) | ForEach-Object { $ro = $_; ((1..$numberOfColumns) | ForEach-Object { "Ro$ro.col$_" }) -join "," }
# | Out-File -FilePath "$PSScriptRoot/TestTable.csv" -Encoding utf8

$databaseName = "bulkinsert"
$storeDB = $connection -replace "master", "$databaseName"
Invoke-Sqlcmd -Query "ALTER DATABASE [$databaseName] SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE [$databaseName] SET ONLINE; DROP DATABASE [$databaseName];"
Invoke-Sqlcmd -Query "CREATE DATABASE [$databaseName];"

Invoke-Sqlcmd -ConnectionString $storeDB -Query "CREATE TABLE [dbo].[bulkinsert] ([Order] int identity(1,1), [Table] nvarchar(150), [Data] nvarchar(max));"

# $rowData = $([System.IO.File]::ReadAllText("$PSScriptRoot/TestTable.csv").Replace("'", "''"))
$rowData = $csvData.Replace("'", "''") -join "`r`n"
for ($i = 1; $i -le $numberOfTables; $i++) {
    Invoke-Sqlcmd -ConnectionString $storeDB -Query "CREATE TABLE [dbo].[TestTable$i] ([Col0] NVARCHAR(100) NOT NULL, [Col1] NVARCHAR(100) NOT NULL, [Col2] NVARCHAR(100) NOT NULL, [Col3] NVARCHAR(100) NOT NULL, [Col4] NVARCHAR(100) NOT NULL, [Col5] NVARCHAR(100) NOT NULL, [Col6] NVARCHAR(100) NOT NULL, [Col7] NVARCHAR(100) NOT NULL, [Col8] NVARCHAR(100) NOT NULL, [Col9] NVARCHAR(100) NOT NULL);"
    Invoke-Sqlcmd -ConnectionString $storeDB -Query "INSERT INTO [dbo].[bulkinsert] ([Table], [Data]) Select 'TestTable$i', '$rowData'"
}
for ($i = 1; $i -le $numberOfTables; $i++) {
    CheckTable -ConnectionString $storeDB -TableName "TestTable$i" -ExpectedCount 0
}
# Write-Host "Bulk inserting data from CSV file..."
# Invoke-Sqlcmd -ConnectionString $storeDB -Query "BULK INSERT [dbo].[TestTable] FROM '$PSScriptRoot/TestTable.csv' WITH (FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', FIRSTROW = 1);"
# Write-Host "Data inserted."
# Invoke-Sqlcmd -ConnectionString $storeDB -Query "DELETE FROM [dbo].[TestTable]"

# $rows = Get-Content -Path "$PSScriptRoot/TestTable.csv"
# $sqlFile = "$PSScriptRoot/TestTable.InsertStatements.sql"
# Remove-Item -Path $sqlFile -ErrorAction SilentlyContinue
# $rows | ForEach-Object {
#     $cols = $_ -split ","
#     "INSERT INTO [dbo].[TestTable] ([Col0], [Col1], [Col2], [Col3], [Col4], [Col5], [Col6], [Col7], [Col8], [Col9]) VALUES (N'$($cols[0])', N'$($cols[1])', N'$($cols[2])', N'$($cols[3])', N'$($cols[4])', N'$($cols[5])', N'$($cols[6])', N'$($cols[7])', N'$($cols[8])', N'$($cols[9])');" `
#      | Out-File -FilePath $sqlFile -Append -Encoding utf8
# }

# Invoke-Sqlcmd -ConnectionString $storeDB -Query "DELETE FROM [dbo].[TestTable]"
# Write-Host "Bulk inserting data insert statements..."
# Invoke-Sqlcmd -ConnectionString $storeDB -Query "SET NOCOUNT ON; $(Get-Content -Raw -Path $sqlFile)"
# Write-Host "Data inserted."

# Test powershell
. ./dist/sqlbuild.bulkinserttable.ps1
$startTime = Get-Date
SqlBuild-BulkInsertTable -ConnectionString $storeDB -With "FIELDTERMINATOR = ',', ROWTERMINATOR = '\n'"
Write-Host "Bulk insert completed in $((Get-Date) - $startTime)"
Invoke-Sqlcmd -ConnectionString $storeDB -Query "DROP TABLE [dbo].[bulkinsert]"

for ($i = 1; $i -le $numberOfTables; $i++) {
    CheckTable -ConnectionString $storeDB -TableName "TestTable$i" -ExpectedCount $rowsPerTable
}

# SqlBuild-RestoreDatabase -ConnectionString $connection -Database "$dbName.restored" -BackupPath "$PSScriptRoot/obj/sqlbackup-powershell.bak"
# SqlBuild-RestoreDatabase -ConnectionString $connection -Database "$dbName.restored.zip" -BackupPath "$PSScriptRoot/obj/sqlbackup-powershell.bak.zip" -Compressed $true
# SqlBuild-RestoreDatabase -ConnectionString $connection -Database "restored-powershell" -BackupPath "$PSScriptRoot/obj/backup-powershell.bak"

# Test csharp
# & ./csc.cmd /t:exe /out:"$PSScriptRoot/obj/$dllname.exe" "dist/$dllname.cs"
# & "$PSScriptRoot/obj/$dllname.exe" "$connection" "$dbName.cs" "$PSScriptRoot/obj/sqlbackup-cs.bak" false
# & "$PSScriptRoot/obj/$dllname.exe" "$connection" "$dbName.cs.zip" "$PSScriptRoot/obj/sqlbackup-cs.bak.zip" true

# DropDatabase -Db "$dbName.restored"
# DropDatabase -Db "$dbName.restored.zip"
# DropDatabase -Db "$dbName.cs"
# DropDatabase -Db "$dbName.cs.zip"