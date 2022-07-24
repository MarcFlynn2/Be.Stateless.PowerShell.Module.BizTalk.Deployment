﻿#region Copyright & License

# Copyright © 2012 - 2022 François Chabot
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#endregion

<#
.SYNOPSIS
   Deploys the resources declared by a given Microsoft BizTalk Server® application deployment manifest.
.DESCRIPTION
   This command will entrust Invoke-Build to carry on all the tasks necessary to deploy the resources declared by a given Microsoft BizTalk Server® application
   deployment manifest, which manifest is a HashTable created with the Resource.Manifest PowerShell module.
.PARAMETER Manifest
   The application deployment manifest instance.
.PARAMETER Path
   The path to the application deployment manifest.
.PARAMETER TargetEnvironment
   The target deployment environment, which can be any string value, but also supports the target environments defined by BizTalk.Factory, i.e. 'DEV' for
   development, 'BLD' for build, 'INT' for integration, 'ACC' for acceptance, 'PRE' for preproduction, or 'PRD' for production.
.PARAMETER Task
   User defined tasks that the manifest depends on to complete its deployment. Tasks can either be new ones or override existing ones. See Invoke-Build
   documentation, How to assemble builds using script blocks, https://github.com/nightroman/Invoke-Build/tree/master/Tasks/Inline, and Script block as File,
   https://github.com/nightroman/Invoke-Build/issues/78, for some explanation.
   Notice that BizTalk.Deployment provides customization/injection points by defining Enter-/Exit-<ResourceScope> tasks, e.g. Enter-DatabaseDeployment and
   Exit-DatabaseDeployment that allows to inject pre- or post-processing tasks surrounding the database deployment tasks.
.PARAMETER ExcludeResourceGroup
   The wildcard pattern determining the names of the resources or pseudo resources to ignore during the deployment. Notice that even though the tasks related to
   these resources will still be executed, they will proceed as if these resources had not been declared and will thus have no effect. All the resources of a
   manifest can be excluded at once by passing the wildcard * character.
.PARAMETER ExcludeTask
   The wildcard pattern determining the names of the tasks to skip during the deployment. Skipping a task also skips all its dependant tasks, e.g. skipping the
   'Deploy' task will skip the whole deployment, as well as passing the wildcard * character.
.PARAMETER FileUser
   The names of the users or groups, local or not, to be granted full access control over the folders declared by both inbound and outbound Microsoft BizTalk
   Server® file adapters. It defaults to both local groups 'BizTalk Application Users' and 'Users'. This parameter has effect provided the 'SkipFileAdapterFolders'
   switch parameter is not passed.
.PARAMETER InitializationOption
   The set of Microsoft BizTalk Server® services, or artifacts, to start after deployment is complete. This is bitmask enumeration defining the following values:
   - None, when no services at all have to be started,
   - Orchestrations, when only the orchestrations have to be started,
   - ReceiveLocations, when only the receive locations have to be enabled,
   - SendPorts, when only the send ports have to be started,
   - All, when all of the above services have to started. It is the default value and is equivalent to passing the following array of values: Orchestrations,
     ReceiveLocations, SendPorts.
.PARAMETER Isolated
   Whether to execute the tasks that load the application binding assembly written in BizTalk.Factory's Binding DSL in another local process via PowerShell
   remoting. It is particularly handy for the developer who is fine tuning the binding assembly and constantly needs to recompile and redeploy it without having it
   being locked by the PowerShell process. As a .NET assembly, once loaded, cannot be unloaded, and unlocked, unless the process that has loaded it is terminated,
   this switch parameter prevents the developer from constantly having to kill his shell and start a new one. For this reason, it defaults to true when the
   TargetEnvironment parameter is given the value 'DEV'.
.PARAMETER SkipFileAdapterFolders
   Whether to skip creating the folders declared by both inbound and outbound Microsoft BizTalk Server® file adapters, as well as modifying their ACLs. The same
   effect could be achieved by excluding the pseudo resource group FileAdapterFolders.
.PARAMETER SkipHostInstanceRestart
   Whether to skip restarting the Microsoft BizTalk Server® host instances concerned by the application being deployed.
.PARAMETER SkipSharedResources
   Whether to skip all the resources that need to be deployed only once in a Microsoft BizTalk Server® group. Indeed, resources such as Microsoft BizTalk Server®
   application bindings and other artifacts like orchestrations, schemas, or maps need to be imported in the Microsoft BizTalk Server®'s management database only
   once, that is to say on only one of the machines belonging to the same Microsoft BizTalk Server® group. While resources such as assembly, windows services,
   event log sources, or xml configurations need to deployed on every machine belonging to the same Microsoft BizTalk Server® group.
   To summarize, this switch parameter needs to passed for every machine belonging to the same Microsoft BizTalk Server® group but the one playing the role of the
   management server.
.PARAMETER SkipUninstall
   Whether to skip the undeployment of the resources declared by the manifest before trying to deploy them. Notice that by default, an uninstall will be triggered
   when the TargetEnvironment is 'DEV' but will always be skipped for other TargetEnvironment values unless this switch parameter is explicitly passed. Care should
   be taken as to whether this switch should be used for target environments such as acceptance or production.
.PARAMETER TerminateServiceInstances
   Whether to terminate any running or suspended Microsoft BizTalk Server® service instances related to the application being uninstalled.
.EXAMPLE
   PS> Install-BizTalkApplication -Manifest $m -TargetEnvironment DEV
.EXAMPLE
   PS> Install-BizTalkApplication -Manifest $m -TargetEnvironment PRD -InitializationOption Orchestrations, SendPorts
.EXAMPLE
   PS> Install-BizTalkApplication -Manifest $m -TargetEnvironment DEV -ExcludeResourceGroup * -Verbose

   As all the resources are excluded, this command outputs the tasks that would have carried on.
.EXAMPLE
   PS> Install-BizTalkApplication -Manifest $m -TargetEnvironment DEV -Task { task Deploy { Write-Host 'I hijacked the whole deployment process.' } }
.LINK
   https://www.stateless.be/PowerShell/Module/BizTalk/Deployment/
.NOTES
   © 2022 be.stateless.
#>
[CmdletBinding(DefaultParameterSetName = 'manifest-path')]
[OutputType([void])]
param(
   [Parameter(Mandatory = $true, ParameterSetName = 'manifest-object')]
   [ValidateNotNullOrEmpty()]
   [ValidateScript( { $_.Properties.Type -eq 'Application' } )]
   [HashTable[]]
   $Manifest,

   [Parameter(Mandatory = $true, ParameterSetName = 'manifest-path')]
   [ValidateNotNullOrEmpty()]
   [ValidateScript( { Test-Path -Path $_ -PathType Leaf } )]
   [string[]]
   $Path,

   [Parameter(Mandatory = $true, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $true, ParameterSetName = 'manifest-path')]
   [ValidateNotNullOrEmpty()]
   [string]
   $TargetEnvironment,

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [scriptblock[]]
   $Task = ([scriptblock] { }),

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [ValidateNotNullOrEmpty()]
   [string[]]
   $ExcludeResourceGroup = @(),

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [ValidateNotNullOrEmpty()]
   [string[]]
   $ExcludeTask = @(),

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [ValidateNotNullOrEmpty()]
   [string[]]
   $FileUser = @("$($env:COMPUTERNAME)\BizTalk Application Users", 'BUILTIN\Users'),

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [Be.Stateless.BizTalk.Dsl.Binding.Visitor.BizTalkServiceInitializationOptions]
   $InitializationOption = 'All',

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [switch]
   $Isolated = ($TargetEnvironment -eq 'DEV'),

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [switch]
   $SkipFileAdapterFolders,

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [switch]
   $SkipHostInstanceRestart,

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [switch]
   $SkipSharedResources,

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [switch]
   $SkipUninstall = ($TargetEnvironment -ne 'DEV'),

   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-object')]
   [Parameter(Mandatory = $false, ParameterSetName = 'manifest-path')]
   [switch]
   $TerminateServiceInstances
)
begin {
   Set-StrictMode -Version Latest
   Resolve-ActionPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
}
process {
   $script:Manifest = switch ($PsCmdlet.ParameterSetName) {
      'manifest-object' { $Manifest }
      'manifest-path' { & $Path }
   }
   if ($script:Manifest.Properties.Type -ne 'Application') {
      throw "This command does not support this type of manifest '$($script:Manifest.Properties.Type)'."
   }

   # https://github.com/nightroman/Invoke-Build/issues/78, Script block as `File`
   # https://github.com/nightroman/Invoke-Build/tree/master/Tasks/Inline
   try {
      $taskBlockList = $Task # don't clash with InvokeBuild's $Task variable
      Invoke-Build Deploy {
         . BizTalk.Deployment.Tasks
         foreach ($taskBlock in $taskBlockList) {
            . $taskBlock
         }
      }
   } catch {
      Write-Error $_.Exception.ToString()
      throw
   }
}
