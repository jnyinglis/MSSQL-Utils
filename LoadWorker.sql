/*- LoadWorker Module

@doc LoadWorker
-*/

declare @module as varchar(100) = 'LoadWorker';

exec jni.DropModule @module;

go
--create procedure jni.[LoadWorker.Register]
--as
--begin
--	declare @worker_id as int;
--	exec jni.[LoadCoordinator.RegisterWorker] @@spid, @worker_id output;
--	select @worker_id;
--end
--go
create procedure jni.[LoadWorker.Start]
as
begin
	declare @worker_info as jni.[LoadCoordinator.WorkInfoType];
	declare @message varchar(max) = '';

	insert into @worker_info exec jni.[LoadCoordinator.RegisterWorker] @@spid;
	
	declare @procedures as table (
		ID int identity(1,1) not null,
		ProcedureName varchar(100) not null,
		ExecutionState varchar(100) not null default 'Not Executed',
		TimeStarted datetime,
		TimeCompleted datetime
	);
	insert into @procedures (ProcedureName)
		select	ProcedureName
		from	jni.[LoadCoordinator.ProceduresGet](@worker_info, jni.[LoadCoordinator.ConfigurationGet]());
	
	exec jni.[LoadCoordinator.LogWorkerMessage] @worker_info, 'set...waiting to start', null, null, null;
	
	while (jni.[LoadCoordinator.MaxWorkersReached](jni.[LoadCoordinator.ConfigurationGet]()) = 0)
	begin
		waitfor delay '00:00:10';
		exec jni.[LoadCoordinator.LogWorkerMessage] @worker_info, '...waiting', null, null, null;
	end
	exec jni.[LoadCoordinator.LogWorkerMessage] @worker_info, 'It''s a go!!', null, null, null;
	
	set @message = 'Begin execution of Role ';
	
	exec jni.[LoadCoordinator.LogWorkerMessage] @worker_info, @message, null, null, null;
	
	declare @id int = (select min(ID) from @procedures);
	begin try
		begin transaction;
		while (@id is not null)
		begin
			declare @procedure_name as varchar(100) = (select ProcedureName from @procedures where ID = @id);
			update @procedures set TimeStarted = getdate() where ID = @id;
			exec @procedure_name;
			update @procedures set TimeCompleted = getdate(), ExecutionState = 'Execution Completed' where ID = @id;
			set @id = ( select min(ID) from @procedures where ID > @id);
		end
		while @@trancount > 0 commit;
	end try
	begin catch
		declare @state int = XACT_STATE();
		declare @error_message varchar(1000) = error_message();
		if @state = -1 rollback
		set @message = 'Failed with: ' + @error_message
		update @procedures set TimeCompleted = getdate(), ExecutionState = 'Execution Failed' where ID = @id;
	end catch

	while @@trancount > 0 commit;

	set @id = (select min(ID) from @procedures);
	while (@id is not null)
	begin
		declare @time_started datetime;
		declare @time_completed datetime;
		declare @pn varchar(100);
		select	@message = ExecutionState + ' for ' + ProcedureName,
				@time_started = TimeStarted,
				@time_completed = TimeCompleted,
				@pn = ProcedureName
		  from	@procedures
		 where	ID = @id;
		exec jni.[LoadCoordinator.LogWorkerMessage] @worker_info, @message, @pn, @time_started, @time_completed;
		set @id = ( select min(ID) from @procedures where ID > @id);
	end

	set @message = 'End execution of Role ';
	exec jni.[LoadCoordinator.LogWorkerMessage] @worker_info, @message, null, null, null;
	
	exec jni.[LoadCoordinator.LogWorkerMessage] @worker_info, 'Exiting', null, null, null;
end
