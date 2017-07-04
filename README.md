# SQL Server Reporting Services

![Last build](https://tobania.visualstudio.com/_apis/public/build/definitions/68c0cf58-5599-4811-abf3-79c8aabb83f4/106/badge)

This Extention provides a way to deploy your SQL Server Reporting files to the SQL Server Reporting service.

Please use https://github.com/tobania/VSTS.Extension.SqlReportingServices/issues to report any bugs or problems you've encountered. We try to resolve them as soon as possible.

**Note that this task is RELEASE ONLY!**

There are two tasks available:
- __SqlReportingServicesDeployment__: Deploys the project without keeping the folderstructure of your local project. You can specify for each filetype (report,dataset,datasource & assets) where to drop the files on the SSRS.
- __SqlReportingServicesFolderDeployment__: Deploys the whole project. You specify the root on your local machine and the root on the SSRS. It will then deploy the folderstructure you have to SSRS. Files which are not reports,datasets or datasources are considered as assets. 

Documentation will follow on Github.
