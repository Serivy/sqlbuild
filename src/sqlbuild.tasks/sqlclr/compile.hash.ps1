$ErrorActionPreference = 'Stop'

$ro   = $PSScriptRoot                                       # ...\sqlbuild\sqlclr
$repo = (Resolve-Path "$ro\..\..").Path                     # ...\dev\sqlbuild  (repo root)
$obj  = [System.IO.Path]::GetFullPath("$ro\..\obj")         # ...\sqlbuild\obj

function CreateHash {
    param ($dllname, $cls)

    if (!$dllname) {
        throw "dllname parameter is required"
        return
    }

    $targetasmcs = "$ro\$dllname.asm.cs"
    if ((Test-Path -Path "$targetasmcs")) {
        Write-Host "Skipping hash generation, source file $targetasmcs already exists"
        return
    }

    New-Item -ItemType Directory -Force -Path $obj | Out-Null
    Remove-Item -Path "$obj\$dllname.asm.cs" -ErrorAction Ignore

    $manifest = Get-Content -Raw -Path "$repo\manifest.json" | ConvertFrom-Json
    $v = $manifest.version
    $asmVer = [System.Version]$v
    $verInt = ($asmVer.Major * 1000000) + ($asmVer.Minor * 10000) + ($asmVer.Build * 100) + $asmVer.Revision

    $code = Get-Content -Path "$ro\$dllname.cs" -Raw
    $code = $code -replace ([regex]::Escape('[assembly: AssemblyVersion("')+'([^"]*)'+[regex]::Escape('")]')),  "[assembly: AssemblyVersion(`"$v`")]"
    $code | Set-Content -NoNewline -Path "$ro\$dllname.cs"

    # Compile the file into a dll, needs to be as small as possible.
    & "$repo\csc.cmd" /t:library /out:"$obj\$dllname.dll" "$ro\$dllname.cs" /optimize /keyfile:"$repo\src\key.snk"
    if ($LASTEXITCODE -ne 0) { throw "csc.exe failed with exit code $LASTEXITCODE" }

    $hash = (Get-FileHash "$obj\$dllname.dll" -Algorithm SHA512).Hash
    $bytes = [System.IO.File]::ReadAllBytes("$obj\$dllname.dll")
    $hexString = [System.BitConverter]::ToString($bytes) -replace '-'
    Write-Host "Build - Hash: $hash"

    $ns = $dllname.Replace('.', '')
    # Output to obj/sqlbuild.asm.cs for use in the msbuild script.
    "namespace sqlbuild {
        public static class ${cls} {
            public const string Hex = `"$hexString`";
            public const string Hash = `"$hash`";
        }
    }" | Set-Content -NoNewline -Path "$ro\$dllname.asm.cs"
    
}

CreateHash "sqlbuild" "SqlBuildAsm"
CreateHash "sqlbuild.backup" "SqlBuildBackupAsm"