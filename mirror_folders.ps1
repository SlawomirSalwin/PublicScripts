# Created by Sławomir Salwin
# Version 1.0
# Creation date: 24/10/2022

[CmdletBinding()]
param(
        [Parameter(Mandatory=$true, ValueFromPipeline =$true)]
        [string] $PathSource,
        [Parameter(Mandatory=$true,ValueFromPipeline =$true)]
        [string] $PathDestination,
        [Parameter(Mandatory=$true,ValueFromPipeline =$true)]
        [string] $PathLog
            )

##############################################################################
#GLOBAL VARIABLES#
##############################################################################
[string]$logEntry

#TESTING
#$PathSource = "C:\Temp\Temp\faktury"
#$PathDestination = "C:\Temp\Temp\Fakturydest"
#$PathLog = "C:\Temp\Temp\logfile.log"
##############################################################################
#FUNCTIONS#
##############################################################################

function new-logfileentry([string]$message){
    
    "$((Get-Date).ToString()) : $message " | Out-File $PathLog -Append default

}

function console-error([string]$message){

Write-Host $message -BackgroundColor Red -ForegroundColor Yellow
}

function console-warning([string]$message){

Write-Host $message -BackgroundColor yellow -ForegroundColor Black
}

function console-success([string]$message){

Write-Host $message -BackgroundColor Green -ForegroundColor White
}

#function to look for and create missing PATHs and log entry about doing so
function Add-PathsToCreate([string]$path){
    if((Test-Path $path) -or ($path -eq $PathDestination)){
        if($FoldersToCreate){
            $FoldersToCreate = $FoldersToCreate | Sort-Object
            foreach($folder in $FoldersToCreate){
                $Error.Clear()
                New-Item -Path $folder -ItemType Directory -Force
                if(!$?){
                new-logfileentry $Error
                console-error $Error 
                }else{
                $logEntry = "New folder in destionation path: $folder"
                new-logfileentry $logEntry
                console-success $logEntry
                }
            }
        }
        [System.Collections.ArrayList]$FoldersToCreate=@()
      
    }else{
        $FoldersToCreate+=$path
        Add-PathsToCreate -path ([string](Split-Path $path))
        
    }
}

function remove_empty_folders([string]$Path){
    foreach ($childDirectory in Get-ChildItem -Force -LiteralPath $Path -Directory) {
        & remove_empty_folders -Path $childDirectory.FullName
    }
    $currentChildren = Get-ChildItem -Force -LiteralPath $Path
    $isEmpty = $currentChildren -eq $null
    if ($isEmpty) {
        $error.Clear()
        Remove-Item -Force -LiteralPath $Path
        if(!$?){
            new-logfileentry $error
            console-error $error
        }else{
            $logEntry = "Empty folder was removed at destination: $Path"
            new-logfileentry $logEntry
            console-success $logEntry
        }
    }
}




##############################################################################
[System.Collections.ArrayList]$FoldersToCreate=@()
$logpath = Split-Path $PathLog

#write to console errror if path to logfile is incorrect
if(!(Test-Path $logpath)){
    $logEntry = "ERROR!!! Path to logfile is incorrect. Please specify correct path, terminating script!" | 
    console-error $logEntry
    exit 1
}
#write to console errror if we cannot initialize log
if(Test-Path $PathLog){
    $logEntry = "ERROR!!! Provided filename in PathLog already exist, please change filename or remove old file. Terminating script!"
    console-error $logEntry
    exit 1
}

#checking if source and source paths are ok

if(!(Test-Path $PathSource)){
    $logEntry = "ERROR!!! Source path is not correct please specify new one! Terminating script!"    
    new-logfileentry $logEntry
    console-error $logEntry
    exit 1
}
#checking if destination and source paths are ok

if(!(Test-Path $PathDestination)){
    $logEntry = "ERROR!!! Destination path is not correct please specify new one! Terminating script!"    
    new-logfileentry $logEntry
    console-error $logEntry
    exit 1
}



#initializing log if destination and source folder and logfile are ok

new-logfileentry ("Synchronization of folder $PathSource, to folder $PathDestination" )

[System.Collections.ArrayList]$FilesSource = Get-ChildItem -Recurse -Path $PathSource -File
[System.Collections.ArrayList]$FilesDestination = Get-ChildItem -Recurse -Path $PathDestination -File

#main work part
foreach($filesource in $FilesSource){ 
    $destinationfilepath = ($filesource.Fullname -replace [regex]::Escape($PathSource),$PathDestination) #making destination filepath 
    if(!(Test-Path (split-path $destinationfilepath))) { #checking if parent folder exist
        Add-PathsToCreate -path ([string](split-path $destinationfilepath)) #creating all necesary partent folders if needed
    }
    if(!(Test-Path -LiteralPath $destinationfilepath)){
            $error.Clear()
            cp $filesource.FullName $destinationfilepath -Force #copy file to dest if it not exist
            if(!$?){
                new-logfileentry $Error
                console-error $error
            }else{
            $logEntry="New file created at: $destinationfilepath"
            new-logfileentry $logEntry
            console-success $logEntry
            }
    }else{
    if((Get-Item -Path $destinationfilepath).LastWriteTimeUtc -lt (Get-Item $filesource.FullName).LastWriteTimeUtc){ #copy only newly edited files
         $error.Clear()
         cp $filesource.FullName $destinationfilepath -Force
         if(!$?){
            new-logfileentry $Error
            console-error $error  
         }else{
            $logEntry="File overriden at: $destinationfilepath"
            new-logfileentry $logEntry
            console-success $logEntry
            
         }
        }
        $FilesDestination.RemoveAt(($FilesDestination.FullName.IndexOf((get-item -LiteralPath $destinationfilepath).FullName))) #remove copied file from destination files list
    }
}
IF($FilesDestination){ #removing all remaining destination files that are not in source
    foreach($file in $FilesDestination){
        $error.Clear()
        rm -LiteralPath $file.FullName -Force
        if(Test-Path $file.fullname){
            $logEntry="File $($file.FullName) cannot be removed please check permissions or if file is opened in any program for any user"
            new-logfileentry $logEntry
            console-error $logEntry
        }else{
            $logEntry="File $($file.FullName) Removed from destinantio with success"
            new-logfileentry $logEntry
            console-success $logEntry
        }
    }
    
}

#removing all unnecesary empty folders from destination

remove_empty_folders $PathDestination

new-logfileentry "FINISHED WORK!!!"
