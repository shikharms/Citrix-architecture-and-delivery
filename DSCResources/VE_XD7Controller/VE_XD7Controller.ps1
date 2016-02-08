Import-LocalizedData -BindingVariable localizedData -FileName Resources.psd1;

function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()]
        [System.String] $SiteName,
        
        ## Existing controller used to join/remove the site.
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()]
        [System.String] $ExistingControllerName, 
        
        ## Database credentials used to join/remove the controller to/from the site.
        [Parameter()] [AllowNull()]
        [System.Management.Automation.PSCredential] $Credential, 
        
        [Parameter()] [ValidateSet('Present','Absent')]
        [System.String] $Ensure = 'Present'
    )
    begin {
        if (-not (TestXDModule)) {
            ThrowInvalidProgramException -ErrorId 'Citrix.XenDesktop.Admin' -ErrorMessage $localizedData.XenDesktopSDKNotFoundError;
        }
    } #end begin
    process {
        $scriptBlock = {
            Import-Module "$env:ProgramFiles\Citrix\XenDesktopPoshSdk\Module\Citrix.XenDesktop.Admin.V1\Citrix.XenDesktop.Admin\Citrix.XenDesktop.Admin.psd1" -Verbose:$false;

            $xdSite = Get-XDSite -AdminAddress $using:ExistingControllerName -ErrorAction Stop;
            $targetResource = @{
                SiteName = $xdSite.Name;
                ExistingControllerName = $using:ExistingControllerName;
                Credential = $using:Credential;
                Ensure = 'Absent';
            }
            if (($xdSite.Name -eq $using:SiteName) -and ($xdSite.Controllers.DnsName -contains $using:localHostName)) {
                $targetResource['Ensure'] = 'Present';
            }
            return $targetResource;
        } #end scriptBlock
        
        $localHostName = GetHostName;
        $invokeCommandParams = @{
            ScriptBlock = $scriptBlock;
            ErrorAction = 'Stop';
        }
        if ($Credential) { AddInvokeScriptBlockCredentials -Hashtable $invokeCommandParams -Credential $Credential; }
        else { $invokeCommandParams['ScriptBlock'] = [System.Management.Automation.ScriptBlock]::Create($scriptBlock.ToString().Replace('$using:','$')); }
        ## Overwrite the local ComputerName returned by AddInvokeScriptBlockCredentials
        $invokeCommandParams['ComputerName'] = $ExistingControllerName;
        Write-Verbose ($localizedData.InvokingScriptBlockWithParams -f [System.String]::Join("','", @($ExistingControllerName)));
        return Invoke-Command @invokeCommandParams;
    } #end process
} #end function Get-TargetResource

function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()]
        [System.String] $SiteName,
        
        ## Existing controller used to join/remove the site.
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()]
        [System.String] $ExistingControllerName, 
        
        ## Database credentials used to join/remove the controller to/from the site.
        [Parameter()] [AllowNull()]
        [System.Management.Automation.PSCredential] $Credential, 
        
        [Parameter()] [ValidateSet('Present','Absent')]
        [System.String] $Ensure = 'Present'
    )
    process {
        $xdSite = Get-TargetResource @PSBoundParameters;
        $localHostName = GetHostName;
        if ($xdSite.SiteName -eq $SiteName -and $xdSite.Ensure -eq $Ensure) {
            Write-Verbose ($localizedData.ControllerDoesExist -f $localHostName, $SiteName);
            Write-Verbose ($localizedData.ResourceInDesiredState -f $localHostName);
            return $true;
        }
        else {
            Write-Verbose ($localizedData.ControllerDoesNotExist -f $localHostName, $SiteName);
            Write-Verbose ($localizedData.ResourceNotInDesiredState -f $localHostName);
            return $false;
        }
    } #end process
} #end function Test-TargetResource

function Set-TargetResource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()]
        [System.String] $SiteName,
        
        ## Existing controller used to join/remove the site.
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()]
        [System.String] $ExistingControllerName, 
        
        ## Database credentials used to join/remove the controller to/from the site.
        [Parameter()] [AllowNull()]
        [System.Management.Automation.PSCredential] $Credential, 
        
        [Parameter()] [ValidateSet('Present','Absent')]
        [System.String] $Ensure = 'Present'
    )
    begin {
        if (-not (TestXDModule)) {
            ThrowInvalidProgramException -ErrorId 'Citrix.XenDesktop.Admin module not found.' -ErrorMessage $localizedData.XenDesktopSDKNotFoundError;
        }
    } #end begin
    process {
        $scriptBlock = {
            Import-Module "$env:ProgramFiles\Citrix\XenDesktopPoshSdk\Module\Citrix.XenDesktop.Admin.V1\Citrix.XenDesktop.Admin\Citrix.XenDesktop.Admin.psd1" -Verbose:$false;
            Remove-Variable -Name CitrxHLSSdkContext -Force -ErrorAction SilentlyContinue;
            
            if ($using:Ensure -eq 'Present') {
                $addXDControllerParams = @{
                    AdminAddress = $using:localHostName;
                    SiteControllerAddress = $using:ExistingControllerName;
                }
                Write-Verbose ($using:localizedData.AddingXDController -f $using:localHostName, $using:SiteName);
                [ref] $null = Add-XDController @addXDControllerParams -ErrorAction Stop;
            }
            else {
                $removeXDControllerParams = @{
                    ControllerName = $using:ExistingControllerName;
                }
                Write-Verbose ($using:localizedData.RemovingXDController -f $using:localHostName, $using:SiteName);
                Remove-XDController @removeXDControllerParams -ErrorAction Stop;
            }
        } #end scriptBlock
        
        $localHostName = GetHostName;
        $invokeCommandParams = @{
            ScriptBlock = $scriptBlock;
            ErrorAction = 'Stop';
        }
        if ($Credential) { AddInvokeScriptBlockCredentials -Hashtable $invokeCommandParams -Credential $Credential; }
        else { $invokeCommandParams['ScriptBlock'] = [System.Management.Automation.ScriptBlock]::Create($scriptBlock.ToString().Replace('$using:','$')); }
        ## Override the local computer name returned by AddInvokeScriptBlockCredentials with
        ## the existing XenDesktop controller address
        $invokeCommandParams['ComputerName'] = $ExistingControllerName;
        Write-Verbose ($localizedData.InvokingScriptBlockWithParams -f [System.String]::Join("','", @($ExistingControllerName, $localHostName, $Ensure, $Credential)));
        Invoke-Command @invokeCommandParams;
    } #end process
} #end function Set-TargetResource