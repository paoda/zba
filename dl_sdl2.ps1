$SDL2Version = "2.30.0"
$ArchiveFile = ".\SDL2-devel-mingw.zip"
$Json = @"
{
	"x86_64-windows-gnu": {
		"include": ".build_config\\SDL2\\include",
		"libs": ".build_config\\SDL2\\lib",
		"bin": ".build_config\\SDL2\\bin"
	}
}	
"@

New-Item -Force -ItemType Directory -Path .\.build_config
Set-Location -Path .build_config -PassThru

if (!(Test-Path -PathType Leaf $ArchiveFile)) {
	Invoke-WebRequest "https://github.com/libsdl-org/SDL/releases/download/release-$SDL2Version/SDL2-devel-$SDL2Version-mingw.zip" -OutFile $ArchiveFile
}

Expand-Archive $ArchiveFile

if (Test-Path -PathType Leaf .\SDL2) {
	Remove-Item -Recurse .\SDL2
}

New-Item -Force -ItemType Directory -Path .\SDL2 
Get-ChildItem -Path ".\SDL2-devel-mingw\SDL2-$SDL2Version\x86_64-w64-mingw32" | Move-Item -Destination .\SDL2

New-Item -Force .\sdl.json -Value $Json

Remove-Item -Recurse .\SDL2-devel-mingw
Set-Location -Path .. -PassThru
