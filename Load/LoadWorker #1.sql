select 'exec jni.[LoadWorker.Start];', @@trancount
exec jni.[LoadWorker.Start];
select 'exec jni.[LoadWorker.Start];', @@trancount
--commit
