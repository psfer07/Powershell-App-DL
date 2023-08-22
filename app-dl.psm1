function Write-Title {
  param ([string]$t, [switch]$warn)
  if ($warn) { $bColor = "Red" } else { $bColor = "Blue" }
  if ($t.Length % 2 -ne 0, 1) { [string]$extra = 'o' }
  $b = "o" * (4 + $t.Length)
  Write-Host "`n`nooo$b$extra" -ForegroundColor $bColor
  Write-Host "oo$extra " -NoNewline -ForegroundColor $bColor
  Write-Host "$t" -NoNewline -ForegroundColor White
  Write-Host " oo$extra" -ForegroundColor $bColor
  Write-Host "ooo$b$extra" -ForegroundColor $bColor
}
function Write-Subtitle {
  param ([string]$t, [int]$pad = 40)
  if ($t.Length % 2 -ne 0) { [string]$extra = 'o' }
  $b = "o" * (($pad - $t.Length - 3) / 2)
  Write-Host "`n<$b " -NoNewline -ForegroundColor Blue
  Write-Host "$t" -NoNewline -ForegroundColor White
  Write-Host " $b$extra>" -ForegroundColor Blue
}
function Write-Point {
  param([string]$t, [switch]$NoNewLine = $false)
  if ($NoNewLine) {
    Write-Host '==> ' -NoNewline -ForegroundColor Magenta
    Write-Host "$t" -NoNewline -ForegroundColor White
  }
  else {
    Write-Host '==> ' -NoNewline -ForegroundColor Magenta
    Write-Host "$t" -ForegroundColor White
  }
}
function Get-AppSize($size) {
  $suffixes = "B", "kB", "MB", "GB"
  for ($i = 0; $i -lt $suffixes.Length; $i++) {
    if ($size -lt 1024) { return [string]::Format("{0:0.00} {1}", $size, $suffixes[$i]) }
    $size /= 1024
  }
  return [string]::Format("{0:0.00} {1}", $size, $suffixes[-1])
}
function Revoke-Path {
  Write-Title -warn "It seems that $app is currently allocated in this path"
  do {
    Write-Host
    Write-Point -NoNewLine
    $reset = Read-Host 'You can (r)estart, (o)pen, or (e)xit the app' 
  } while ($reset -ne 'r' -and $reset -ne 'o' -and $reset -ne 'e')
  switch ($reset) {
    'r' { Start-Main }
    'o' { Open-App $p $o $app $folder $exe $cmd $cmd_syn $portapps }
    'e' { Write-Title 'Closing this terminal...'; Start-Sleep -Milliseconds 500; exit }
  }
}
function Open-App {
  param (
    [Parameter(Position = 0)]
    [string]$p,

    [Parameter(Position = 1)]
    [string]$o,

    [Parameter(Position = 2)]
    [string]$app,

    [Parameter(Position = 3)]
    [string]$folder,

    [Parameter(Position = 4)]
    [string]$exe,

    [Parameter(Position = 5)]
    [string]$cmd,

    [Parameter(Position = 6)]
    [string]$cmd_syn,

    [Parameter(Position = 7)]
    [string]$portapps
  )
  function Open-Extracted {
    if ($cmd) {
      Write-Point "There is a preset for running $app $($cmd_syn). Launch it with presets?" 
      do {
        Write-Host
        Write-Point -NoNewLine
        $runcmd = Read-Host 'y/n' 
      } while ($runcmd -ne 'y' -and $runcmd -ne 'n')
      if ($runcmd -eq 'n') {
        Write-Title "Running $app..."
        Start-Process -FilePath "$p\$app\$folder\$exe" -ErrorAction SilentlyContinue
      }
      else {    
        Write-Title "Running $app $($cmd_syn)"
        Start-Process -FilePath "$p\$app\$folder\$exe" -ArgumentList $($cmd) -ErrorAction SilentlyContinue
      }
    }
    else {
      Write-Title "Running $app..."
      Start-Process -FilePath "$p\$app\$folder\$exe" -ErrorAction SilentlyContinue
    }
  }
  switch -Wildcard ($o) {
    "*.zip" {
      Write-Title 'Zip file detected'
      if (Test-Path -Path "$p\$app\$folder") {
        Write-Title "$app is Available in $path, so opening..."
        Open-Extracted
      }
      # Expand and open the app
      elseif (Test-Path -LiteralPath "$p\$o") {
        Write-Point "$app is saved as a zip file, so uncompressing..."
        Expand-Archive -Literalpath "$p\$o" -DestinationPath "$p\$app" -Force
        if ($?) { Write-Title 'Package successfully extracted...' }
        else {
          Write-Warning "Failed to extract package. Error: $($_.Exception.Message)"
          Read-Host "Press any key to continue..."
        }
        Write-Subtitle "Launching $app..."
        Open-Extracted
       
      }
    }
    "*.7z" {
      $7z_libs = '7z.exe', '7z.dll'
      foreach ($7z_lib in $7z_libs) { $wc.DownloadFile("https://raw.githubusercontent.com/psfer07/App-DL/$branch/7z/$7z_lib", "$Env:TEMP\$7z_lib") }
      $wc.Dispose()
      $7z = "$assets\7z.exe" <# '.\7z\7z.exe' #>
      if ($portapps) { $exe = "$app".ToLower() + '.exe' }
      Write-Title '7z file detected'
      if (Test-Path -Path "$p\$app\$folder") {
        Write-Title "$app is available in $path, so opening..."
        Open-Extracted
      }
      elseif (Test-Path -Path "$p\$o") {
        Write-Point "$app is saved as a 7z file, so uncompressing..."
        Start-Process $7z -ArgumentList "x `"$p\$o`" -o`"$p\$app`"" -Wait -NoNewWindow
        if ($?) { Write-Title 'Package successfully extracted...' }
        else {
          Write-Warning "Failed to extract package. Error: $($_.Exception.Message)"
          Read-Host 'Press any key to continue...'
        }
        Clear-Host
        Open-Extracted
      }
    }
    "*.exe" {
      Write-Title 'Exe file detected'
      Open-Extracted
    }
    "*.msi" {
      Write-Title 'Microsoft installer detected'
      Write-Title "Installing $app automatically"
      Write-Point 'Do you want to launch it after installation?'
      do {
        Write-Host
        Write-Point -NoNewLine
        $openInst = Read-Host '--> (y/n)' 
      } while ($openInst -ne 'y' -and $openInst -ne 'n')
      Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$p\$o`" /passive /promptrestart" -Wait
      Write-Title "$app successfully installed"
      if ($openInst -eq 'y') {
        Write-Title "Launching $app..."
        function Show-Progress {
          param (
            [int]$Current,
            [int]$Total
          )
          $PercentComplete = ($Current / $Total) * 100
          Write-Progress -Activity "Processing actions" -Status "Action $Current of $Total" -PercentComplete $PercentComplete
        }
        $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
        Show-Progress -Current 1 -Total 6
        $database = $windowsInstaller.GetType().InvokeMember("OpenDatabase", 'InvokeMethod', $Null, $windowsInstaller, @("$p\$o", 0))
        Show-Progress -Current 2 -Total 6
        $view = $database.GetType().InvokeMember("OpenView", 'InvokeMethod', $Null, $database, ("SELECT Value FROM Property WHERE Property='ProductName'"))
        Show-Progress -Current 3 -Total 6
        $view.GetType().InvokeMember("Execute", 'InvokeMethod', $Null, $view, $Null)
        Show-Progress -Current 4 -Total 6
        $record = $view.GetType().InvokeMember("Fetch", 'InvokeMethod', $Null, $view, $Null)
        Show-Progress -Current 5 -Total 6
        $prod = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq ($record.GetType().InvokeMember("StringData", 'GetProperty', $Null, $record, 1)) }
        Show-Progress -Current 6 -Total 6
        Start-Process -FilePath "$($prod.InstallLocation)\$folder\$exe"
      }
    }
    default {
      Write-Title 'Bundle Microsoft app detected'
      Add-AppPackage -Path "$p\$o" -ForceApplicationShutdown -Confirm:$false
    }
  }
}