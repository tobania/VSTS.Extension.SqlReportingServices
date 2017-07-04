param(
	[Parameter(Mandatory=$True)][string]$RemoteRootPath,
	[Parameter(Mandatory=$True)][string]$LocalRootPath,
	[string]$UpdateDataSourceToRemote,
	[Parameter(Mandatory=$True)][string]$WebserviceUrl,
	[string]$WsUsername,
	[string]$WsPassword,
	[string]$UseVerbose,
	[string]$OverrideExisting,
	[string]$AddResourceExtension
)
	function Verbose-WriteLine{
		[cmdletbinding()]
		param(
			[Parameter(Position=1)]$text
		)
		if($UseVerbose -and $UseVerbose -eq $true){
			#$oldForeColor = $Host.UI.RawUI.ForegroundColor;
			#$oldBackColor = $Host.UI.RawUI.BackgroundColor;

			#$Host.Ui.RawUI.ForegroundColor = 'Black';
			#$Host.UI.RawUI.BackgroundColor = 'Yellow';
			Write-Host "[VERBOSE] >> $text" -;
			
			#$Host.Ui.RawUI.ForegroundColor = $oldForeColor;
			#$Host.UI.RawUI.BackgroundColor = $oldBackColor;
		}
	}

##########################################################
#                      SETUP OF CODE                     #
##########################################################
Add-Type -Path .\DirectoryHelpers.cs -ErrorAction SilentlyContinue; #Errors can be ignored

	Write-Host "Preparing Deployment of RDL files...";


	Verbose-WriteLine "Preparing script... (Verbose = $UseVerbose)";
	Verbose-WriteLine "Using following parameters:"
	Verbose-WriteLine "Remote root path: $RemoteRootPath";
	Verbose-WriteLine "Local root path: $LocalRootPath";
	Verbose-WriteLine "Attempt to update the datasource path: $UpdateDataSourceToRemote";
	
	$hasWsPassword = "N/A";
	if([System.String]::IsNullOrWhiteSpace($WsPassword) -eq $false){ #Check if the Webservice HAS a password and mark it with some stars
		$hasWsPassword = "********";
	}
	Verbose-WriteLine "Webservice: $WebserviceUrl";
	Verbose-WriteLine "WsUsername: $WsUsername";
	Verbose-WriteLine "WsPassword: $hasWsPassword";
	#Correcting remote server path
	if([string]::IsNullOrWhiteSpace($RemoteRootPath) -eq $false -and $RemoteRootPath.Length-1 -le -1 -and $RemoteRootPath.LastIndexOf("/") -eq $RemoteRootPath.Length-1){
		$RemoteRootPath = $RemoteRootPath.Substring(0,$RemoteRootPath.Length-1);
	}

	$LocalRootPath = [System.IO.Path]::GetFullPath($LocalRootPath);
	
##########################################################
#                      Testing files                     #
##########################################################

	Write-Host "Uploading files" -NoNewline;
	#Get all Files using the $ReportFiles parameter (expecting it is a Wildcard or direct link to 1 file)
	$pathIsValid = Test-Path $LocalRootPath;
	if($pathIsValid -eq $False){
		Write-Error "No file(s) matching the path/wildcard $LocalRootPath were found";#NotFound 1
		exit -1;
	}


##########################################################
#                Creating Webservice proxy               #
##########################################################

	$ssrs= $null; #Webservice proxy
	[System.Management.Automation.PSCredential]$auth = $null; #Auth incase there is one
	if([System.String]::IsNullOrWhiteSpace($WsUsername) -or [System.String]::IsNullOrWhiteSpace($WsPassword)){  #If not use the DefaultCredential (PS session of the machine where this powershell script is executed
		Write-Host "Creating WebService proxy using default credentials"; 
		$ssrs =New-WebServiceProxy -Uri $WebserviceUrl -UseDefaultCredential -ErrorAction Stop;
	}else{#Incase there is a Webservice user-password pair, use the PSCredential of that pair
		Write-Host "Creating WebService proxy using credentials";
		$wsSecurePass = ConvertTo-SecureString -String $WsPassword -AsPlainText -Force

		$auth = New-Object System.Management.Automation.PSCredential -ArgumentList $WsUsername,$wsSecurePass;
		$ssrs = New-WebServiceProxy -Uri $WebserviceUrl -Credential $auth -ErrorAction Stop;
	}

    $type = $ssrs.GetType().Namespace;

    #display datatype, just for our reference
    Verbose-WriteLine "Got Namespace $datatype for SSRS..."; 
##########################################################
#                 Recurse upload to SSRCS                #
##########################################################

$dirs = [Tobania.SqlReportingFolderDeployment.DirectoryHelpers]::GetFolderStructure($LocalRootPath,$RemoteRootPath);

$dirs;
foreach($folder in $dirs.GetEnumerator()){
	[string]$folderPath=$folder.Key.Replace("/" + $folder.Value,"");
	[string]$folderName = $folder.Value;
	if($folderName.IndexOf('/') -eq 0){
		$folderName = $folderName.Substring(1);
	}

	$props = New-Object "System.Collections.Generic.List[$type.Property]";
	$mime = New-Object ("$type.Property");
	$mime.Name = "Description";
	$mime.Value = "Uploaded by Tobania.VSTS.SqlREportinServicesFolderDeployment";
	$props.Add($mime);
	
	if($folderPath.IndexOf('/') -ne 0){
		$folderPath = "/" + $folderPath;
	}
	Write-Host $folderPath;
	try{
		$ssrs.CreateFolder($folderName,$folderPath,$props.ToArray());
	}catch{
		 if($_.Exception.Message.ToLower().Contains("already exists")){
			Verbose-WriteLine "Folder $folderName already exists, Skipping!" 
		 }else{
			throw;
		 }
	}
}



$files = @(Get-ChildItem $LocalParentFolder -Recurse);
[Collections.Generic.List[String]]$dataSources = New-Object "System.Collections.Generic.List[String]";
[Collections.Generic.List[String]]$dataSets = New-Object "System.Collections.Generic.List[String]";
[Collections.Generic.List[String]]$reports = New-Object "System.Collections.Generic.List[String]";
[Collections.Generic.List[String]]$assets = New-Object "System.Collections.Generic.List[String]";

foreach($file in $files){
	$ext=[System.IO.Path]::GetExtension($file.FullName).ToLower();
	if($ext.Contains("rdl")){
		$reports.Add($file.FullName);
	}
	elseif($ext.Contains("rds")){
		$dataSources.Add($file.FullName);
	}elseif($ext.Contains("rsd")){
		$dataSets.Add($file.FullName);
	}
	else{
		$assets.Add($file.FullName);
	}
}

Write-Host "Uploading Data sources...";

$dataSources | ForEach-Object{
	[xml]$rds = Get-Content -Path $_; #Read the RDS(XML) files
	$connectionProperties = $rds.RptDataSource.ConnectionProperties;
	$Definition = New-Object ("$type.DataSourceDefinition"); 
	$Definition.ConnectString = $connectionProperties.ConnectString;
	$Definition.Extension = $connectionProperties.Extension;
	$Definition.Extension = $connectionProperties.Extension; #Add the Extension from the RDS
	if([System.Convert]::ToBoolean($connectionProperties.IntegratedSecurity)){ #Set the Integrated mode
		$Definition.CredentialRetrieval = 'Integrated'
	}
	Write-Host ($Definition | Format-List | Out-String)
	$rdsName = $rds.RptDataSource.Name;
	Verbose-WriteLine "Creating Datasource $rdsName";
	[System.IO.FileInfo]$fileInfo = New-Object "System.IO.FileInfo" -ArgumentList $_;
	
	#Documentation of the method below: https://msdn.microsoft.com/en-us/library/reportservice2010.reportingservice2010.createdatasource.aspx
	$createdDatasource = $ssrs.CreateDataSource( #Create/Update the Datasource
		$rdsName, #The name of the RDS
		[Tobania.SqlReportingFolderDeployment.DirectoryHelpers]::ExtractRemotePath($fileInfo.Directory,$LocalRootPath,$RemoteRootPath), #Let the helper do the conversion
		$true, #Override existing
		$Definition,# The definition ("xml")
		$null #Additional properties
	);


};

Write-Host "Uploading Datasets...";

$dataSets | ForEach-Object{
	$datasetName = $_; 
	$datasetFileName = [System.IO.Path]::GetFileNameWithoutExtension($datasetName);
	Write-Host "Uploading datasource $datasetName to $DataSetRootPath...";
	Verbose-WriteLine "Reading $datasetName file...";
	[xml]$rsd = Get-Content $datasetName;
	$byteRsd = Get-Content $datasetName -Encoding Byte
	$warnings = $null;
	try{
		[System.IO.FileInfo]$fileInfo = New-Object "System.IO.FileInfo" -ArgumentList $_;
		$dataset = $ssrs.CreateCatalogItem(
			"DataSet",
			$datasetFileName,
			[Tobania.SqlReportingFolderDeployment.DirectoryHelpers]::ExtractRemotePath($fileInfo.Directory,$LocalRootPath,$RemoteRootPath), #Let the helper do the conversion
			$true,
			$byteRsd,
			$null,
			[ref]$warnings
		);
		
		#If any warning was logged during upload, log them to the console
		if($warnings -ne $null){
			Write-Warning "One or more warnings occured during upload:";
			$warningSb = New-Object System.Text.StringBuilder;
			$warnings | ForEach-Object{
				$txtWarning = $_.Message;
				$warningSb.AppendLine("`t- {$txtWarning}");
			}
			Write-Warning $warningSb.ToString();
		}
	}catch [System.Exception]{
		Write-Error $_.Exception.Message;
		#Terminate script
		exit -1;
	}
};

Write-Host "Uploading Assets...";

Add-Type -AssemblyName "System.Web";
$assets | ForEach-Object{
	[System.IO.FileInfo]$fileInfo = New-Object "System.IO.FileInfo" -ArgumentList $_;
	if(!$fileInfo.Attributes.HasFlag([System.IO.FileAttributes]::Directory)){
		$bts = Get-Content $_ -Encoding Byte;
		$fileName = [System.IO.Path]::GetFileNameWithoutExtension($_);
		if($AddResourceExtension -eq $true){
			$fileName = [System.IO.Path]::GetFileName($_);
		}
		$warning =$null;
		$props = New-Object "System.Collections.Generic.List[$type.Property]";
		$mime = New-Object ("$type.Property");
		$mime.Name = "MimeType";
		$mime.Value = [System.Web.MimeMapping]::GetMimeMapping($_); #Set THe correct mimetype
		$props.Add($mime);
	
		$resource = $ssrs.CreateCatalogItem(
			"Resource",
			$fileName,
			[Tobania.SqlReportingFolderDeployment.DirectoryHelpers]::ExtractRemotePath($fileInfo.Directory,$LocalRootPath,$RemoteRootPath), #Let the helper do the conversion
			$true,
			$bts,
			$props.ToArray(),
			[ref]$warning
		);
		if($warnings -ne $null){
			Write-Warning "One or more warnings occured during upload:";
			$warningSb = New-Object System.Text.StringBuilder;
			$warnings | ForEach-Object{
				$txtWarning = $_.Message;
				$warningSb.AppendLine("`t- {$txtWarning}");
			}
			Write-Warning $warningSb.ToString();
		}
	}
}

Write-Host "Uploading Reports..." + $ReportFiles.Count; 

$reports | ForEach-Object{
	if(![String]::IsNullOrWhiteSpace($_)){
	$reportName = [System.IO.Path]::GetFileNameWithoutExtension($_); #Get the name of the reportname
	$bytes = [System.IO.File]::ReadAllBytes($_); #Get The path to upload
	$byteLenght = $bytes.Lenght; #for verbose logging 
	Write-Host "Uploading report $reportName to $ReportUploadRootPath...";
	Verbose-WriteLine "Uploading $reportName with filesize $byteLength bytes"; 
	$warnings =$null; #Warnings associated to the upload
	try{
	[System.IO.FileInfo]$fileInfo = new-object 'System.IO.FileInfo' -ArgumentList $_;
	$report = $ssrs.CreateCatalogItem(
		"Report", #The Catalog Item
		$reportName, #The report name
		[Tobania.SqlReportingFolderDeployment.DirectoryHelpers]::ExtractRemotePath($fileInfo.Directory,$LocalRootPath,$RemoteRootPath), #Let the helper do the conversion
		$OverrideExisting, #Overriding files which exists
		$bytes, #The bytes to upload
		$null, #Additional properties to set
		[ref]$warnings #Warnings associated to the upload
	);

		#If any warning was logged during upload, log them to the console
		if($warnings -ne $null){
			Write-Warning "One or more warnings occured during upload:";
			$warningSb = New-Object System.Text.StringBuilder;
			$warnings | ForEach-Object{
				$txtWarning = $_.Message;
				$warningSb.AppendLine("`t- {$txtWarning}");
			}
			Write-Warning $warningSb.ToString();
		}
		
		if($UpdateDataSourceToRemote -eq $true){ #Update the datasources
			Write-Host "Updating the DataSources of the report $reportName...";
			
			$serverDataSources = $ssrs.ListChildren($RemoteRootPath,$true);
			$neededDataSources = $ssrs.GetItemDataSources($report.Path);
			
			$neededDataSources | ForEach-Object{
				$reportDataSourceName = $_.Name;
				Foreach($serverDataSource in $serverDataSources){
					if([System.String]::Compare($serverDataSource.Name.Trim(),$reportDataSourceName.Trim(),$true) -eq 0){
						$dataSourcePathNew = $serverDataSource.Path;
						
						Write-Host "Updating DataSource '$reportDataSourceName' to path '$dataSourcePathNew'..." -NoNewline;
							
						$dataSourceReferenceNew = New-Object("$type.DataSourceReference");
						$dataSourceReferenceNew.Reference = $dataSourcePathNew;

						$dataSourceNew = New-Object ("$type.DataSource");
						$dataSourceNew.Name =$reportDataSourceName;
						$dataSourceNew.Item = $dataSourceReferenceNew;
						#[System.Collections.Generic.List[$type + ".DataSource"]]$arr = @($dataSourceNew);
						$ssrs.SetItemDataSources($report.Path,$dataSourceNew);
						Write-Host "Done!";
						break;
					}
				}
			}
		}
	}catch [System.Exception]{
		Write-Error $_.Exception.Message;
		#Terminate script
		exit -1;
	}
	}
}





 