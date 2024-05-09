
<#
    .SYNOPSIS
        Set the FSCPS configuration details
        
    .DESCRIPTION
        Set the FSCPS configuration details from the configuration store
        
        All settings retrieved from this cmdlets is to be considered the default parameter values across the different cmdlets
        
    .PARAMETER SettingsJsonString
        String contains JSON with custom settings
        
    .PARAMETER SettingsFilePath
        Set path to the settings.json file
        
    .EXAMPLE
        PS C:\> Set-FSCPSSettings -SettingsFilePath "c:\temp\settings.json"
        
        This will output the current FSCPS configuration.
        The object returned will be a Hashtable.
        
    .LINK
        Get-FSCPSSettings
        
    .NOTES
        Tags: Environment, Url, Config, Configuration, Upload, ClientId, Settings
        
        Author: Oleksandr Nikolaiev (@onikolaiev)
        
#>

function Set-FSCPSSettings {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        [string] $SettingsFilePath,
        [string] $SettingsJsonString
    )
    begin{
        if((-not ($SettingsJsonString -eq "")) -and (-not ($SettingsFilePath -eq "")))
        {
            throw "Both settings parameters cannot be provided. Please provide only one of them."
        }

        if(-not ($SettingsJsonString -eq ""))
        {
            $SettingsFilePath = "C:\temp\settings.json"
            $null = Test-PathExists -Path "C:\temp\" -Type Container -Create
            $null = Set-Content $SettingsFilePath $SettingsJsonString -Force -PassThru
        }

        $fscpsFolderName = Get-PSFConfigValue -FullName "fscps.tools.settings.fscpsFolder"
        $fscmSettingsFile = Get-PSFConfigValue -FullName "fscps.tools.settings.fscpsSettingsFile"
        $fscmRepoSettingsFile = Get-PSFConfigValue -FullName "fscps.tools.settings.fscpsRepoSettingsFile"

        $settingsFiles = @()
        $res = [Ordered]@{}

        $reposytoryName = ""
        $reposytoryOwner = ""
        $currentBranchName = ""

        
        if($env:GITHUB_REPOSITORY)# If GitHub context
        {
            Write-PSFMessage -Level Important -Message "Running on GitHub"
            Set-PSFConfig -FullName 'fscps.tools.settings.repoProvider' -Value 'GitHub'
            Set-PSFConfig -FullName 'fscps.tools.settings.repositoryRootPath' -Value "$env:GITHUB_WORKSPACE"            

            Set-PSFConfig -FullName 'fscps.tools.settings.runId' -Value "$ENV:GITHUB_RUN_NUMBER"
            Set-PSFConfig -FullName 'fscps.tools.settings.workflowName' -Value "$ENV:GITHUB_WORKFLOW"

            if($SettingsFilePath -eq "")
            {
                $RepositoryRootPath = "$env:GITHUB_WORKSPACE"
                Write-PSFMessage -Level Verbose -Message "GITHUB_WORKSPACE is: $RepositoryRootPath"
                
                $settingsFiles += (Join-Path $fscpsFolderName $fscmSettingsFile)
            }
            else{
                $settingsFiles += $SettingsFilePath
            }

            $reposytoryOwner = "$env:GITHUB_REPOSITORY".Split("/")[0]
            $reposytoryName = "$env:GITHUB_REPOSITORY".Split("/")[1]
            Write-PSFMessage -Level Verbose -Message "GITHUB_REPOSITORY is: $reposytoryName"
            $branchName = "$env:GITHUB_REF"
            Write-PSFMessage -Level Verbose -Message "GITHUB_REF is: $branchName"
            $currentBranchName = [regex]::Replace($branchName.Replace("refs/heads/","").Replace("/","_"), '(?i)(?:^|-|_)(\p{L})', { $args[0].Groups[1].Value.ToUpper()})      
            $gitHubFolder = ".github"

            $workflowName = "$env:GITHUB_WORKFLOW"
            Write-PSFMessage -Level Verbose -Message "GITHUB_WORKFLOW is: $workflowName"
            $workflowName = ($workflowName.Split([System.IO.Path]::getInvalidFileNameChars()) -join "").Replace("(", "").Replace(")", "").Replace("/", "")

            $settingsFiles += (Join-Path $gitHubFolder $fscmRepoSettingsFile)            
            $settingsFiles += (Join-Path $gitHubFolder "$workflowName.settings.json")
            
        }
        elseif($env:AGENT_ID)# If Azure DevOps context
        {
            Write-PSFMessage -Level Verbose -Message "Running on Azure"
            Set-PSFConfig -FullName 'fscps.tools.settings.repoProvider' -Value 'AzureDevOps'
            Set-PSFConfig -FullName 'fscps.tools.settings.repositoryRootPath' -Value "$env:PIPELINE_WORKSPACE"
            Set-PSFConfig -FullName 'fscps.tools.settings.runId' -Value "$ENV:Build_BuildNumber"
            Set-PSFConfig -FullName 'fscps.tools.settings.workflowName' -Value "$ENV:Build_DefinitionName" 
            if($SettingsFilePath -eq "")
            {
                $RepositoryRootPath = "$env:PIPELINE_WORKSPACE"
                Write-PSFMessage -Level Verbose -Message "RepositoryRootPath is: $RepositoryRootPath"
            }
            else{
                $settingsFiles += $SettingsFilePath
            }
            
            $reposytoryOwner = $($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI.replace('https://dev.azure.com/', '').replace('/', '').replace('https:',''))
            $reposytoryName = "$env:SYSTEM_TEAMPROJECT"
            $branchName = "$env:BUILD_SOURCEBRANCH"
            $currentBranchName = [regex]::Replace($branchName.Replace("/Metadata","").Replace("$/$($reposytoryName)/","").Replace("$/$($reposytoryName)","").Replace("Trunk/","").Replace("/","_"), '(?i)(?:^|-|_)(\p{L})', { $args[0].Groups[1].Value.ToUpper() })   

            #$settingsFiles += (Join-Path $fscpsFolderName $fscmSettingsFile)

        }
        else { # If Desktop or other
            Write-PSFMessage -Level Verbose -Message "Running on desktop"
            Set-PSFConfig -FullName 'fscps.tools.settings.repoProvider' -Value 'Other'
            if($SettingsFilePath -eq "")
            {
                throw "SettingsFilePath variable should be passed if running on the cloud/personal computer"
            }
            $reposytoryName = "windows host"
            $settingsFiles += $SettingsFilePath
        }
        Set-PSFConfig -FullName 'fscps.tools.settings.currentBranch' -Value $currentBranchName
        Set-PSFConfig -FullName 'fscps.tools.settings.repoOwner' -Value $reposytoryOwner
        Set-PSFConfig -FullName 'fscps.tools.settings.repoName' -Value $reposytoryName

        
        function MergeCustomObjectIntoOrderedDictionary {
            Param(
                [System.Collections.Specialized.OrderedDictionary] $dst,
                [PSCustomObject] $src
            )
        
            # Add missing properties in OrderedDictionary

            $src.PSObject.Properties.GetEnumerator() | ForEach-Object {
                $prop = $_.Name
                $srcProp = $src."$prop"
                $srcPropType = $srcProp.GetType().Name
                if (-not $dst.Contains($prop)) {
                    if ($srcPropType -eq "PSCustomObject") {
                        $dst.Add("$prop", [ordered]@{})
                    }
                    elseif ($srcPropType -eq "Object[]") {
                        $dst.Add("$prop", @())
                    }
                    else {
                        $dst.Add("$prop", $srcProp)
                    }
                }
            }
        
            @($dst.Keys) | ForEach-Object {
                $prop = $_
                if ($src.PSObject.Properties.Name -eq $prop) {
                    $dstProp = $dst."$prop"
                    $srcProp = $src."$prop"
                    $dstPropType = $dstProp.GetType().Name
                    $srcPropType = $srcProp.GetType().Name
                    if($dstPropType -eq 'Int32' -and $srcPropType -eq 'Int64')
                    {
                        $dstPropType = 'Int64'
                    }
                    
                    if ($srcPropType -eq "PSCustomObject" -and $dstPropType -eq "OrderedDictionary") {
                        MergeCustomObjectIntoOrderedDictionary -dst $dst."$prop".Value -src $srcProp
                    }
                    elseif ($dstPropType -ne $srcPropType) {
                        throw "property $prop should be of type $dstPropType, is $srcPropType."
                    }
                    else {
                        if ($srcProp -is [Object[]]) {
                            $srcProp | ForEach-Object {
                                $srcElm = $_
                                $srcElmType = $srcElm.GetType().Name
                                if ($srcElmType -eq "PSCustomObject") {
                                    $ht = [ordered]@{}
                                    $srcElm.PSObject.Properties | Sort-Object -Property Name -Culture "iv-iv" | ForEach-Object { $ht[$_.Name] = $_.Value }
                                    $dst."$prop" += @($ht)
                                }
                                else {
                                    $dst."$prop" += $srcElm
                                }
                            }
                        }
                        else {
                            Set-PSFConfig -FullName fscps.tools.settings.$prop -Value $srcProp
                            #$dst."$prop" = $srcProp
                        }
                    }
                }
            }
        }
    }
    process{
        Invoke-TimeSignal -Start    
        #foreach ($config in Get-PSFConfig -FullName "fscps.tools.settings.*") {
        #    $propertyName = $config.FullName.ToString().Replace("fscps.tools.settings.", "")
        #    $res.$propertyName = $config.Value
        #}
        $res = Get-FSCPSSettings -OutputAsHashtable

        $settingsFiles | ForEach-Object {
            $settingsFile = $_
            if($RepositoryRootPath)
            {
                $settingsPath = Join-Path $RepositoryRootPath $settingsFile
            }
            else {
                $settingsPath = $SettingsFilePath
            }
            
            Write-PSFMessage -Level Verbose -Message "Settings file '$settingsFile' - $(If (Test-Path $settingsPath) {"exists. Processing..."} Else {"not exists. Skip."})"
            if (Test-Path $settingsPath) {
                try {
                    $settingsJson = Get-Content $settingsPath -Encoding UTF8 | ConvertFrom-Json
        
                    # check settingsJson.version and do modifications if needed
                    MergeCustomObjectIntoOrderedDictionary -dst $res -src $settingsJson
                }
                catch {
                    Write-PSFMessage -Level Host -Message "Settings file $settingsPath, is wrongly formatted." -Exception $PSItem.Exception
                    Stop-PSFFunction -Message "Stopping because of errors"
                    return
                    throw 
                }
            }
            Write-PSFMessage -Level Verbose -Message "Settings file '$settingsFile' - processed"
        }
        Write-PSFMessage -Level Host  -Message "Settings were updated succesfully."
        Invoke-TimeSignal -End
    }
    end{

    }

}