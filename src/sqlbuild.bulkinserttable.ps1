# Bulk insert data into a table.
# -- Before running the script, create the table and insert data.
#CREATE TABLE [dbo].[bulkinsert] (Table nvarchar(150), Data nvarchar(max))
#INSERT INTO [dbo].[bulkinsert] (Table, Data) VALUES (N'Test1', N'1,2,3')
# -- Then clean up the table
#DROP TABLE [dbo].[bulkinsert]

function SqlBuild-BulkInsertTable {
    param ( [string]$ConnectionString, [string]$With = $null)
    $conn = New-Object System.Data.SQLClient.SQLConnection
    $conn.ConnectionString = $ConnectionString
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message };
    $conn.add_InfoMessage($handler); 
    $conn.FireInfoMessageEventOnUserErrors = $true;
    $conn.Open()
    $command = $conn.CreateCommand()
    $command.CommandText = "{sqlbuild.bulkinserttable.sql}"
    $withParam = New-Object System.Data.SQLClient.SqlParameter "@withopt", $With
    $command.Parameters.Add($withParam) > $null
    $command.CommandType = [System.Data.CommandType]::Text
    $command.ExecuteNonQuery() > $null
    $conn.Close()
}