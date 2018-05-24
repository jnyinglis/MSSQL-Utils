/*- tSQLt Module

@doc tSQLt.Template
-*/

declare @module as varchar(100) = 'tSQLt';

exec jni.DropModule @module;

go
create function jni.[tSQLt.Template] (
@entity_definition as xml(jni.[Entity.XSD]),
@procedure_name as varchar(8000)
)
returns xml
as
begin
	declare @template as varchar(max) =
'
IF EXISTS ( SELECT  name
            FROM    sysobjects
            WHERE   id      = OBJECT_ID(''[Test].Test_<PROCEDURE_NAME>'')
            AND     type    = ''P'')
BEGIN
    PRINT ''Dropping procedure [Test_<PROCEDURE_NAME>]''
    DROP PROCEDURE [Test].Test_<PROCEDURE_NAME>
END
;
PRINT ''Creating procedure [Test_<PROCEDURE_NAME>]''
;
CREATE PROCEDURE
[Test].Test_<PROCEDURE_NAME>
AS
<PARAMETERS>

<OUTPUTRESULTSET>

-------------------------------------------
Fake Tables.
-------------------------------------------
<FAKE_TABLES>

/*---------------------------------------------
Test #1
---------------------------------------------*/

BEGIN
--
-- Populate Fake Data.
--

etc, etc...
';


	declare @parameters as varchar(max);
	-- input/ouput parameters for the procedure
	select	@parameters = isnull(@parameters, '') + 'declare ' + parameter_name + ' as ' + type + ';' + char(10)
		from	(
				select
						Entities.Parameter.value('./@ordinal_position', 'varchar(1000)') AS ordinal_position,
						Entities.Parameter.value('./@parameter_mode', 'varchar(1000)') AS parameter_mode,
						Entities.Parameter.value('./@is_result', 'varchar(1000)') AS is_result,
						Entities.Parameter.value('./@parameter_name', 'varchar(1000)') AS parameter_name,
						Entities.Parameter.value('./@type', 'varchar(1000)') AS type
				from	@entity_definition.nodes('/Entity/Parameters/Parameter') Entities(Parameter)
			) t1

	declare @outputresultset as varchar(max);

	declare @fake_tables as varchar(max);
	select	@fake_tables = isnull(@fake_tables, '') + 'EXEC tSQLt.FakeTable @TableName = ''' + entity_name + '''' + char(10)  
		from	(
				-- all objects used by the procedure, including all child objects
		  		select	
						Entities.Entity.value('./@entity_name', 'varchar(1000)') AS entity_name,
						Entities.Entity.value('./@type_name', 'varchar(1000)') AS type_name,
						Entities.Entity.value('./@type', 'varchar(1000)') AS type
				from	@entity_definition.nodes('/Entity/FlatDependencies/Entity') Entities(Entity)
			) t1
		where	type in ('U')

	--select	*
	--  from	(
	--		-- objects used by the procedure directly, does not include child objects
	--		select	
	--				Entities.Entity.value('./@entity_name', 'varchar(1000)') AS entity_name,
	--				Entities.Entity.value('./@type_name', 'varchar(1000)') AS type_name,
	--				Entities.Entity.value('./@type', 'varchar(1000)') AS type
	--		from	@entity_definition.nodes('/Entity/Uses/Entity') Entities(Entity)
	--		) t1
	--  where	type in ('U')

	declare @result as varchar(max) = isnull(@template, '');
	set @result = replace(@result, '<PROCEDURE_NAME>', isnull(@procedure_name, ''));
	set @result = replace(@result, '<PARAMETERS>', isnull(@parameters, ''));
	set @result = replace(@result, '<OUTPUTRESULTSET>', isnull(@outputresultset, ''));
	set @result = replace(@result, '<FAKE_TABLES>', isnull(@fake_tables, ''));
	declare @resultXML as xml = (
		select @result as [text()]
		for xml path('')
	);
	return @resultXML;
end
;
go
