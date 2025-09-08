if ((select value_in_use from sys.configurations where name = 'clr enabled') = 0)
begin
    Exec sp_configure 'show advanced options', 1; RECONFIGURE; exec sp_configure 'clr enabled', 1; RECONFIGURE; EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
end

declare @hash varbinary(64) = CONVERT(varbinary(64), '{sql.hash}', 2);
BEGIN TRY
    exec sp_add_trusted_assembly @hash, N'sqlbuildbackup, version=0.0.0.0, culture=neutral, publickeytoken=null, processorarchitecture=msil''sqlbuildbackup, version=0.0.0.0, culture=neutral, publickeytoken=null, processorarchitecture=msil';
    create assembly sqlbuildbackup authorization [dbo] from 0x{sql.asm}
    with permission_set = unsafe;
    execute sp_executesql N'create procedure CreateBackup(@name nvarchar(max), @backup varbinary(max) output, @compressed bit = 0) as external name sqlbuildbackup.[SQLBuild.Functions].CreateBackup'
    exec CreateBackup @name, @backup output, @compress
END TRY
BEGIN CATCH print ERROR_MESSAGE() END CATCH

BEGIN TRY exec sp_drop_trusted_assembly @hash END TRY BEGIN CATCH END CATCH
BEGIN TRY drop procedure dbo.CreateBackup END TRY BEGIN CATCH END CATCH
BEGIN TRY drop assembly sqlbuildbackup END TRY BEGIN CATCH END CATCH
