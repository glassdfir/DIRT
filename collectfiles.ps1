#1. Timestamps are a great way to make unique folder names with context.
$timestamp = (get-date).ToString('yyyy-MM-dd-h-m-s')

#2. Array of Files to Collect
$filestocollect = @()

#3. NTFS Files
$filestocollect += 'c:\$MFT'
$filestocollect += 'c:\$LogFile'
$filestocollect += 'c:\$Extend\$USNJrnl:$J'

#4. Array for Regex Signatures for Files of Interest
$filesigs = @()
#Application Experience Service
$filesigs += '^c:\\Windows\\AppCompat\\Programs\\Amcache.hve$'
$filesigs += '^C:\\Windows\\AppCompat\\Programs\\RecentFilecache.bcf$'

#Jump Lists
$filesigs += '^c:\\Users\\.*\\AppData\\Roaming\\Microsoft\\Windows\\Recent\\AutomaticDestinations\\.*$'

#Shortcuts for Recently Used Files
$filesigs += '^c:\\Users\\.*\\AppData\\Roaming\\Microsoft\\(Windows|Office)\\Recent\\.*\.lnk$'

#USB first and last times used
$filesigs += '^C:\\Windows\\inf\\setupapi.dev.log$'

#Prefetch Files
$filesigs += '^c:\\Windows\\Prefetch\\.*\.pf$'

#User Registry Files
$filesigs += '^c:\\Users\\.*\\ntuser.dat$'
$filesigs += '^c:\\Users\\.*\\usrclass.dat$'

#System Registry Files
$filesigs += '^c:\\Windows\\System32\\config\\.*'

#Event Logs
$filesigs += '^c:\\Windows\\System32\\winevt\\Logs\\.*.evtx$'

#Browser Artifacts
$filesigs += '^c:\\Users\\.*\\AppData\\.*\\Microsoft\\Windows\\WebCache\\.*'
$filesigs += '^c:\\Users\\.*\\%\AppData\\.*\\Mozilla\\Firefox\\Profiles\\.*.default\\.*'
$filesigs += '^c:\\Users\\.*\\AppData\\.*\\Google\\Chrome\\User\ Data\\Default\\.*'

#System Resource Utilization Manager
$filesigs += '^c:\\Windows\\system32\\sru\\SRUDB.dat'


$filestocollect += gci -Path C:\Users,C:\Windows -Recurse -Force -File -ErrorAction SilentlyContinue | 
                     Where-Object { $_.FullName -imatch $($filesigs -join "|") }| % { $_.FullName }

#5. Collect Files of Interest
foreach($file in $filestocollect){
    #6. Bastardized Multiprocessing. Counts the number of fcats running and sleep if it is more than 10.
    while(@(Get-Process fcat -ErrorAction SilentlyContinue).Count -ge 10){Start-Sleep -Seconds 5}

    #7. Manipulating the path to get what we need
    $unixname = $file -replace "c:","" -replace "\\","/"
    $outfile = $('{0}\\{1}' -f $timestamp,$file -replace ':','')
    $outdir  = $outfile.Substring(0,$outfile.LastIndexOf("\"))
    
    #8. Building the command string
    $cmdstr = ""
    $cmdstr += "/c mkdir $('{0}{1}{0}' -f [char]34, $outdir) & "
    $cmdstr += "$('{0}\\{1}' -f $pwd,"fcat.exe") -h -f ntfs $('{0}{1}{0}' -f [char]34, $unixname) \\.\c:  > "
    $cmdstr += "$('{0}{1}{0}' -f [char]34, $outfile) "
    
    #Run
    Start-Process cmd.exe -ArgumentList $cmdstr -WindowStyle Hidden
    Start-Sleep -Seconds 1

}

#9. Wait until all of the fcats are done
while(@(Get-Process fcat  -ErrorAction SilentlyContinue).Count){
    write-host "Collectors are still running..."
    Start-Sleep -Seconds 30
}
write-host "Zipping..."
#10. Zip it real good.
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($('{0}\\{1}' -f $pwd,$timestamp), $('{0}\\{1}.zip' -f $pwd,$timestamp))
write-host "Done"