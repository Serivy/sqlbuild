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