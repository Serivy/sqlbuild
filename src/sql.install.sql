print DB_NAME()
print @@version
print CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion'))

declare @asmVersion bigint = {sql.versionnumber};
declare @hash varbinary(64) = CONVERT(varbinary(64), '{sql.hash}', 2);

declare @vstring nvarchar(max);
select top 1 @vstring = [clr_name] from sys.assemblies where [clr_name] like 'sqlbuild%'
declare @vstringnumber bigint = 
    SUBSTRING(PARSENAME(@vstring, 4), CHARINDEX ('=' , PARSENAME(@vstring, 4))+1, 1000) * 1000000
    + PARSENAME(@vstring, 3) * 10000
    + PARSENAME(@vstring, 2) * 100
    + SUBSTRING (PARSENAME(@vstring, 1), 0, CHARINDEX (',', PARSENAME(@vstring, 1)))

if @vstringnumber is null or @vstringnumber < @asmVersion
begin
    print convert(nvarchar(4000), @vstringnumber) + ' < ' + convert(nvarchar(4000), @asmVersion)
    print 'Uninstalling old version'
    -- Clean up old assembly
    if OBJECT_ID(N'master.sys.trusted_assemblies') is not null begin 
        DECLARE @trustsql nvarchar(max)
        set @trustsql = 'declare @hashdrop varbinary(64) = (select top 1 hash from sys.trusted_assemblies where description like ''sqlbuild%'') if (@hashdrop is not null) begin exec sp_drop_trusted_assembly @hashdrop end'; execute sp_executesql @trustsql
    end else begin 
        alter database master set trustworthy on
    end

    DECLARE @objname NVARCHAR(50), @objtype NVARCHAR(50), @dropsql nvarchar(max)
    DECLARE db_cursor CURSOR FOR
    select o.[name], o.[type] from sys.objects as o inner join sys.assembly_modules as am on o.object_id = am.object_id inner join sys.assemblies as a on a.assembly_id = am.assembly_id where a.name = 'sqlbuild'
    OPEN db_cursor
    FETCH NEXT FROM db_cursor INTO @objname, @objtype
    WHILE @@FETCH_STATUS = 0
    BEGIN
        if (@objtype = 'FS') begin set @dropsql = 'drop function [' + @objname + ']'; execute sp_executesql @dropsql end
        if (@objtype = 'PC') begin set @dropsql = 'drop procedure [' + @objname + ']'; execute sp_executesql @dropsql end
        FETCH NEXT FROM db_cursor INTO @objname, @objtype
    END
    CLOSE db_cursor
    DEALLOCATE db_cursor
    if exists (select top 1 1 from sys.assemblies as a where a.name = 'sqlbuild') begin drop assembly sqlbuild end

    print 'Installing new version'
    Exec sp_configure 'show advanced options', 1; RECONFIGURE; exec sp_configure 'clr enabled', 1; RECONFIGURE; EXEC sp_configure 'show advanced options', 0; RECONFIGURE;

    if OBJECT_ID(N'master.sys.trusted_assemblies') is not null begin 
        DECLARE @trustedsql nvarchar(max) = 'exec sp_add_trusted_assembly '+CONVERT(nvarchar(max), @hash, 1)+', N''sqlbuild, version=0.0.0.0, culture=neutral, publickeytoken=null, processorarchitecture=msil'';'
        execute sp_executesql @trustedsql
    end

    create assembly sqlbuild authorization [dbo] from 0x{sql.asm}
    with permission_set = unsafe;

    declare @dynsql nvarchar(max);
    set @dynsql = 'create function WriteFile (@path nvarchar(150), @bin varbinary(max)) returns nvarchar(max) AS external name sqlbuild.[SQLBuild.Functions].WriteFile'
    execute sp_executesql @dynsql

    set @dynsql = 'create procedure RestoreBackup(@name nvarchar(max), @backup varbinary(max), @compressed bit = 0) as external name sqlbuild.[SQLBuild.Functions].RestoreBackup'
    execute sp_executesql @dynsql

    set @dynsql = 'create procedure CreateBackup (@name nvarchar(max), @backup varbinary(max) output, @compress bit = 0) as external name sqlbuild.[SQLBuild.Functions].[CreateBackup]'
    execute sp_executesql @dynsql
end