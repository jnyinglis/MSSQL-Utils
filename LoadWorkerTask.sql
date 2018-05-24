/*- TestWorkerTask Module

@doc TestWorkerTask
-*/

declare @module as varchar(100) = 'LoadWorkerTask';

exec jni.DropModule @module;

go
create procedure jni.[LoadWorkerTask.StoreOrderWebService]
as
declare @i as int = cast(rand()*10 as int);
declare @StoreCode varchar(12);
select top (@i) @StoreCode = Code from ar_v_Stores order by Code;
declare @OrderCode varchar(12) = right(convert(varchar(40), getdate(), 121), 12);
declare @OrderType int = 5;
declare @Authorized char(1) = 'Y';
declare @Allocate char(1) = 'Y';
declare @OrderDate date = cast(getdate() as date);
declare @ReqDate date = cast(getdate() as date);


declare @xml as xml = (
	select	@StoreCode as '@StoreCode',
			@OrderCode as '@OrderCode',
			@OrderDate as '@OrderDate',
			@OrderType as '@OrderType',
			@Authorized as '@Authorized',
			@Allocate as '@Allocate',
			(
				select	top 600
						Code as '@ProductCode',
						@ReqDate as '@ReqDate',
						100 as '@Quantity'
				from ar_v_Products p
				for xml path('Line'), root('Lines'), type
			)
	for xml path('StoreOrder'), root('StoreOrders'), type
);

select @xml;

DECLARE @RC int
DECLARE @i_TraceOn tinyint = 0
DECLARE @i_Stream tinyint = 1
DECLARE @i_UserCode varchar(4) = 'mgb'
DECLARE @i_Data nvarchar(max) = cast(@xml as nvarchar(max))


EXECUTE @RC = [dbo].[ar_sp_StoreOrderUpdateForIntegration] 
   @i_TraceOn
  ,@i_Stream
  ,@i_UserCode
  ,@i_Data

go



