declare @xml as xml(jni.[LoadCoordinator.XSD]) = '
<LoadCoordinator Description="Load #1">
	<Workers>
		<Worker RoleType="SIRIS Store Orders" NumberOfWorkers="3"/>
	</Workers>
	<Roles>
		<Role Type="Allocator">
			<Task Procedure="jni.[LoadWorkerTask.CreatePurchaseOrder]"/>
			<Task Procedure="jni.[LoadWorkerTask.PreAllocatePurchaseOrder]"/>
			<Task Procedure="jni.[LoadWorkerTask.AuthorizeAllocation]"/>
		</Role>
		<Role Type="SIRIS Store Orders">
			<Task Procedure="jni.[LoadWorkerTask.StoreOrderWebService]"/>
			<Task Procedure="jni.[LoadWorkerTask.StoreOrderWebService]"/>
			<Task Procedure="jni.[LoadWorkerTask.StoreOrderWebService]"/>
		</Role>
		<Role Type="Buyer">
			<Task Procedure="jni.[LoadWorkerTask.StoreOrderWebService]"/>
		</Role>
		<Role Type="POS Sales">
			<Task Procedure="jni.[LoadWorkerTask.StoreOrderWebService]"/>
		</Role>
	</Roles>
	<WhenToStart Time="18:00:00"/>
</LoadCoordinator>
';



exec jni.[LoadCoordinator.Setup] @xml;

select * from jni.[LoadCoordinator.Configuration];
select * from jni.[LoadCoordinator.RegisteredWorkers];


select * from jni.[LoadCoordinator.WorkerLog]


