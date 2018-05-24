-- 
declare @entity_name as varchar(8000) = 'jni.[Probability.XMLCompiledToTable2]';

-- returns the XML that contains all the entities/objects referenced by @entity_name
declare @entity_definition as xml =
	jni.[Entity.Definition](@entity_name);

select @entity_definition;

-- view the contents of the XML
select @entity_definition;

-- this function takes an XML entity definition document and returns a SQL string
-- for a tSQLt test procedure.
--
declare @output as xml =
	jni.[tSQLt.Template](
				jni.[Entity.Definition](@entity_name),
				@entity_name
	);

select @output;


