/*- Entity Module

-*/

declare @module as varchar(100) = 'Entity';

exec jni.DropModule @module;

go

create xml schema collection jni.[Entity.XSD] as
'<?xml version="1.0"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified" attributeFormDefault="unqualified">
	<xs:element name="Entity" type="ParentEntityType"/>

	<xs:complexType name="ParentEntityType">
		<xs:sequence>
			<xs:element name="Parameters" type="ParametersType" minOccurs="0" maxOccurs="1"/>
			<xs:element name="Columns" type="ColumnsType" minOccurs="0" maxOccurs="1"/>
			<xs:element name="Uses" type="UsesType" minOccurs="0" maxOccurs="1"/>
			<xs:element name="TreeDependencies" type="TreeDependenciesType" minOccurs="0" maxOccurs="1"/>
			<xs:element name="FlatDependencies" type="FlatDependenciesType" minOccurs="0" maxOccurs="1"/>
		</xs:sequence>
		<xs:attribute name="entity_name" type="xs:string" use="required"/>
		<xs:attribute name="type_name" type="xs:string" use="required"/>
		<xs:attribute name="type" type="xs:string" use="required"/>
	</xs:complexType>

	<xs:complexType name="ParametersType">
		<xs:sequence>
			<xs:element name="Parameter" type="ParameterType" minOccurs="0" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

	<xs:complexType name="ParameterType">
		<xs:attribute name="ordinal_position" type="xs:string" use="required"/>
		<xs:attribute name="parameter_mode" type="xs:string" use="required"/>
		<xs:attribute name="is_result" type="xs:string" use="required"/>
		<xs:attribute name="parameter_name" type="xs:string" use="required"/>
		<xs:attribute name="type" type="xs:string" use="required"/>
		<xs:attribute name="data_type" type="xs:string" use="required"/>
		<xs:attribute name="character_maximum_length" type="xs:string" use="optional"/>
		<xs:attribute name="numeric_precision" type="xs:string" use="optional"/>
		<xs:attribute name="numeric_scale" type="xs:string" use="optional"/>
	</xs:complexType>

	<xs:complexType name="ColumnsType">
		<xs:sequence>
			<xs:element name="Column" type="ColumnType" minOccurs="0" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

	<xs:complexType name="ColumnType">
		<xs:attribute name="ordinal_position" type="xs:string" use="required"/>
		<xs:attribute name="column_name" type="xs:string" use="required"/>
		<xs:attribute name="is_nullable" type="xs:string" use="required"/>
		<xs:attribute name="type" type="xs:string" use="required"/>
		<xs:attribute name="data_type" type="xs:string" use="required"/>
		<xs:attribute name="character_maximum_length" type="xs:string" use="optional"/>
		<xs:attribute name="numeric_precision" type="xs:string" use="optional"/>
		<xs:attribute name="numeric_scale" type="xs:string" use="optional"/>
	</xs:complexType>
	
	<xs:complexType name="TreeDependenciesType">
		<xs:sequence>
			<xs:element name="Entity" type="ChildEntityType" minOccurs="0" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

	<xs:complexType name="FlatDependenciesType">
		<xs:sequence>
			<xs:element name="Entity" type="ChildEntityType" minOccurs="0" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

	<xs:complexType name="EntityType">
		<xs:attribute name="entity_name" type="xs:string" use="required"/>
		<xs:attribute name="type_name" type="xs:string" use="optional"/>
		<xs:attribute name="type" type="xs:string" use="optional"/>
		<xs:attribute name="usage_count" type="xs:string" use="optional"/>
	</xs:complexType>

	<xs:complexType name="ChildEntityType">
		<xs:complexContent>
			<xs:extension base="EntityType">
				<xs:sequence>
					<xs:element name="Uses" type="UsesType" minOccurs="0" maxOccurs="1"/>
					<xs:element name="UsedBy" type="UsedByType" minOccurs="0" maxOccurs="1"/>
				</xs:sequence>
			</xs:extension>
		</xs:complexContent>
	</xs:complexType>

	<xs:complexType name="UsesType">
		<xs:sequence>
			<xs:element name="Entity" type="ChildEntityType" minOccurs="1" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

	<xs:complexType name="UsedByType">
		<xs:sequence>
			<xs:element name="Entity" type="EntityType" minOccurs="1" maxOccurs="unbounded"/>
		</xs:sequence>
	</xs:complexType>

</xs:schema>'
;
go
create function jni.[Entity.Definition](
@entity_name as nvarchar(1000)
)
returns xml(jni.[Entity.XSD])
--returns xml
as
begin
	declare @object_id int = object_id(@entity_name);
	declare @resultTbl as table (
		xmlResult xml
	);

	with
		--
		-- List of object type descriptions and mnemonic type
		-- e.g. U - user table, V - view
		--
		object_types ([type], [type_name])
		as (
			select	SUBSTRING([name], 1, 2) collate catalog_default as [type],
					SUBSTRING([name], 5, 66) as [type_name]
			  from	[master].dbo.spt_values
			 where	[type] = 'O9T'
			   and	number = -1
		)
		,
		--
		-- List of every object in the database, embellished with a type description
		--
		[all_objects] ([object_id], schemaname_objectname, [type_name], [type])
		as (
			select	[objects].[object_id],
					([schemas].[name] + '.' + [objects].[name]) as schemaname_objectname,
					[object_types].[type_name],
					[object_types].[type]
			from	sys.objects
					inner join sys.schemas
						on [schemas].[schema_id] = [objects].[schema_id]
					inner join object_types
						on [object_types].[type] = [objects].[type]
			union all
			select	xml_collection_id,
					name,
					'xml schema',
					'XS'
			  from	sys.xml_schema_collections
			union all
			select	-1,
					NULL,
					'Unresolved Entity',
					'UE'
		)
		,
		--
		-- Find all referenced entities (recursively), using the passed in @entity_name, converted to @object_id.
		--
		[all_referenced_objects] (referencing_entity_name, referencing_schema, referencing_id, referenced_id, referenced_schema_name, referenced_entity_name, referenced_type_name, referenced_type, Level, FullPath)
		as (
			select	object_name(sed.referencing_id) as referencing_entity_name,
					schema_name(sed.referencing_id) as referencing_schema,
					sed.referencing_id,
					coalesce(sed.referenced_id, object_id(sed.referenced_entity_name)) as referenced_id,
					sed.referenced_schema_name,
					sed.referenced_entity_name,
					o.[type_name] as referenced_type_name,
					o.[type] as referenced_type,
					0 as Level,
					cast(object_name(sed.referencing_id) + '/' + sed.referenced_entity_name as varchar(max)) as FullPath
			  from	sys.sql_expression_dependencies sed
					inner join [all_objects] o
						on o.object_id = coalesce(sed.referenced_id, object_id(sed.referenced_entity_name), -1)
			 where	sed.referencing_id = @object_id
			union all
			select	object_name(sed.referencing_id) as referencing_entity_name,
					schema_name(sed.referencing_id) as referencing_schema,
					sed.referencing_id,
					coalesce(sed.referenced_id, object_id(sed.referenced_entity_name)) as referenced_id,
					sed.referenced_schema_name,
					sed.referenced_entity_name,
					o.[type_name] as referenced_type_name,
					o.[type] as referenced_type,
					Level + 1,
					cast(FullPath + '/' + sed.referenced_entity_name as varchar(max))
			  from	sys.sql_expression_dependencies sed
					inner join [all_objects] o
						on o.object_id = coalesce(sed.referenced_id, object_id(sed.referenced_entity_name), -1)
					inner join all_referenced_objects ao
						on ao.referenced_id = sed.referencing_id
			 where	sed.referencing_minor_id = 0
		),
		--
		-- Referened objects can occur multiple times, find the distinct list including their usage count
		--
		distinct_referenced_objects (referenced_entity_name, referenced_id, referenced_type_name, referenced_type, usage_count)
		as (
			select	case when referenced_type = 'UE' then referencing_entity_name + '.' + referenced_entity_name else referenced_entity_name end as referenced_entity_name,
					referenced_id,
					referenced_type_name,
					referenced_type,
					count(*) as usage_count
			  from	all_referenced_objects
			group by case when referenced_type = 'UE' then referencing_entity_name + '.' + referenced_entity_name else referenced_entity_name end,
					referenced_id,
					referenced_type_name,
					referenced_type
		),
		--
		-- List of distinct referenced objects but including two XML elements. One holding the objects that it uses, and the other that it is used by.
		-- This is used in constructing the final XML document.
		--
		distinct_referenced_objects_uses (referenced_entity_name, referenced_id, referenced_type_name, referenced_type, usage_count, Uses, UsedBy)
		as (
			select	dos.referenced_entity_name,
					dos.referenced_id,
					dos.referenced_type_name,
					dos.referenced_type,
					dos.usage_count,
					(
						select	--object_name(sedc.referencing_id) as '@referencing_entity_name',
								--sedc.referencing_id as '@referencing_id',
								--coalesce(sedc.referenced_id, object_id(sedc.referenced_entity_name)) as '@referenced_id',
								--sedc.referenced_schema_name '@schema_name',
								case when oc.[type] = 'UE' then object_name(sedc.referencing_id) + '.' + sedc.referenced_entity_name else sedc.referenced_entity_name end '@entity_name',
								--coalesce(sedc.referenced_id, object_id(sedc.referenced_entity_name)) as '@object_id',
								--sedc.referenced_minor_id as '@minor_id',
								--sedc.is_caller_dependent as '@is_caller_dependent',
								--sedc.is_ambiguous as '@is_ambiguous',
								--oc.schemaname_objectname as '@schemaname_objectname',
								oc.[type_name] as '@type_name',
								oc.[type] as '@type'
							from	sys.sql_expression_dependencies sedc
								inner join [all_objects] oc
									on oc.object_id = coalesce(sedc.referenced_id, object_id(sedc.referenced_entity_name), -1)
							where	sedc.referencing_id  = dos.referenced_id
							and	sedc.referencing_minor_id = 0
						for xml path('Entity'), type
					) as Uses,
					(
						select	o.referencing_entity_name as '@entity_name',
								count(*) as '@usage_count'
						  from	all_referenced_objects o
						 where	o.referenced_id = dos.referenced_id
						group by o.referencing_entity_name
						for xml path('Entity'), type
					) as UsedBy
			  from	distinct_referenced_objects dos
		),
		--
		-- This is a hack, part 1. Generate an XML hierarchy of dependency usage
		--
		xml_tree_snippets
		as (
			select	t1.*,
					case
						-- first and only reference
						when Level = 0 and PrevLevel is null and NextLevel is null then '<Entity entity_name="' + referenced_entity_name + '" type_name="'+referenced_type_name+'" type="'+referenced_type+'"/>'
						-- first reference in the list, more expected
						when Level = 0 and PrevLevel is null then '<Entity entity_name="' + referenced_entity_name + '" type_name="'+referenced_type_name+'" type="'+referenced_type+'"><Uses>'
						-- last reference in the list
						when Level = 0 and NextLevel is null then replicate('</Uses></Entity>', (PrevLevel-Level)+1) + '<Entity entity_name="' + referenced_entity_name + '" type_name="'+referenced_type_name+'" type="'+referenced_type+'"></Entity>'
						when Level > PrevLevel then '<Entity entity_name="' + referenced_entity_name + '" type_name="'+referenced_type_name+'" type="'+referenced_type+'"><Uses>'
						when Level <= PrevLevel then replicate('</Uses></Entity>', (PrevLevel-Level)+1) + '<Entity entity_name="' + referenced_entity_name + '" type_name="'+referenced_type_name+'" type="'+referenced_type+'"><Uses>'
					end as xml_snippet
				from	(
						select	Level,
								lag(Level, 1) over(order by FullPath) PrevLevel,
								lead(Level, 1) over(order by FullPath) NextLevel,
								FullPath,
								referenced_entity_name,
								referenced_type_name,
								referenced_type
						  from	all_referenced_objects
					) t1
		
		),
		--
		-- This is a hack, part 2. Concatenate everything from xml_tree_snipperts into single XML element
		-- This is used in constructing the final XML document.
		xml_tree
		as (
			select	cast(replace(xml_string, '<Uses></Uses>', '') as xml) as xml_tree
			  from	(
						select	(
							select	xml_snippet
								from	xml_tree_snippets
							order by FullPath
							for xml path(''), type
						).value('.','NVARCHAR(MAX)') xml_string
					) t1
		)
		,
		--
		-- This is the final resulting XML document, this will, eventually, be returned by the function.
		--
		result_in_xml (XMLResult)
		as (
			select	tl.referencing_entity_name as '@entity_name',
					o.[type_name] as '@type_name',
					o.[type] as '@type',
					-- list of input parameters, if this is a function or procedure
					(
						select	p.ORDINAL_POSITION as '@ordinal_position',
								p.PARAMETER_MODE as '@parameter_mode',
								p.IS_RESULT as '@is_result',
								p.PARAMETER_NAME as '@parameter_name',
								case
									when p.DATA_TYPE in ('varchar', 'nvarchar', 'char') then p.DATA_TYPE + '(' + cast(p.CHARACTER_MAXIMUM_LENGTH as varchar(100)) + ')'
									when p.DATA_TYPE in ('numeric') then p.DATA_TYPE + '(' +  cast(p.NUMERIC_PRECISION as varchar(100)) + ',' + cast(p.NUMERIC_SCALE as varchar(100)) + ')'
									else p.DATA_TYPE
								end as '@type',
								p.DATA_TYPE as '@data_type',
								p.CHARACTER_MAXIMUM_LENGTH as '@character_maximum_length',
								p.NUMERIC_PRECISION as '@numeric_precision',
								p.NUMERIC_SCALE as '@numeric_scale'
						  from	information_schema.parameters p
						where	p.SPECIFIC_NAME = tl.referencing_entity_name
						for xml path('Parameter'), root('Parameters'), type
					),
					-- list of output columns, if this is table valued function,
					(
						select	rc.ORDINAL_POSITION as '@ordinal_position',
								rc.COLUMN_NAME as '@column_name',
								rc.IS_NULLABLE as '@is_nullable',
								case
									when rc.DATA_TYPE in ('varchar', 'nvarchar', 'char') then rc.DATA_TYPE + '(' + cast(rc.CHARACTER_MAXIMUM_LENGTH as varchar(100)) + ')'
									when rc.DATA_TYPE in ('numeric') then rc.DATA_TYPE + '(' +  cast(rc.NUMERIC_PRECISION as varchar(100)) + ',' + cast(rc.NUMERIC_SCALE as varchar(100)) + ')'
									else rc.DATA_TYPE
								end as '@type',
								rc.DATA_TYPE as '@data_type',
								rc.CHARACTER_MAXIMUM_LENGTH as '@character_maximum_length',
								rc.NUMERIC_PRECISION as '@numeric_precision',
								rc.NUMERIC_SCALE as '@numeric_scale'
						  from	information_schema.routine_columns rc
						where	rc.TABLE_NAME = tl.referencing_entity_name
						for xml path('Column'), root('Columns'), type
					),
					-- list of entities that are only directly referenced by @entity_name
					(
						select	case when ao.referenced_type = 'UE' then tl.referencing_entity_name + '.' + ao.referenced_entity_name else ao.referenced_entity_name end as '@entity_name',
								ao.referenced_type_name as '@type_name',
								ao.referenced_type as '@type'
						  from	all_referenced_objects ao
						 where	ao.referencing_id = tl.referencing_id
						for xml path('Entity'), root('Uses'), type
					),
					-- list of all entities referenced, parent-child dependencies preserved
					(
						select	xml_tree
						  from	xml_tree
					) as TreeDependencies
					,
					-- flattened list of all entities referenced
					(
						select	dos.referenced_entity_name as '@entity_name',
								dos.referenced_type_name as '@type_name',
								dos.referenced_type as '@type',
								dos.usage_count as '@usage_count',
								dos.Uses,
								dos.UsedBy
						  from	distinct_referenced_objects_uses dos
						for xml path('Entity'), root('FlatDependencies'), type
					)
			 from	(select distinct referencing_entity_name, referencing_schema, referencing_id from all_referenced_objects where level = 0 ) tl
					inner join [all_objects] o
						on o.object_id = tl.referencing_id
			for xml path('Entity'), type
		)
	insert into @resultTbl
	select XMLResult from result_in_xml
	;
	return (select XMLResult from @resultTbl);
end
;
go

