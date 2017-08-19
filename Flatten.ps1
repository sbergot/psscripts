Function Get-NestedFolder {
    Param([string]$path)
    Get-ChildItem -Path $path -Directory -Recurse | % { $_.FullName }
}

Function Get-FoldersWithFiles {
    Param([string]$path)
    Get-NestedFolder | % {
        $f = Get-ChildItem -Path $_ -File
        if (($f | measure).Count -gt 0) { $_ }
    }
}


Function Get-DirectoryDate {
    Param(
        [string]$path,
        [int]$days=5
    )
    Write-Verbose "Checking date for: $path"
    $files = Get-ChildItem $path -File | Sort-Object { $_.LastWriteTime }
    if (($files | measure).count -lt 2) {
        Write-Debug "directory: $path"
        Write-Debug "Not enough files"
        return
    }
    $firstDate = $files[0].LastWriteTime;
    $date = $firstDate
    :loop
    ForEach ($f in  $files) {
        $newDate = $f.LastWriteTime
        $span = New-TimeSpan -Start $date -End $newDate
        if ($span -gt (New-TimeSpan -Days $days)) {
            Write-Debug "directory: $path"
            Write-Debug "span too big: $($span.Days)"
            Write-Debug $date
            Write-Debug $newDate
            $firstDate = $null
            break loop
        }
        $date = $newDate
    }
    return $firstDate
}

Function Get-FormattedDate([DateTime] $date) {
    Get-Date -Date $date -Format 'yyyy-MM'
}

Function ConvertTo-FlatFolderName {
    Param(
        [string] $baseFolder,
        [string] $path
    )
    $relPath = $path -replace [regex]::Escape($baseFolder),''
    return $relPath.Trim('\') -split '\\' -join ' - '
}

Function Get-FormattedFolderName {
    Param(
        [string] $baseFolder,
        [string] $path
    )
    $date = Get-DirectoryDate $path
    $formattedDate = Get-FormattedDate $date
    $flatName = ConvertTo-FlatFolderName $baseFolder $path
    return "$formattedDate $flatName"
}

Function Move-ToFormattedDirs {
    Param(
        [string] $path
    )
    $alldirs = Get-NestedFolder $path
    $dirs = $alldirs | ? { Get-DirectoryDate $_ }
    $dirs | % {
        $formatted = Get-FormattedFolderName $path $_
        $dest = "$path\$formatted"
        Write-Verbose "src:  $_"
        Write-Verbose "dest: $dest"
        Move-Item $_ $dest -WhatIf
    }
}
