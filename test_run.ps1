$f = [System.IO.Path]::GetTempFileName() + '.ps1'
Invoke-RestMethod https://raw.githubusercontent.com/BiosSystem/WinSwift/master/WinSwift.ps1 -OutFile $f
& $f
Remove-Item $f -Force -ErrorAction SilentlyContinue
