/*- Utils Module
-*/
declare @module as varchar(100) = 'Utils';

exec jni.DropModule @module;

go
/*- Utils.SequenceTable
-*/
create function jni.[Utils.SequenceTable] ()
returns table
as
return
with
  n0 as (
    select 1 as n union all select 1
  ),
  n1 as (
    select 1 as n from n0 as a cross join n0 as b
  ),
  n2 as (
    select 1 as n from n1 as a cross join n1 as b
  ),
  n3 as (
    select 1 as n from n2 as a cross join n2 as b
  ),
  n4 as (
    select 1 as n from n3 as a cross join n3 as b
  ),
  n5 as (
    select 1 as n from n4 as a cross join n4 as b
  )
select row_number() over(order by n) as n
from n5
;
go
