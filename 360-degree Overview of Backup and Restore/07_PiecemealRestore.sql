/*
07_PiecemealRestore.sql
Written by Taiob Ali
taiob@sqlworlwide.com
https://bsky.app/profile/sqlworldwide.bsky.social
https://twitter.com/SqlWorldWide
https://sqlworldwide.com/
https://www.linkedin.com/in/sqlworldwide/

Code copied from this link and modified for this presentation
https://www.red-gate.com/simple-talk/wp-content/uploads/RedGateBooks/ShawnMcGehee/sql-server-backup-restore.pdf

Last Modiefied
August 28, 2023
	
Tested on :
SQL Server 2022 CU7
SSMS 19.1

We don't need to be taking file backups in order to perform a partial/piecemeal restore. 
If the database is small enough, we can still take full database backups and then restore just a certain filegroup from that backup file as shown in this demo
*/


/*
Delete all old backups
*/

EXEC master.sys.xp_delete_files N'C:\Temp\backupOverview\*'

/*
Setting up database and tables for demo
*/

USE master;
GO

DECLARE @SQL nvarchar(1000);

IF EXISTS (SELECT 1 FROM sys.databases WHERE [name] = N'piecemealRestoreTest')
  BEGIN
    SET @SQL = 
      N'USE [master];
       ALTER DATABASE piecemealRestoreTest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
       USE [master];
       DROP DATABASE piecemealRestoreTest;';
    EXEC (@SQL);
  END;
ELSE
  BEGIN
    PRINT 'Database piecemealRestoreTest does not exist, creating a new one'
  END
GO

CREATE DATABASE piecemealRestoreTest ON PRIMARY 
	(	NAME = N'piecemealRestoreTest', 
		FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\piecemealRestoreTest.mdf', 
		SIZE = 5120KB, FILEGROWTH = 1024KB ), 
	FILEGROUP [Secondary] 
	(	NAME = N'piecemealRestoreTestData2', 
		FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\piecemealRestoreTestData2.ndf', 
		SIZE = 5120KB, FILEGROWTH = 1024KB )
	LOG ON 
	( NAME = N'piecemealRestoreTestData2_log', 
		FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\piecemealRestoreTestData2_log.ldf', 
		SIZE = 1024KB, FILEGROWTH = 512KB ) 
GO 

ALTER DATABASE piecemealRestoreTest SET RECOVERY FULL;
GO

IF NOT EXISTS 
	(	SELECT  name                 
		FROM sys.filegroups 
		WHERE is_default = 1
		AND name = N'Secondary'
	)  
ALTER DATABASE piecemealRestoreTest MODIFY FILEGROUP [Secondary] DEFAULT;
GO

USE piecemealRestoreTest;
GO  

CREATE TABLE dbo.messagePrimary
(Message NVARCHAR(50) NOT NULL) ON  [PRIMARY];
GO  

CREATE TABLE dbo.messageSecondary 
(Message NVARCHAR(50) NOT NULL) ON  [SECONDARY];
GO  

INSERT INTO dbo.messagePrimary
VALUES ('This is the data for the primary filegroup');
GO

INSERT INTO messageSecondary 
VALUES ('This is the data for the secondary filegroup');
GO

/*
Highly recommended to start with a full backup of the whole database
We are skipping that for demo puroses
Taking file backups followed by transaction log backup so transactions can be rolled forward
*/

USE master;
GO

BACKUP DATABASE piecemealRestoreTest
FILEGROUP = N'Primary' 
TO  DISK = N'C:\Temp\backupOverview\piecemealRestoreTest_FG_Primary.bak'
WITH INIT;
GO

BACKUP LOG piecemealRestoreTest
TO DISK = N'C:\Temp\backupOverview\piecemealRestoreTest_log1.trn';
GO

BACKUP DATABASE piecemealRestoreTest
FILEGROUP = N'Secondary' 
TO  DISK = N'C:\Temp\backupOverview\piecemealRestoreTest_FG_Secondary.bak'
WITH INIT;
GO

BACKUP LOG piecemealRestoreTest
TO DISK = N'C:\Temp\backupOverview\piecemealRestoreTest_log2.trn';
GO

/*
Restore primary filegroup only followed by subsequent log backups
Bring the database online (without secondary filegroup)

PARTIAL = A piecemeal restore begins with a RESTORE DATABASE using the PARTIAL option and specifying one or more secondary filegroups to be restored
REPLACE = REPLACE should be used rarely and only after careful consideration. I am using it here as we did not take a tail log backup
*/

USE master;
GO 

RESTORE DATABASE piecemealRestoreTest FILEGROUP = N'primary'  
FROM DISK = N'C:\Temp\backupOverview\piecemealRestoreTest_FG_Primary.bak'
WITH PARTIAL, NORECOVERY, REPLACE; ; 
GO  

RESTORE DATABASE piecemealRestoreTest 
FROM DISK = N'C:\Temp\backupOverview\piecemealRestoreTest_log1.trn'
WITH NORECOVERY;  
GO 

RESTORE DATABASE piecemealRestoreTest 
FROM DISK = N'C:\Temp\backupOverview\piecemealRestoreTest_log2.trn'
WITH RECOVERY;  
GO 

/*
Select from tables from both filegroups
*/

USE piecemealRestoreTest;
GO

SELECT [Message] from dbo.messagePrimary;
GO

SELECT [Message] from dbo.messageSecondary;
GO

/*
Restore secondary filegroup only followed by subsequent log backups
*/

USE master;
GO 

RESTORE DATABASE piecemealRestoreTest 
FROM DISK = N'C:\Temp\backupOverview\piecemealRestoreTest_FG_Secondary.bak'
WITH NORECOVERY; 
GO  

RESTORE DATABASE piecemealRestoreTest 
FROM DISK = N'C:\Temp\backupOverview\piecemealRestoreTest_log2.trn'
WITH RECOVERY;  
GO 

/*
Select from tables from both filegroups
*/

USE piecemealRestoreTest;
GO

SELECT [Message] from dbo.messagePrimary;
GO

SELECT [Message] from dbo.messageSecondary;
GO

/*
Clean up
*/

USE master;
GO

DROP DATABASE IF EXISTS piecemealRestoreTest;
GO
