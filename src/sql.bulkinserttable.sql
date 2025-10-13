if ((select value_in_use from sys.configurations where name = 'clr enabled') = 0)
begin
    Exec sp_configure 'show advanced options', 1; RECONFIGURE; exec sp_configure 'clr enabled', 1; RECONFIGURE; EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
end

declare @hash varbinary(64) = CONVERT(varbinary(64), '{sql.hash}', 2);
exec sp_add_trusted_assembly @hash, N'sqlbuildbulkinserttable, version=0.0.0.0, culture=neutral, publickeytoken=null, processorarchitecture=msil';
create assembly [sqlbuild.bulkinserttable] authorization [dbo] from 0x{sql.asm}
with permission_set = unsafe;
execute sp_executesql N'create procedure BulkInsertTable(@withopt nvarchar(2000)) as external name [sqlbuild.bulkinserttable].[SQLBuild.Functions].BulkInsertTable'
exec BulkInsertTable @withopt

BEGIN TRY exec sp_drop_trusted_assembly @hash END TRY BEGIN CATCH END CATCH
BEGIN TRY drop procedure BulkInsertTable END TRY BEGIN CATCH END CATCH
BEGIN TRY drop assembly [sqlbuild.bulkinserttable] END TRY BEGIN CATCH END CATCH