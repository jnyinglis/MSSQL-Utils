/*- Sampling Module
-*/
declare @module as varchar(100) = 'Sampling';

exec jni.DropModule @module;

go
create type jni.[Sampling.TextType] as table
(
	Id int identity(1,1) not null,
	Text varchar(max) not null,
	primary key(Id)
)
;
go
create function jni.[Sampling.TextToProbability] (
@text as jni.[Sampling.TextType] readonly)
returns xml
as
begin
	declare @top as int = (select (count(*)/10000)+1 from @text);
	declare @textConcatenated as varchar(max) = 
	(
		select TextConcatPartial
			from	(
					select top (@top) ((n-1)*10000)+1 fromId, n*10000 toID
					from jni.[Utils.SequenceTable]()
				) t1
				cross apply (
					select (select	[Text]
								from	@text t
								where	t.Id between t1.fromId and t1.toID
							for xml path(''), type
							).value('.', 'VARCHAR(MAX)') TextConcatPartial
				) t2
		for xml path(''), type
	).value('.', 'VARCHAR(MAX)');
	
	return (
		select	row_number() over(order by (select NULL)) as '@BinNumber',
				count(*) as '@BinWeight',
				value as '@Outcome'
		from string_split(@textConcatenated, ' ')
		where RTRIM(value) <> ''
		group by value
		for xml path('Id'), root('Probability'), type
	);
end
go
