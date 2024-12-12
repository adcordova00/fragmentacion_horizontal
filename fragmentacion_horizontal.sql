
-- Creación de la base de datos original
SET NOCOUNT ON
GO
set nocount    on
set dateformat mdy

USE master

declare @dttm varchar(55)
select  @dttm=convert(varchar,getdate(),113)
raiserror('Beginning InstPubs.SQL at %s ....',1,1,@dttm) with nowait

GO

if exists (select * from sysdatabases where name='pubs')
begin
  raiserror('Dropping existing pubs database ....',0,1)
  DROP database pubs
end
GO

CHECKPOINT
go

raiserror('Creating pubs database....',0,1)
go
CREATE DATABASE pubs
GO

CHECKPOINT
GO

USE pubs
GO

if db_name() <> 'pubs'
   raiserror('Error in InstPubs.SQL, ''USE pubs'' failed!  Killing the SPID now.'
            ,22,127) with log
GO

if CAST(SERVERPROPERTY('ProductMajorVersion') AS INT)<12 
BEGIN
  exec sp_dboption 'pubs','trunc. log on chkpt.','true'
  exec sp_dboption 'pubs','select into/bulkcopy','true'
END
ELSE ALTER DATABASE [pubs] SET RECOVERY SIMPLE WITH NO_WAIT
GO

execute sp_addtype id      ,'varchar(11)' ,'NOT NULL'
execute sp_addtype tid     ,'varchar(6)'  ,'NOT NULL'
execute sp_addtype empid   ,'char(9)'     ,'NOT NULL'

raiserror('Now at the create table section ....',0,1)
GO

CREATE TABLE authors
(
   au_id          id
         CHECK (au_id like '[0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]')
         CONSTRAINT UPKCL_auidind PRIMARY KEY CLUSTERED,
   au_lname       varchar(40)       NOT NULL,
   au_fname       varchar(20)       NOT NULL,
   phone          char(12)          NOT NULL DEFAULT ('UNKNOWN'),
   address        varchar(40)           NULL,
   city           varchar(20)           NULL,
   state          char(2)               NULL,
   zip            char(5)               NULL CHECK (zip like '[0-9][0-9][0-9][0-9][0-9]'),
   contract       bit               NOT NULL
)
GO

-- Fragmentación horizontal
-- Crear bases de datos para los fragmentos
CREATE DATABASE authors_CA;
CREATE DATABASE authors_UT;
GO

-- Crear tablas de fragmentos
USE authors_CA;
CREATE TABLE authors (
    au_id VARCHAR(11) PRIMARY KEY,
    au_lname VARCHAR(40) NOT NULL,
    au_fname VARCHAR(20) NOT NULL,
    phone CHAR(12) NOT NULL DEFAULT ('UNKNOWN'),
    address VARCHAR(40) NULL,
    city VARCHAR(20) NULL,
    state CHAR(2) NULL,
    zip CHAR(5) NULL CHECK (zip LIKE '[0-9][0-9][0-9][0-9][0-9]'),
    contract BIT NOT NULL
);

USE authors_UT;
CREATE TABLE authors (
    au_id VARCHAR(11) PRIMARY KEY,
    au_lname VARCHAR(40) NOT NULL,
    au_fname VARCHAR(20) NOT NULL,
    phone CHAR(12) NOT NULL DEFAULT ('UNKNOWN'),
    address VARCHAR(40) NULL,
    city VARCHAR(20) NULL,
    state CHAR(2) NULL,
    zip CHAR(5) NULL CHECK (zip LIKE '[0-9][0-9][0-9][0-9][0-9]'),
    contract BIT NOT NULL
);
GO

-- Insertar datos en los fragmentos
USE pubs;
INSERT INTO authors_CA.dbo.authors
SELECT * FROM authors WHERE state = 'CA';

INSERT INTO authors_UT.dbo.authors
SELECT * FROM authors WHERE state = 'UT';
GO

-- Crear vista unificada
USE pubs;
CREATE VIEW authors_unified AS
SELECT * FROM authors_CA.dbo.authors
UNION ALL
SELECT * FROM authors_UT.dbo.authors;
GO
