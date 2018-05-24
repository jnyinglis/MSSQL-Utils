/*- Statistics Module

@doc Statistics.Mod, Statistics.HDRUniform
-*/

declare @module as varchar(100) = 'Statistics';

exec jni.DropModule @module;

go
/*- Statistics.Mod
-*/
create function jni.[Statistics.Mod] (
@dividend	bigint,
@divisor	bigint)
returns bigint
as
begin
	return (@dividend % @divisor)
end
go
/*- Statistics.HDRUniform
-*/
create function jni.[Statistics.HDRUniform] (
@sv_id	int,
@pm_index	int)
returns numeric(38,12)
as
begin
	declare @f_sv_id float = @sv_id;
	declare @f_pm_index float = @pm_index;
	return (
		jni.[Statistics.Mod](
			(
			(
				(
				jni.[Statistics.Mod]((power((@f_sv_id + 1000000), 2) + (@f_sv_id + 1000000) * (@f_pm_index + 10000000)), 99999989)
				) + 1000007
			)
			*
			(
				(
				jni.[Statistics.Mod]((power((@f_pm_index + 10000000), 2) + (@f_pm_index + 10000000) *
					(jni.[Statistics.Mod]((power((@f_sv_id + 1000000), 2) + (@f_sv_id + 1000000) * (@f_pm_index + 10000000)), 99999989 ))
					), 99999989
				)
				) + 1000013
			)
			), 2147483647
		) / 2147483647.0
	)
end
go

/*- Statistics.Normsinv
-*/
create function jni.[Statistics.Normsinv](
@p numeric(38,19)
)
returns numeric(38,19)
as
begin
	declare @a1 as numeric(38,19) = -39.696830286653757
	declare @a2 as numeric(38,19) = 220.9460984245205
	declare @a3 as numeric(38,19) = -275.92851044696869
	declare @a4 as numeric(38,19) = 138.357751867269
	declare @a5 as numeric(38,19) = -30.66479806614716
	declare @a6 as numeric(38,19) = 2.5066282774592392
 
	declare @b1 as numeric(38,19) = -54.476098798224058
	declare @b2 as numeric(38,19) = 161.58583685804089
	declare @b3 as numeric(38,19) = -155.69897985988661
	declare @b4 as numeric(38,19) = 66.80131188771972
	declare @b5 as numeric(38,19) = -13.280681552885721
 
	declare @c1 as numeric(38,19) = -0.0077848940024302926
	declare @c2 as numeric(38,19) = -0.32239645804113648
	declare @c3 as numeric(38,19) = -2.4007582771618381
	declare @c4 as numeric(38,19) = -2.5497325393437338
	declare @c5 as numeric(38,19) = 4.3746641414649678
	declare @c6 as numeric(38,19) = 2.9381639826987831

	declare @d1 as numeric(38,19) = 0.0077846957090414622
	declare @d2 as numeric(38,19) = 0.32246712907003983
	declare @d3 as numeric(38,19) = 2.445134137142996
	declare @d4 as numeric(38,19) = 3.7544086619074162

	  -- Define break-points.
	declare @low_point as numeric(38,19) = 0.02425
	declare @high_point as numeric(38,19) = 1 - @low_point

	declare @q_low as numeric(38,19) = sqrt((-2 * log(@p)))
	declare @q_central as numeric(38,19) = @p - 0.5
	declare @r as numeric(38,19) = @q_central * @q_central
	declare @q_upper as numeric(38,19) = sqrt((-2 * log(1 - @p)))
	return (
		case
		  when @p = 0 or @p = 1
			then
				0
		  when @p > 0 and @p < @low_point
			then
				-- Rational approximation for lower region.
			  (((((@c1 * @q_low + @c2) * @q_low + @c3) * @q_low + @c4) * @q_low + @c5) * @q_low + @c6) /
			  ((((@d1 * @q_low + @d2) * @q_low + @d3) * @q_low + @d4) * @q_low + 1)
		  when @p >= @low_point and @p <= @high_point
			then
				-- Rational approximation for central region.
			  (((((@a1 * @r + @a2) * @r + @a3) * @r + @a4) * @r + @a5) * @r + @a6) * @q_central /
			  (((((@b1 * @r + @b2) * @r + @b3) * @r + @b4) * @r + @b5) * @r + 1)
		  when @p > @high_point and @p < 1
			then
				-- Rational approximation for upper region.
			  -(((((@c1 * @q_upper + @c2) * @q_upper + @c3) * @q_upper + @c4) * @q_upper + @c5) * @q_upper + @c6) /
			  ((((@d1 * @q_upper + @d2) * @q_upper + @d3) * @q_upper + @d4) * @q_upper + 1)
		end
	)
end
go

/*- Statistics.Norminv
-*/
create function jni.[Statistics.Norminv](
@p float,
@mu  float,
@sigma  float)
returns numeric(38,12)
as
begin
	return (
		case @p
			when 0 then -1
			when 1 then 1
			else @mu + @sigma * jni.[Statistics.Normsinv](@p)
		end
	)
end
go

/*- Statistics.HDRNormal
-*/
create function jni.[Statistics.HDRNormal](
@sv_id	int,
@pm_index	int,
@mean	float,
@std_dev	float)
returns numeric(38,12)
as
begin
	declare @f_sv_id float = @sv_id;
	declare @f_pm_index float = @pm_index;
	return (
		case when @std_dev != 0
			then
			  jni.[Statistics.Norminv](
				jni.[Statistics.Mod](
				  ((jni.[Statistics.Mod](power((@f_sv_id+1000000), 2)+(@f_sv_id+1000000)*(@f_pm_index+10000000), 99999989)) + 1000007) *
				  ((jni.[Statistics.Mod](power((@f_pm_index + 10000000), 2) + (@f_pm_index + 10000000) * (jni.[Statistics.Mod](power((@f_sv_id + 1000000), 2) +
					(@f_sv_id + 1000000) * (@f_pm_index + 10000000), 99999989)), 99999989)) + 1000013), 2147483647
				) / 2147483647.0, @mean, @std_dev
			  )
			else
			  @mean
			end
	)
end
go
