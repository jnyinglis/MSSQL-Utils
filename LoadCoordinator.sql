/*- @Module LoadCoordinator

@doc LoadCoordinator
-*/

declare @module as varchar(100) = 'LoadCoordinator';

exec jni.DropModule @module;

go

create xml schema collection jni.[LoadCoordinator.XSD] as
'<?xml version="1.0"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified" attributeFormDefault="unqualified">
	<xs:element name="LoadCoordinator" type="LoadCoordinatorType"/>

	<xs:complexType name="LoadCoordinatorType">
		<xs:sequence>
			<xs:element name="Workers" type="WorkersType" minOccurs="1" maxOccurs="1"/>
			<xs:element name="Roles" type="RolesType" minOccurs="0" maxOccurs="1"/>
			<xs:element name="WhenToStart" type="StartType" minOccurs="1" maxOccurs="1"/>
		</xs:sequence>
		<xs:attribute name="Description" type="xs:string" use="required"/>
	</xs:complexType>

	<xs:complexType name="WorkersType">
		<xs:sequence>
			<xs:element name="WorkerTask" type="TaskType" minOccurs="0" maxOccurs="1"/>
			<xs:element name="Worker" type="WorkerType" minOccurs="0" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

	<xs:complexType name="TaskType">
		<xs:attribute name="Procedure" type="xs:string" use="required"/>
	</xs:complexType>

	<xs:complexType name="WorkerType">
		<xs:attribute name="RoleType" type="xs:string" use="required"/>
		<xs:attribute name="NumberOfWorkers" type="xs:positiveInteger" use="required"/>
	</xs:complexType>

	<xs:complexType name="RolesType">
		<xs:sequence>
			<xs:element name="Role" type="RoleType" minOccurs="1" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

	<xs:complexType name="RoleType">
		<xs:sequence>
			<xs:element name="Task" type="TaskType" minOccurs="1" maxOccurs="unbounded"/>
		</xs:sequence>
		<xs:attribute name="Type" type="xs:string" use="required"/>
	</xs:complexType>
	
	<xs:complexType name="StartType">
		<xs:attribute name="Delay" type="xs:string" use="optional"/>
		<xs:attribute name="Time" type="xs:string" use="optional"/>
	</xs:complexType>

</xs:schema>
'
go
create type jni.[LoadCoordinator.WorkInfoType] as table
(
	WorkerID int not null,
	RoleType varchar(100) not null
)
go
drop table jni.[LoadCoordinator.Configuration]
drop table jni.[LoadCoordinator.RegisteredWorkers]
drop table jni.[LoadCoordinator.WorkerLog]
go
create table jni.[LoadCoordinator.Configuration] (
	configuration xml not null
)
go
create table jni.[LoadCoordinator.RegisteredWorkers] (
	WorkerID int identity(1,1) not null,
	SPID int not null,
	RoleType varchar(100) not null,
	primary key (WorkerID),
	unique (SPID)
)
go
create table jni.[LoadCoordinator.WorkerLog] (
	ID int identity(1,1) not null,
	WorkerID int not null,
	DateCreated datetime not null default getdate(),
	RoleType varchar(100) not null,
	Message varchar(max) not null,
	TaskProcedure varchar(100),
	TimeStarted datetime null,
	TimeCompleted datetime null
)
go
/*-

@doc LoadCoordinator
-*/
create procedure jni.[LoadCoordinator.Setup]
@xml as xml(jni.[LoadCoordinator.XSD])
as
begin
	truncate table jni.[LoadCoordinator.Configuration];
	truncate table jni.[LoadCoordinator.RegisteredWorkers];
	truncate table jni.[LoadCoordinator.WorkerLog];
	insert into jni.[LoadCoordinator.Configuration] values (@xml);
end
go
/*-
-*/
create procedure jni.[LoadCoordinator.RegisterWorker] (
@spid	int)
as
begin
	declare @return jni.[LoadCoordinator.WorkInfoType];
	begin try
		if jni.[LoadCoordinator.MaxWorkersReached](jni.[LoadCoordinator.ConfigurationGet]()) = 1 raiserror('Max Workers Reached', 16, 1);
		if jni.[LoadCoordinator.IsWorkerRegistered](@spid) = 1 raiserror('Worker is already registered with this SPID', 16, 1);
		declare @RoleType varchar(100) = jni.[LoadCoordinator.NextAvailbleRole](jni.[LoadCoordinator.ConfigurationGet]());
		
		insert into jni.[LoadCoordinator.RegisteredWorkers] (
			RoleType,
			SPID
		)
		output inserted.WorkerID, inserted.RoleType into @return
		values (
			@RoleType,
			@spid
		);
	end try
	begin catch
		declare @error_message varchar(max) = error_message();
		raiserror(@error_message, 16, 1);
	end catch;
	select * from @return;
end
go
create function jni.[LoadCoordinator.ConfigurationGet]()
returns xml(jni.[LoadCoordinator.XSD])
as
begin
		return (
			select configuration from jni.[LoadCoordinator.Configuration]
		);
end
go
create function jni.[LoadCoordinator.MaxWorkersReached](
@configuration as xml(jni.[LoadCoordinator.XSD])
)
returns bit
as
begin
	--declare @configuration as xml(jni.[LoadCoordinator.XSD]) = ( select configuration from jni.[LoadCoordinator.Configuration]);
	declare @maxWorkers as int = (
		select	sum(Configuration.Worker.value('./@NumberOfWorkers', 'int')) AS Number
		  from	@configuration.nodes('/LoadCoordinator/Workers/Worker') Configuration(Worker)
	);
	return (case when (select max(WorkerID) from jni.[LoadCoordinator.RegisteredWorkers]) = @maxWorkers then 1 else 0 end);
end
go
create function jni.[LoadCoordinator.WorkerRoles](
@configuration as xml(jni.[LoadCoordinator.XSD])
)
returns table
as
	return (
		select	[RoleType],
				sum([NumberOfWorkers]) [ConfiguredWorkers]
		  from	(
				select	Configuration.Worker.value('./@RoleType', 'varchar(100)') AS [RoleType],
						Configuration.Worker.value('./@NumberOfWorkers', 'int') AS [NumberOfWorkers]
				  from	@configuration.nodes('/LoadCoordinator/Workers/Worker') Configuration(Worker)
				) t1
		group by [RoleType]
	);
go
create function jni.[LoadCoordinator.NextAvailbleRole](
@configuration as xml(jni.[LoadCoordinator.XSD])
)
returns varchar(100)
as
begin
	return (
		select	top 1
				t1.RoleType
		from	jni.[LoadCoordinator.WorkerRoles](@configuration) t1
				left outer join (
					select	RoleType,
							count(*) RegisteredWorkers
					  from	jni.[LoadCoordinator.RegisteredWorkers]
					group by RoleType
				) t2
				on t2.RoleType = t1.RoleType
		order by t1.ConfiguredWorkers - isnull(t2.RegisteredWorkers, 0) desc
	);
end
go
create function jni.[LoadCoordinator.IsWorkerRegistered](
@spid int)
returns bit
as
begin
	declare @cnt as int = (select count(*) from jni.[LoadCoordinator.RegisteredWorkers] where SPID = @spid);
	return (case when @cnt = 0 then 0 else 1 end);
end
go
--create function jni.[LoadCoordinator.WorkerTask](
--@worker_info as jni.[LoadCoordinator.WorkInfoType] readonly)
--returns varchar(100)
--as
--begin
--	declare @configuration as xml(jni.[LoadCoordinator.XSD]) = jni.[LoadCoordinator.ConfigurationGet]();
--	return(
--		select	Configuration.WorkerTask.value('./@Procedure', 'varchar(100)') AS [Procedure]
--		  from	@configuration.nodes('/LoadCoordinator/Workers/WorkerTask') Configuration(WorkerTask)
--	);
--end
--go
create function jni.[LoadCoordinator.ProceduresGet](
@worker_info as jni.[LoadCoordinator.WorkInfoType] readonly,
@configuration as xml(jni.[LoadCoordinator.XSD]))
returns @return table (
	ProcedureName varchar(100) not null
)
as
begin
	declare @RoleType as varchar(100) = (select RoleType from @worker_info);

	insert into @return
		select	t1.ProcedureName
		from	(
				select	Configuration.Role.value('@Type', 'varchar(100)') AS [RoleType],
						RoleType.Task.value('./@Procedure', 'varchar(100)') AS [ProcedureName]
				  from	@configuration.nodes('/LoadCoordinator/Roles/Role') Configuration(Role)
						cross apply Configuration.Role.nodes('./Task') RoleType(Task)
				) t1
		where	[RoleType] = @RoleType;
		return;
end
go
create procedure jni.[LoadCoordinator.LogWorkerMessage](
@worker_info as jni.[LoadCoordinator.WorkInfoType] readonly,
@message as varchar(max),
@task_procedure as varchar(100),
@time_started as datetime,
@time_completed as datetime)
as
begin
	insert into jni.[LoadCoordinator.WorkerLog] (WorkerID, RoleType, [Message], TaskProcedure, TimeStarted, TimeCompleted)
		select WorkerID, RoleType, @message, @task_procedure, @time_started, @time_completed from @worker_info
end
