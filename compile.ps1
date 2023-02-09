$dllname = "sqlbuild"
$manifest = Get-Content -Raw -Path manifest.json | ConvertFrom-Json
$v = $manifest.version
$asmVer = New-Object -TypeName System.Version -ArgumentList $v
$verInt = $(($asmVer.Major * 1000000) + ($asmVer.Minor * 10000)  + ($asmVer.Build * 100)  + ($asmVer.Revision))

$code = (Get-Content -path "src/sqlbuild.cs" -Raw)
$code = $code -replace ([regex]::Escape('[assembly: AssemblyVersion("')+'([^"]*)'+[regex]::Escape('")]')),  "[assembly: AssemblyVersion(`"$v`")]"
$code | Set-Content -NoNewline -Path "src/sqlbuild.cs"

# Compile the file into a dll, needs to be as small as possible.
& ./csc.cmd /t:library /out:"$PSScriptRoot/obj/$dllname.dll" "src/$dllname.cs" /optimize /keyfile:src/key.snk

$hash = (Get-FileHash .\obj\$dllname.dll -Algorithm SHA512).Hash
$bytes = [System.IO.File]::ReadAllBytes("$([System.Environment]::CurrentDirectory)/obj/$dllname.dll"); 
$hexString = [System.BitConverter]::ToString($bytes) -replace '-'
$hexString | Out-File "obj/$dllname.hex"
$hash | Out-File "obj/$dllname.hash"

$sqlInstall = (Get-Content -path "src/sql.install.sql" -Raw)
$sqlInstall = $sqlInstall -replace ([regex]::Escape('{sql.versionnumber}')), $verInt
$sqlInstall = $sqlInstall -replace ([regex]::Escape('{sql.asm}')), $hexString
$sqlInstall = $sqlInstall -replace ([regex]::Escape('{sql.hash}')), $hash

# Compile the msbuild script.
$code = (Get-Content -path "src/sqlbuild.targets" -Raw)
$code = $code -replace ([regex]::Escape('{sql.install.sql}')), $sqlInstall
$code = $code -replace ([regex]::Escape('{sql.uninstall.sql}')), (Get-Content -path "src/sql.uninstall.sql" -Raw)
$code | Set-Content -Path "dist/sqlbuild.targets"

# Compile the powershell script.
$code = (Get-Content -path "src/sqlbuild.ps1" -Raw)
$code = $code -replace ([regex]::Escape('{sql.install.sql}')), $sqlInstall
$code | Set-Content -Path "dist/sqlbuild.ps1"