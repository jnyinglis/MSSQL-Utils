create schema [jni]
go
drop procedure jni.DropModule
go
create procedure jni.DropModule
@module varchar(100)
as
begin
	declare @drops as nvarchar(max) = '';

	select @drops = @drops + 'drop function jni.['+name+'];print ''dropping function jni.[' + name + ']'';'
	from sys.objects
	where
		name like @module+'.%'
		and type in ('TF', 'FN', 'IF')
	;

	select @drops = @drops + 'drop procedure jni.['+name+'];print ''dropping procedure jni.[' + name + ']'';'
	from sys.objects
	where
		name like @module+'.%'
		and type in ('P')
	;

	select @drops = @drops + 'drop type jni.[' + name + '];print ''dropping type jni.[' + name + ']'';'
	from sys.types
	where
		name like  @module+'.%'
	;

	select @drops = @drops + 'drop xml schema collection jni.[' + name + '];print ''dropping xml schema collection jni.[' + name + ']'';'
	from sys.xml_schema_collections
	where name like  @module+'.%'
	;
	exec sp_executesql @drops
	;
end