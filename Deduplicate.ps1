class FileHash
{
    [string]$directory
    [string]$filename
    [string]$hash
}

Function New-FileHash([string]$path) {
    $hash = (Get-FileHash $path).Hash
    $directory = Split-Path $path -Resolve
    $filename = Split-Path $path -Leaf -Resolve
    $res = New-Object FileHash
    $res.directory = $directory
    $res.filename = $filename
    $res.hash = $hash
    return $res
}

$HASH_CACHE = @{}
$HASH_CACHE_PATH = Join-Path $HOME '.hash_chache.json'

Function Save-Cache {
    $HASH_CACHE | ConvertTo-Json > $HASH_CACHE_PATH
}

Function Load-Cache {
    $HASH_CACHE = Get-Content $HASH_CACHE_PATH | ConvertFrom-Json
}

Function Get-Cache {
    $HASH_CACHE
}

Function Clean-Cache {
    $keys = $HASH_CACHE.Keys
    $keys | % {
        if (!(Test-Path $_)) {
            $HASH_CACHE.Remove($_)
        }
    }
}

Function Build-HashDirectory([string]$path) {
    $allfiles = Get-ChildItem $path -Recurse -File
    $count = ($allfiles | measure).Count
    $i = 0
    $allfiles | % {
        $filepath = $_.FullName
        if ($HASH_CACHE[$filepath]) {
            $hash = $HASH_CACHE[$filepath]
        } else {
            $hash = New-FileHash $filepath
            $HASH_CACHE[$filepath] = $hash
        }
        $i++
        Write-Progress -Id 2 -Activity "Computing hashes" -Status "Processed $filepath" -PercentComplete (($i * 100) / $count)
        $hash
    }
}

Function Save-HashDirectory([string]$target) {
    $dirpath = (Resolve-Path $target).Path
    $dirname = Split-Path $dirpath -Leaf
    $path = Split-Path $dirpath -Parent
    Build-HashDirectory $dirpath | ConvertTo-Json > (Join-Path $path "$dirname.json")
}

Function Save-HashDirectories([string]$path) {
    $dirs = Get-ChildItem $path -Directory
    $i = 0
    $count = ($dirs | measure).Count
    $dirs | % {
        $dirpath = $_.FullName
        $dirname = Split-Path $dirpath -Leaf
        Write-Progress -Id 1 -Activity "Computing hashes for folders" -Status "Processing $dirname" -PercentComplete (($i * 100) / $count)
        Build-HashDirectory $dirpath | ConvertTo-Json > (Join-Path $path "$dirname.json")
        $i++
    }
}

Function Load-HashDirectory([string]$path) {
    $object = Get-Content $path | ConvertFrom-Json
    $object | % { [FileHash]$_ }
}

Function Test-Included([string]$path1, [string]$path2) {
    $dir1 = Load-HashDirectory $path1
    $dir2 = Load-HashDirectory $path2
    $group = @{}
    $dir1 | % { $group[$_.Hash] = $true }
    $dir2 | ? { !$group[$_.Hash] } | % {
        Write-Warning "file not included: $($_.directory)\$($_.filename)"
    }
}

Function GroupBy-Hash([string] $path) {
    $hashes = Load-HashDirectory $path
    $group = @{}
    $hashes | % {
        if (!$group[$_.hash]) { 
            $group[$_.hash] = @{}
        }
        $group[$_.hash][$_.directory] = $true
    }
    return $group
}

Function Get-DuplicatedDirectories ([string]$path) {
    $d = GroupBy-Hash $path
    $dirs = @{}
    $d.Keys | ? { $d[$_].Keys.Count -gt 1 } | % { $dirs[$d[$_].Keys -join "`n"] = $ture }
    $dirs.Keys | % { '----------------'; $_ }
}