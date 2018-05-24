/*- Probability Module
-*/
declare @module as varchar(100) = 'Probability';

exec jni.DropModule @module;

go
create xml schema collection jni.[Probability.XSD] as
'<?xml version="1.0"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified" attributeFormDefault="unqualified">
	<xs:element name="Probability" type="ProbabilityType"/>

	<xs:complexType name="ProbabilityType">
		<xs:sequence>
			<xs:element name="Id" type="IdTypeIn" minOccurs="1" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

	<xs:complexType name="IdTypeIn">
		<xs:attribute name="BinNumber" type="xs:positiveInteger" use="required"/>
		<xs:attribute name="BinWeight" type="xs:decimal" use="required"/>
		<xs:attribute name="Outcome" type="xs:string" use="required"/>
	</xs:complexType>
</xs:schema>
'
go
create xml schema collection jni.[Probability.XSDCompiled] as
'<?xml version="1.0"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified" attributeFormDefault="unqualified">
	<xs:element name="Probability" type="ProbabilityType"/>

	<xs:complexType name="ProbabilityType">
		<xs:sequence>
			<xs:element name="Id" type="IdTypeOut" minOccurs="1" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

	<xs:complexType name="IdTypeOut">
		<xs:attribute name="BinNumber" type="xs:positiveInteger" use="required"/>
		<xs:attribute name="BinWeight" type="xs:decimal" use="required"/>
		<xs:attribute name="Outcome" type="xs:string" use="required"/>
		<xs:attribute name="FromInterval" type="xs:decimal" use="required"/>
		<xs:attribute name="ToInterval" type="xs:decimal" use="required"/>
		<xs:attribute name="Chance" type="xs:decimal" use="required"/>
	</xs:complexType>
</xs:schema>
'
go
/*- Probability.XMLCompiledToTable AsTableCompiledFromXMLCompiled
-*/
create function jni.[Probability.XMLCompiledToTable] (
@probabilityDistribution	AS XML(jni.[Probability.XSDCompiled]))
RETURNS TABLE
AS
RETURN
	select	t1.BinNumber,
			t1.BinWeight,
			t1.Outcome,
			t1.FromInterval,
			t1.ToInterval,
			t1.Chance
	  from	(
	  		select	Probability.Id.value('./@BinNumber', 'int') AS BinNumber,
					Probability.Id.value('./@BinWeight', 'numeric(38,12)') AS BinWeight,
					Probability.Id.value('./@Outcome', 'varchar(100)') AS Outcome,
					Probability.Id.value('./@FromInterval', 'numeric(38,12)') AS FromInterval,
					Probability.Id.value('./@ToInterval', 'numeric(38,12)') AS ToInterval,
					Probability.Id.value('./@Chance', 'numeric(38,12)') AS Chance
			  from	@probabilityDistribution.nodes('/Probability/Id') Probability(Id)
			) t1
go
create function jni.[Probability.AsOpenXMLCompiledToTable] (
@id	AS int)
returns @return table
(
	BinNumber int not null primary key,
	BinWeight numeric(38,12) not null,
	Outcome varchar(100) not null,
	FromInterval numeric(38,12) not null,
	ToInterval  numeric(38,12) not null,
	Chance  numeric(38,12) not null
)
as
begin
	insert into @return
		select	t1.BinNumber,
				t1.BinWeight,
				t1.Outcome,
				t1.FromInterval,
				t1.ToInterval,
				t1.Chance
		from openxml(@id, '/Probability/Id', 1) WITH 
					(BinNumber		int,
					BinWeight		numeric(38,12),
					Outcome			varchar(100),
					FromInterval	numeric(38,12),
					ToInterval		numeric(38,12),
					Chance			numeric(38,12)) t1;
	return;
end
go
/*- Probability.Bin
-*/
create function jni.[Probability.Bin] (
@probabilityDistribution	AS XML(jni.[Probability.XSDCompiled]),
@sv_id int,
@pm_index int)
returns int
as
begin
	--declare @rand as numeric(38,12) = (select sum(r)%1 from (select top (@pm_index) jni.[Statistics.HDRUniform](@sv_id, n) as r from jni.[Utils.SequenceTable]()) t1);
	declare @rand as numeric(38,12) = jni.[Statistics.HDRUniform](@sv_id, @pm_index);
	return (
		select	BinNumber
		  from	(
			select	Probability.Id.value('./@BinNumber', 'int') AS BinNumber,
					Probability.Id.value('./@BinWeight', 'numeric(38,12)') AS BinWeight,
					Probability.Id.value('./@Outcome', 'varchar(100)') AS Outcome,
					Probability.Id.value('./@FromInterval', 'numeric(38,12)') AS FromInterval,
					Probability.Id.value('./@ToInterval', 'numeric(38,12)') AS ToInterval,
					Probability.Id.value('./@Chance', 'numeric(38,12)') AS Chance
			  from	@probabilityDistribution.nodes('/Probability/Id') Probability(Id)
			) t1
		 where	@rand between FromInterval and ToInterval
	)
end
go
/*- Probability.Outcome
-*/
create function jni.[Probability.Outcome] (
@probabilityDistribution	AS XML(jni.[Probability.XSDCompiled]),
@sv_id int,
@pm_index int)
returns varchar(100)
as
begin
	--declare @rand as numeric(38,6) = (select sum(r)%1 from (select top (@pm_index) jni.[Statistics.HDRUniform](@sv_id, n) as r from jni.[Utils.SequenceTable]()) t1);	
	declare @rand as numeric(38,6) = jni.[Statistics.HDRUniform](@sv_id, @pm_index);
	return (
		select	Outcome
		  from	(
			select	Probability.Id.value('./@BinNumber', 'int') AS BinNumber,
					Probability.Id.value('./@BinWeight', 'numeric(38,12)') AS BinWeight,
					Probability.Id.value('./@Outcome', 'varchar(100)') AS Outcome,
					Probability.Id.value('./@FromInterval', 'numeric(38,12)') AS FromInterval,
					Probability.Id.value('./@ToInterval', 'numeric(38,12)') AS ToInterval,
					Probability.Id.value('./@Chance', 'numeric(38,12)') AS Chance
			  from	@probabilityDistribution.nodes('/Probability/Id') Probability(Id)
			) t1
		 where	@rand between FromInterval and ToInterval
	)
end
go
create type jni.[Probability.TblType] as table
(
	BinNumber int not null identity(1,1),
	BinWeight numeric(38,12) not null default 1 check (BinWeight > 0),
	Outcome varchar(100) not null
)
go
create type jni.[Probability.TblCompiledType] as table
(
	BinNumber int not null unique,
	BinWeight numeric(38,12) not null,
	Outcome varchar(100) not null,
	FromInterval numeric(38,12) not null,
	ToInterval numeric(38,12) not null,
	Chance numeric(38,12) not null
	primary key(FromInterval, ToInterval)
)
go
/*- Probability.TypeToTableCompiled  AsTableCompiledFromType
-*/
create function jni.[Probability.TypeToTableCompiled](
@probabilityDistribution as jni.[Probability.TblType] readonly)
returns table
as
	return 
		select	BinNumber,
				BinWeight,
				Outcome,
				FromInterval,
				ToInterval,
				Chance
		  from	(
			select	t1.BinNumber,
					t1.BinWeight,
					t1.Outcome,
					t4.FromInterval,
					t4.ToInterval,
					(t4.ToInterval - t4.FromInterval) + case when t4.FromInterval = 0 then 0 else 0.000000000001 end as Chance
			  from	(
					select	BinNumber,
							BinWeight,
							Outcome
					  from	@probabilityDistribution
					 where	BinWeight > 0
				) t1
				inner join (
					select	BinNumber,
							isnull(lag(BinValueNormalized, 1) over(order by BinNumber)+0.000000000001, 0) FromInterval,
							BinValueNormalized as ToInterval
					  from	(
							select	t2.BinNumber,
									t2.BinWeight,
									t2.Outcome,
									--sum(t2.BinWeight) over(order by t2.BinNumber rows unbounded preceding ) / sum(t2.BinWeight) over(order by t2.BinNumber rows between unbounded preceding and unbounded following) as BinValueNormalized
									cast(cast(sum(t2.BinWeight) over(order by t2.BinNumber rows unbounded preceding ) as numeric(24,12))
										/ cast(sum(t2.BinWeight) over(order by t2.BinNumber rows between unbounded preceding and unbounded following) as numeric(24,12)) as numeric(38,12)) as BinValueNormalized
							  from	(
										select	BinNumber,
												BinWeight,
												Outcome
										  from	@probabilityDistribution
										 where	BinWeight > 0
									) t2
							) t3
				) t4
				on t4.BinNumber = t1.BinNumber
			) Id;
go
/*- Probability.TblOutcome
-*/
create function jni.[Probability.TblOutcome] (
@probabilityDistribution	AS jni.[Probability.TblCompiledType] readonly,
@sv_id int,
@pm_index int)
returns varchar(100)
as
begin
	--declare @rand as numeric(38,6) = (select sum(r)%1 from (select top (@pm_index) jni.[Statistics.HDRUniform(@sv_id, n) as r from jni.[Utils.SequenceTable]()) t1);
	declare @rand as numeric(38,8) = jni.[Statistics.HDRUniform](@sv_id, @pm_index);
	return (
		select	Outcome
		  from	(
			select	BinNumber,
					BinWeight,
					Outcome,
					FromInterval,
					ToInterval,
					Chance
			  from	@probabilityDistribution
			) t1
		 where	@rand between FromInterval and ToInterval
	)
end
go
/*- Probability.XMLtoTable AsTableFromXML
-*/
create function jni.[Probability.XMLtoTable] (
@probabilityDistribution	AS XML(jni.[Probability.XSD]))
returns @return table
(
	BinNumber int not null primary key,
	BinWeight numeric(38,12) not null,
	Outcome varchar(100) not null
)
as
begin
	insert into @return
		select	Probability.Id.value('./@BinNumber', 'int') AS BinNumber,
				Probability.Id.value('./@BinWeight', 'numeric(38,12)') AS BinWeight,
				Probability.Id.value('./@Outcome', 'varchar(100)') AS Outcome
		  from	@probabilityDistribution.nodes('/Probability/Id') Probability(Id);
	return;
end
go
/*- Probability.XMLtoTable2
-*/
create function jni.[Probability.AsOpenXMLtoTable] (
@id	AS int)
returns @return table
(
	BinNumber int not null primary key,
	BinWeight numeric(38,12) not null,
	Outcome varchar(100) not null
)
as
begin
	insert into @return
		 select	t1.BinNumber,
				t1.BinWeight,
				t1.Outcome
		   from openxml(@id, '/Probability/Id', 1) WITH 
					(BinNumber		int,
					BinWeight		numeric(38,12),
					Outcome			varchar(100)) t1;
	return;
end
go
/*- Probability.XMLtoTableCompiled AsTableCompiledFromXML
-*/
create function jni.[Probability.XMLtoTableCompiled] (
@probabilityDistribution	AS XML(jni.[Probability.XSD]))
returns table
	return 
		select	BinNumber,
				BinWeight,
				Outcome,
				FromInterval,
				ToInterval,
				Chance
		  from	(
			select	t1.BinNumber,
					t1.BinWeight,
					t1.Outcome,
					t4.FromInterval,
					t4.ToInterval,
					(t4.ToInterval - t4.FromInterval) + case when t4.FromInterval = 0 then 0 else 0.000000000001 end as Chance
			  from	(
					select * from jni.[Probability.XMLtoTable](@probabilityDistribution)
					--select	Probability.Id.value('./@BinNumber', 'int') AS BinNumber,
					--		Probability.Id.value('./@BinWeight', 'numeric(38,12)') AS BinWeight,
					--		Probability.Id.value('./@Outcome', 'varchar(100)') AS Outcome
					--  from	@probabilityDistribution.nodes('/Probability/Id') Probability(Id)
				) t1
				inner join (
					select	BinNumber,
							isnull(lag(BinValueNormalized, 1) over(order by BinNumber)+0.000000000001, 0) FromInterval,
							BinValueNormalized as ToInterval
					  from	(
							select	t2.BinNumber,
									t2.BinWeight,
									t2.Outcome,
									--sum(t2.BinWeight) over(order by t2.BinNumber rows unbounded preceding ) / sum(t2.BinWeight) over(order by t2.BinNumber rows between unbounded preceding and unbounded following) as BinValueNormalized
									cast(cast(sum(t2.BinWeight) over(order by t2.BinNumber rows unbounded preceding ) as numeric(24,12))
										/ cast(sum(t2.BinWeight) over(order by t2.BinNumber rows between unbounded preceding and unbounded following) as numeric(24,12)) as numeric(38,12)) as BinValueNormalized
							  from	(
										select * from jni.[Probability.XMLtoTable](@probabilityDistribution)
										--select	Probability.Id.value('./@BinNumber', 'int') AS BinNumber,
										--		Probability.Id.value('./@BinWeight', 'numeric(38,12)') AS BinWeight,
										--		Probability.Id.value('./@Outcome', 'varchar(100)') AS Outcome
										--  from	@probabilityDistribution.nodes('/Probability/Id') Probability(Id)
									) t2
							) t3
				) t4
				on t4.BinNumber = t1.BinNumber
			) Id
go
/*- Probability.XMLtoTableCompiled2
-*/
create function jni.[Probability.AsOpenXMLtoTableCompiled] (
@id	AS int)
returns @return table
(
	BinNumber int not null primary key,
	BinWeight numeric(38,12) not null,
	Outcome varchar(100) not null,
	FromInterval numeric(38,12) not null,
	ToInterval  numeric(38,12) not null,
	Chance  numeric(38,12) not null
)
as
begin
	insert into @return
		select	BinNumber,
				BinWeight,
				Outcome,
				FromInterval,
				ToInterval,
				Chance
		  from	(
			select	t1.BinNumber,
					t1.BinWeight,
					t1.Outcome,
					t4.FromInterval,
					t4.ToInterval,
					(t4.ToInterval - t4.FromInterval) + case when t4.FromInterval = 0 then 0 else 0.000000000001 end as Chance
			  from	(
					select * from jni.[Probability.AsOpenXMLtoTable](@id)
				) t1
				inner join (
					select	BinNumber,
							isnull(lag(BinValueNormalized, 1) over(order by BinNumber)+0.000000000001, 0) FromInterval,
							BinValueNormalized as ToInterval
					  from	(
							select	t2.BinNumber,
									t2.BinWeight,
									t2.Outcome,
									--sum(t2.BinWeight) over(order by t2.BinNumber rows unbounded preceding ) / sum(t2.BinWeight) over(order by t2.BinNumber rows between unbounded preceding and unbounded following) as BinValueNormalized
									cast(cast(sum(t2.BinWeight) over(order by t2.BinNumber rows unbounded preceding ) as numeric(24,12))
										/ cast(sum(t2.BinWeight) over(order by t2.BinNumber rows between unbounded preceding and unbounded following) as numeric(24,12)) as numeric(38,12)) as BinValueNormalized
							  from	(
										select * from jni.[Probability.AsOpenXMLtoTable](@id)
									) t2
							) t3
				) t4
				on t4.BinNumber = t1.BinNumber
			) Id;
	return;
end
go
/*- Probability.BernoulliTbl
-*/
create function jni.[Probability.BernoulliTbl](
@p	numeric(6,6)
)
returns @return table
(
	BinNumber int not null unique,
	BinWeight numeric(38,12) not null,
	Outcome varchar(100) not null,
	FromInterval numeric(38,12) not null,
	ToInterval numeric(38,12) not null,
	Chance numeric(38,12) not null
	primary key(FromInterval, ToInterval)
)
as
begin
	declare @p1 numeric(6,6) = 1 - @p

	insert into @return
		select * from jni.[Probability.XMLtoTableCompiled](
			(
				select	*
				  from	(
						select	1	as '@BinNumber',
								@p	as '@BinWeight',
								1	as '@Outcome'
						union all
						select	2	as '@BinNumber',
								@p1	as '@BinWeight',
								0	as '@Outcome'
						) t1
				for xml path('Id'), root('Probability'), type
			)
		);
	return;
end
go
/*- Probability.BinomialTbl
-*/
create function jni.[Probability.BinomialTbl](
@mean	float,
@std_dev	float)
returns @return table
(
	BinNumber int not null unique,
	BinWeight numeric(38,12) not null,
	Outcome varchar(100) not null,
	FromInterval numeric(38,12) not null,
	ToInterval numeric(38,12) not null,
	Chance numeric(38,12) not null
	primary key(FromInterval, ToInterval)
)
as
begin
--	insert into @return
	return;
end
go
/*- Probability.XMLToXMLCompiled AsXMLCompiledFromXML
-*/
create function jni.[Probability.XMLToXMLCompiled] (
@probabilityDistribution	AS XML(jni.[Probability.XSD]))
returns XML(jni.[Probability.XSDCompiled])
as
begin

	return (
		select	BinNumber,
				BinWeight,
				Outcome,
				FromInterval,
				ToInterval,
				Chance
		  from	(
			select	t1.BinNumber,
					t1.BinWeight,
					t1.Outcome,
					t4.FromInterval,
					t4.ToInterval,
					(t4.ToInterval - t4.FromInterval) + case when t4.FromInterval = 0 then 0 else 0.000000000001 end as Chance
			  from	(
					select * from jni.[Probability.XMLtoTable](@probabilityDistribution)
					--select	Probability.Id.value('./@BinNumber', 'int') AS BinNumber,
					--		Probability.Id.value('./@BinWeight', 'numeric(38,12)') AS BinWeight,
					--		Probability.Id.value('./@Outcome', 'varchar(100)') AS Outcome
					--  from	@probabilityDistribution.nodes('/Probability/Id') Probability(Id)
				) t1
				inner join (
					select	BinNumber,
							isnull(lag(BinValueNormalized, 1) over(order by BinNumber)+0.000000000001, 0) FromInterval,
							BinValueNormalized as ToInterval
					  from	(
							select	t2.BinNumber,
									t2.BinWeight,
									t2.Outcome,
									cast(cast(sum(t2.BinWeight) over(order by t2.BinNumber rows unbounded preceding ) as numeric(24,12))
										/ cast(sum(t2.BinWeight) over(order by t2.BinNumber rows between unbounded preceding and unbounded following) as numeric(24,12)) as numeric(38,12)) as BinValueNormalized
							  from	(
										select * from jni.[Probability.XMLtoTable](@probabilityDistribution)
										--select	Probability.Id.value('./@BinNumber', 'int') AS BinNumber,
										--		Probability.Id.value('./@BinWeight', 'numeric(38,12)') AS BinWeight,
										--		Probability.Id.value('./@Outcome', 'varchar(100)') AS Outcome
										--  from	@probabilityDistribution.nodes('/Probability/Id') Probability(Id)
									) t2
							) t3
				) t4
				on t4.BinNumber = t1.BinNumber
			) Id
		for xml auto, root('Probability')
	)
end
go
/*- Probability.TableCompiledToXMlCompiled
-*/
create function jni.[Probability.TableCompiledToXMLCompiled] (
@probabilityDistribution	as jni.[Probability.TblCompiledType] readonly)
returns XML(jni.[Probability.XSDCompiled])
as
begin

	return (
		select	BinNumber as '@BinNumber',
				BinWeight as '@BinWeight',
				Outcome as '@Outcome',
				FromInterval as '@FromInterval',
				ToInterval as '@ToInterval',
				Chance as '@Chance'
		  from	@probabilityDistribution
		for xml path('Id'), root('Probability')
	)
end
go
create procedure jni.[Probability.OpenXMLToTableCompiled]
@xml as xml
as
begin
	declare @id as int;
	exec sp_xml_preparedocument @id output, @xml

	declare @xmlAsTblC as jni.[Probability.TblCompiledType];

	select * from jni.[Probability.AsOpenXMLtoTableCompiled](@id);

	exec sp_xml_removedocument @id
end
--
-- Given an XML distribution this returns a 'compiled' version
-- that can be used by the other functions.
--
--Example
--
--declare @color_pd as xml = dbo.JIProbAsXML('
--<Probability>
--	<Id BinNumber="1" BinWeight="64"  Outcome="No Color"/>
--	<Id BinNumber="2" BinWeight="8"  Outcome="Black"/>
--	<Id BinNumber="3" BinWeight="8"  Outcome="White"/>
--	<Id BinNumber="4" BinWeight="2"  Outcome="Red"/>
--	<Id BinNumber="5" BinWeight="2"  Outcome="Green"/>
--	<Id BinNumber="6" BinWeight="2"  Outcome="Brown"/>
--	<Id BinNumber="7" BinWeight="1"  Outcome="Tan"/>
--	<Id BinNumber="8" BinWeight="1"  Outcome="Yellow"/>
--</Probability>')
--;
--
--declare @color_samples as int = 100;

--with
--	list as
--	(
--		select	top (@color_samples)
--			n as list_Id
--		  from	jni.[Utils.SequenceTable]()
--	),
--	colors as
--	(
--		select	dbo.JIProbOutcome(@color_pd, 1, list_id) as color_description
--		  from	list
--	)
--select	color_description,
--		count(*)
--  from	colors
--group by color_description
--order by 2 desc
--;
