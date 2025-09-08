function Compile-SqlBuild {
    param ( [string]$variant )
        
    $dllname = "sqlbuild.$variant"
    $manifest = Get-Content -Raw -Path manifest.json | ConvertFrom-Json
    $v = $manifest.version
    $asmVer = New-Object -TypeName System.Version -ArgumentList $v
    $verInt = $(($asmVer.Major * 1000000) + ($asmVer.Minor * 10000)  + ($asmVer.Build * 100)  + ($asmVer.Revision))

    $code = (Get-Content -path "src/$dllname.cs" -Raw)
    $code = $code -replace ([regex]::Escape('[assembly: AssemblyVersion("')+'([^"]*)'+[regex]::Escape('")]')),  "[assembly: AssemblyVersion(`"$v`")]"
    $code | Set-Content -NoNewline -Path "src/$dllname.cs"

    # Compile the file into a dll, needs to be as small as possible.
    New-Item -Path obj -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    & ./csc.cmd /t:library /out:"$PSScriptRoot/obj/$dllname.dll" "src/$dllname.cs" /optimize /keyfile:src/key.snk

    $hash = (Get-FileHash .\obj\$dllname.dll -Algorithm SHA512).Hash
    $bytes = [System.IO.File]::ReadAllBytes("$([System.Environment]::CurrentDirectory)/obj/$dllname.dll"); 
    $hexString = [System.BitConverter]::ToString($bytes) -replace '-'
    $hexString | Out-File "obj/$dllname.hex"
    $hash | Out-File "obj/$dllname.hash"

    $sqlCode = (Get-Content -path "src/sql.$variant.sql" -Raw)
    $sqlCode = $sqlCode -replace ([regex]::Escape('{sql.versionnumber}')), $verInt
    $sqlCode = $sqlCode -replace ([regex]::Escape('{sql.asm}')), $hexString
    $sqlCode = $sqlCode -replace ([regex]::Escape('{sql.hash}')), $hash

    # Compile the sql script.
    # $sqlCode | Set-Content -Path "dist/$dllname.sql"

    # Compile the powershell script.
    $code = (Get-Content -path "src/$dllname.ps1" -Raw)
    $code = $code -replace ([regex]::Escape("{$dllname.sql}")), $sqlCode
    $code | Set-Content -Path "dist/$dllname.ps1"
    
    # Compile the csharp.
    $code = (Get-Content -path "src/$dllname.example.cs" -Raw)
    $code = $code -replace ([regex]::Escape("{$dllname.sql}")), $sqlCode
    $code | Set-Content -Path "dist/$dllname.cs"
}