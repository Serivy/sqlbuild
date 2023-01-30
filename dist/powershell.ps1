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
    $command.CommandText = "print DB_NAME()
print @@version
print CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion'))

declare @asmVersion bigint = 1000000;
declare @hash varbinary(64) = CONVERT(varbinary(64), '63313E4013C9B621F3693BFDF65E6FC92F53784FAABE847940CA36E026CC03FBA4E4D6C37872A2A4DDEFE02794B298EE36C8DF1EFB4314F358F076C35C0C2BDC', 2);

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

    create assembly sqlbuild authorization [dbo] from 0x4D5A90000300000004000000FFFF0000B800000000000000400000000000000000000000000000000000000000000000000000000000000000000000800000000E1FBA0E00B409CD21B8014CCD21546869732070726F6772616D2063616E6E6F742062652072756E20696E20444F53206D6F64652E0D0D0A2400000000000000504500004C01030038CFD7630000000000000000E00022200B013000001A000000060000000000009E3900000020000000400000000000100020000000020000040000000000000004000000000000000080000000020000539D00000300408500001000001000000000100000100000000000001000000000000000000000004C3900004F00000000400000A802000000000000000000000000000000000000006000000C00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000080000000000000000000000082000004800000000000000000000002E74657874000000A419000000200000001A000000020000000000000000000000000000200000602E72737263000000A80200000040000000040000001C0000000000000000000000000000400000402E72656C6F6300000C000000006000000002000000200000000000000000000000000000400000420000000000000000000000000000000080390000000000004800000002000500542200007816000009000000000000000000000000000000CC3800008000000000000000000000000000000000000000000000000000000000000000000000001E02280800000A2A3A02280800000A02037D010000042A6202280900000A2C07280A00000A10000203280B00000A022A1B30030098000000010000117201000070730C00000A0A72310000700B280A00000A0C0803280B00000A066F0D00000A0D09076F0E00000A096F0F00000A72980C00701F0C8C160000016F1000000A026F1100000A096F0F00000A72A40C00701F0C8C160000016F1000000A086F1100000A066F1200000A096F1300000A26066F1400000ADE0A092C06096F1500000ADC08281600000ADE0A062C06066F1500000ADC2A011C000002002500567B000A0000000002000B00828D000A000000001B300400CA000000020000117201000070730C00000A0A280A00000A0B1B8D11000001251672AE0C0070A2251702A2251872D20C0070A2251907A2251A72EE0C0070A2281700000A0C066F0D00000A0D09086F0E00000A066F1200000A096F1300000A26066F1400000A0307281800000A5107281600000A042C44731900000A1304110417731A00000A1305110503501603508E696F1B00000ADE0C11052C0711056F1500000ADC0311046F1C00000A51DE2211042C0711046F1500000ADCDE14092C06096F1500000ADC062C06066F1500000ADC2A000001340000020080001090000C000000000200760031A7000C000000000200440071B5000A0000000002000B00B4BF000A000000001E02281D00000A2A42534A4201000100000000000C00000076342E302E33303331390000000005006C00000024030000237E000090030000EC03000023537472696E6773000000007C070000080D0000235553008414000010000000234755494400000094140000E401000023426C6F620000000000000002000001571D02000900000000FA013300160000010000001C000000040000000200000006000000080000001D000000030000000C0000000200000001000000030000000000DB0101000000000006007501E50206009501E50206001E01D2020F00050300000600EB00E5020600A901030206007703030206000601030206008F0303020A004801B1020E001403A4000A003201B1020A00550296030A005E0096030600F6010A000E00E8011B020600CA0103020600D1010A0006008A000A000A00460063020A00310296030A00B40014000A00A40296030A00980263020A00480263020600790003020600FC010A000E0069001B02000000000100000000000100010000011000D9003E03190001000100000110005D01E5021900010002000100100055033400250002000300260013025D0151800F0260015020000000008618CC02060001005820000000008618CC02010001006720000000009600850063010100802000000000960076026A01030040210000000096008402720106004C22000000008618CC020600090000000100D60100000200C403000001009F00000002009102101003002900000001009F00020002009102101003006E030900CC0201001100CC0206001900CC020A002900CC0206004100CC0210005100CC0206006100CC0206003100CC0206008900DB03160091008F001B00990030031F006900CC022F00690050003400A100AC032F0071005F033900A900BD013E00C100B3014500C9000A020600A100CB034A00C900BE000600D100C40006009900CC004E008900880360009900230366007900CC0206008100CC026C00D900D30074007900BC037C004900CC0206000E0008002C01020015005B01020021005B0127001200D8012E000B007B012E00130084012E001B00A30143002300AC0143000A00AC0160003300AC0163002300AC0163000A00AC0163002B00B10180003B00AC01A0003B00AC0126005300048000000100000000000000010000008A003D00000004000000000000000000000081002000000000000400000000000000000000008100140000000000040000000000000000000000810003020000000000000000003C4D6F64756C653E0053797374656D2E494F0053797374656D2E44617461006D73636F726C696200636F6D707265737365640053514C4275696C640073716C6275696C64004462436F6D6D616E6400437265617465436F6D6D616E640053716C436F6D6D616E6400436F6D7072657373696F6E4D6F64650049446973706F7361626C6500577269746546696C650047657454656D7046696C654E616D65006E616D650053797374656D2E4E65742E4D696D650053716C44625479706500436C6F736500446973706F73650044656C65746500577269746500456D62656464656441747472696275746500436F6D70696C657247656E6572617465644174747269627574650041747472696275746555736167654174747269627574650044656275676761626C654174747269627574650053716C50726F6365647572654174747269627574650053716C46756E6374696F6E4174747269627574650052656653616665747952756C657341747472696275746500436F6D70696C6174696F6E52656C61786174696F6E734174747269627574650052756E74696D65436F6D7061746962696C697479417474726962757465007365745F56616C7565004164645769746856616C756500537472696E67005061746800706174680073716C6275696C642E646C6C004465666C61746553747265616D004D656D6F727953747265616D0053797374656D004F70656E00636F6E0056657273696F6E0053797374656D2E494F2E436F6D7072657373696F6E0053716C506172616D65746572436F6C6C656374696F6E004462436F6E6E656374696F6E0053716C436F6E6E656374696F6E0053797374656D2E446174612E436F6D6D6F6E00526573746F72654261636B7570004372656174654261636B7570006261636B7570004462506172616D657465720053716C506172616D65746572004D6963726F736F66742E53716C5365727665722E536572766572002E63746F720053797374656D2E446961676E6F73746963730053797374656D2E52756E74696D652E436F6D70696C6572536572766963657300446562756767696E674D6F646573004D65646961547970654E616D65730052656164416C6C4279746573005772697465416C6C4279746573004D6963726F736F66742E436F6465416E616C797369730046756E6374696F6E73006765745F506172616D657465727300636F6D7072657373004174747269627574655461726765747300436F6E636174004F626A6563740053797374656D2E446174612E53716C436C69656E74007365745F436F6D6D616E645465787400546F41727261790062696E61727900457865637574654E6F6E51756572790049734E756C6C4F72456D70747900000000002F63006F006E007400650078007400200063006F006E006E0065006300740069006F006E003D007400720075006500008C650D000A006400650063006C0061007200650020004000640061007400610020006E00760061007200630068006100720028006D006100780029002C00200040006C006F00670020006E00760061007200630068006100720028006D006100780029002C00200040006C006F006700460069006C00650020006E00760061007200630068006100720028006D006100780029002C00200040006400610074006100460069006C00650020006E00760061007200630068006100720028006D006100780029002C002000400072006500730074006F007200650020006E00760061007200630068006100720028006D006100780029003B0020000D000A00730065006C0065006300740020004000640061007400610020003D00200063006100730074002800730065007200760065007200700072006F00700065007200740079002800270049006E007300740061006E0063006500440065006600610075006C007400440061007400610050006100740068002700290020006100730020006E00760061007200630068006100720028006D0061007800290029002C00200040006C006F00670020003D00200063006100730074002800730065007200760065007200700072006F00700065007200740079002800270049006E007300740061006E0063006500440065006600610075006C0074004C006F00670050006100740068002700290020006100730020006E00760061007200630068006100720028006D0061007800290029000D000A006400650063006C0061007200650020004000660069006C006500730020007400610062006C00650028004C006F0067006900630061006C004E0061006D00650020004E0056004100520043004800410052002800310032003800290020004E004F00540020004E0055004C004C002C00200050006800790073006900630061006C004E0061006D00650020004E0056004100520043004800410052002800320036003000290020004E004F00540020004E0055004C004C002C0054007900700065002000430048004100520028003100290020004E004F00540020004E0055004C004C002C00460069006C006500470072006F00750070004E0061006D00650020004E0056004100520043004800410052002800310032003000290020004E0055004C004C002C00530069007A00650020004E0055004D0045005200490043002800320030002C0020003000290020004E004F00540020004E0055004C004C002C004D0061007800530069007A00650020004E0055004D0045005200490043002800320030002C0020003000290020004E004F00540020004E0055004C004C002C00460069006C00650049006400200042004900470049004E00540020004E0055004C004C002C004300720065006100740065004C0053004E0020004E0055004D0045005200490043002800320035002C0020003000290020004E0055004C004C002C00440072006F0070004C0053004E0020004E0055004D0045005200490043002800320035002C0020003000290020004E0055004C004C002C0055006E00690071007500650049004400200055004E0049005100550045004900440045004E0054004900460049004500520020004E0055004C004C002C0052006500610064004F006E006C0079004C0053004E0020004E0055004D0045005200490043002800320035002C0020003000290020004E0055004C004C002C005200650061006400570072006900740065004C0053004E0020004E0055004D0045005200490043002800320035002C0020003000290020004E0055004C004C002C004200610063006B0075007000530069007A00650049006E0042007900740065007300200042004900470049004E00540020004E0055004C004C002C0053006F00750072006300650042006C006F0063006B00530069007A006500200049004E00540020004E0055004C004C002C00460069006C006500470072006F007500700049006400200049004E00540020004E0055004C004C002C004C006F006700470072006F00750070004700550049004400200055004E0049005100550045004900440045004E0054004900460049004500520020004E0055004C004C002C0044006900660066006500720065006E007400690061006C0042006100730065004C0053004E0020004E0055004D0045005200490043002800320035002C0020003000290020004E0055004C004C002C0044006900660066006500720065006E007400690061006C0042006100730065004700550049004400200055004E0049005100550045004900440045004E0054004900460049004500520020004E0055004C004C002C004900730052006500610064004F006E006C007900200042004900540020004E0055004C004C002C0049007300500072006500730065006E007400200042004900540020004E0055004C004C002C005400440045005400680075006D0062007000720069006E0074002000560041005200420049004E00410052005900280033003200290020004E0055004C004C002C00200053006E0061007000730068006F007400550052004C0020004E0056004100520043004800410052002800330036003000290029000D000A0069006E007300650072007400200069006E0074006F0020004000660069006C00650073000D000A00650078006500630020002800270052004500530054004F00520045002000460049004C0045004C004900530054004F004E004C0059002000460052004F004D0020004400490053004B0020003D0020002700270027002B004000620061006B002B00270027002700270029000D000A006500780065006300200028002700690066002000640062005F006900640028002700270027002B00200040006E0061006D00650020002B00270027002700290020006900730020006E006F00740020006E0075006C006C00200062006500670069006E00200041004C0054004500520020004400410054004100420041005300450020005B0027002B00200040006E0061006D00650020002B0027005D0020005300450054002000530049004E0047004C0045005F00550053004500520020005700490054004800200052004F004C004C004200410043004B00200049004D004D004500440049004100540045003B002000440052004F00500020004400410054004100420041005300450020005B0027002B00200040006E0061006D00650020002B0027005D003B00200065006E0064003B00270029000D000A00730065006C00650063007400200040006400610074006100460069006C00650020003D0020002800730065006C00650063007400200074006F0070002000310020004C006F0067006900630061006C004E0061006D0065002000660072006F006D0020004000660069006C00650073002000570068006500720065002000540079007000650020003D00200027004400270029002C00200040006C006F006700460069006C00650020003D0020002800730065006C00650063007400200074006F0070002000310020004C006F0067006900630061006C004E0061006D0065002000660072006F006D0020004000660069006C00650073002000570068006500720065002000540079007000650020003D00200027004C00270029002C002000400072006500730074006F007200650020003D002000270052004500530054004F005200450020004400410054004100420041005300450020005B0027002B0040006E0061006D0065002B0027005D002000460052004F004D0020004400490053004B0020003D0020002700270027002B004000620061006B002B00270027002700200057004900540048002000460049004C00450020003D00200031002C0020004D004F0056004500200027002700270020002B00200040006400610074006100460069006C00650020002B002000270027002700200054004F00200027002700270020002B0020004000640061007400610020002B00200040006E0061006D00650020002B00200027005F0044006100740061002E006D0064006600270027002C004D004F005600450020002700270027002B00200040006C006F006700460069006C00650020002B00270027002700200054004F0020002700270027002B00200040006C006F00670020002B00200040006E0061006D00650020002B00200027005F004C006F0067002E006D0064006600270027002C00200020004E004F0055004E004C004F00410044002C0020005200450050004C004100430045002C0020005300540041005400530020003D002000350027000D000A0065007800650063002800400072006500730074006F00720065002900010B40006E0061006D00650000094000620061006B0000234200410043004B005500500020004400410054004100420041005300450020005B00001B5D00200054004F0020004400490053004B0020003D00200027000117270020005700490054004800200049004E0049005400010000D00F1283D07C3F42BF6BCB3E775504EF0004200101080320000105200101111105200101111D040001020E0300000E060002010E1D0508070412350E0E1239042001010E04200012390420001255062002125D0E1C042001011C03200008040001010E0C070612350E0E1239123D12410500010E1D0E0500011D050E07200201126D1171072003011D0508080420001D0508B77A5C561934E08980A00024000004800000940000000602000000240000525341310004000001000100316E84F44C89E54377E52FB4DE9F74FCE2BDBB32E46AA296A42AF7D7E78E856012694C0E044E0E5F3A81E6663AD0A7EC79EA60DC21ABF0D0C0839E5D42E94E9D024181D32A8B50B855000A98FF90669A1224E40F4F1727D72345D23CD3B0241546B2E21C057061C0A1B5D1AE24CA628F82B65F4E7352EA0DF81F5BF327243AC32E63006F006E007400650078007400200063006F006E006E0065006300740069006F006E003D007400720075006500010002060802060E0600020E0E1D05070003010E1D0502080003010E101D05020801000800000000001E01000100540216577261704E6F6E457863657074696F6E5468726F777301080100020000000000040100000026010002000000020054020D416C6C6F774D756C7469706C6500540209496E68657269746564000801000B00000000000000009135EAD08BB929AC29F154FDFD328EC2352F25568EA09589699405D23B9E7DBC7F615A6F3034DB615591A97DB949BAE207E931495A34C7476C4ABCB2E4E7EF0EA721611658559930490181E1A19CE04C8722EC9E24A5102CD7C1752855ADAFB7DD1DF22866418C1849BE5E004B490CBB57D21EE905485E5C01D56420C6530A927439000000000000000000008E39000000200000000000000000000000000000000000000000000080390000000000000000000000005F436F72446C6C4D61696E006D73636F7265652E646C6C0000000000FF25002000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001001000000018000080000000000000000000000000000001000100000030000080000000000000000000000000000001000000000048000000584000004C02000000000000000000004C0234000000560053005F00560045005200530049004F004E005F0049004E0046004F0000000000BD04EFFE00000100000001000000000000000100000000003F000000000000000400000002000000000000000000000000000000440000000100560061007200460069006C00650049006E0066006F00000000002400040000005400720061006E0073006C006100740069006F006E00000000000000B004AC010000010053007400720069006E006700460069006C00650049006E0066006F0000008801000001003000300030003000300034006200300000002C0002000100460069006C0065004400650073006300720069007000740069006F006E000000000020000000300008000100460069006C006500560065007200730069006F006E000000000031002E0030002E0030002E00300000003A000D00010049006E007400650072006E0061006C004E0061006D0065000000730071006C006200750069006C0064002E0064006C006C00000000002800020001004C006500670061006C0043006F00700079007200690067006800740000002000000042000D0001004F0072006900670069006E0061006C00460069006C0065006E0061006D0065000000730071006C006200750069006C0064002E0064006C006C0000000000340008000100500072006F006400750063007400560065007200730069006F006E00000031002E0030002E0030002E003000000038000800010041007300730065006D0062006C0079002000560065007200730069006F006E00000031002E0030002E0030002E0030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000C000000A03900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    with permission_set = unsafe;

    declare @dynsql nvarchar(max);
    set @dynsql = 'create function WriteFile (@path nvarchar(150), @bin varbinary(max)) returns nvarchar(max) AS external name sqlbuild.[SQLBuild.Functions].WriteFile'
    execute sp_executesql @dynsql

    set @dynsql = 'create procedure RestoreBackup(@name nvarchar(max), @backup varbinary(max), @compressed bit = 0) as external name sqlbuild.[SQLBuild.Functions].RestoreBackup'
    execute sp_executesql @dynsql

    set @dynsql = 'create procedure CreateBackup (@name nvarchar(max), @backup varbinary(max) output, @compress bit = 0) as external name sqlbuild.[SQLBuild.Functions].[CreateBackup]'
    execute sp_executesql @dynsql
end"
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
