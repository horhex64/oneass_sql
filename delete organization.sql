-- подключаем базу 
use [copy]

set nocount on 
/*
	for sql server 2008
*/
if OBJECT_ID('tempdb..#Results') IS NOT NULL drop table #Results
if OBJECT_ID('tempdb..#Links') IS NOT NULL drop table #Links
if OBJECT_ID('tempdb..#Results_group') IS NOT NULL drop table #Results_group
/*
	else 
*/
--drop table if EXISTS #Results
--drop table if EXISTS #Links
--drop table if EXISTS #Results_group

declare @TableName nvarchar(256), @ColumnName nvarchar(128), @ColID  nvarchar(128), @id_for_delete binary(16)
declare @id_to_string NVARCHAR(max)
declare @dt datetime, @zopa datetime
declare @org_count INTEGER, @del_done INTEGER

-- ссылки на организации, которые нужно удалить
CREATE TABLE #Links (rfs_id binary(16))
/*
	Установка параметров:
	1. _Reference141 - таблица с сылками на организации
	2. _IDRRef - ссылка на организацию, которую необходимо сохранить
*/
insert into #Links (rfs_id) select _IDRRef from _Reference141 where _IDRRef <> 0xA12800155D04D31011ECF1EFD5CA0246
/*
	Начало начал
*/
set @org_count = select count(*) from #Links 
set @del_done = 0

-- организации, котры будут удалены
select a.rfs_id, b._Description from #Links a, _Reference141 b where b._IDRRef = a.rfs_id

declare cursor_orgiya cursor for select rfs_id from #Links
	open cursor_orgiya
		fetch next from cursor_orgiya into @id_for_delete
		while @@FETCH_STATUS = 0
		begin
			set @id_to_string = convert(NVARCHAR(max), @id_for_delete, 1)
			set @dt = CURRENT_TIMESTAMP
			CREATE TABLE #Results (TabName nvarchar(256), TabColumn nvarchar(128))
			CREATE TABLE #Results_group (TabName nvarchar(256), TabColumn nvarchar(128))
			declare cursor_tabels cursor for select TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
				open cursor_tabels 
					fetch next from cursor_tabels into @TableName
					while @@FETCH_STATUS = 0 
					begin
						declare cursor_clumns cursor for select COLUMN_NAME from INFORMATION_SCHEMA.COLUMNS where DATA_TYPE in ('binary') and CHARACTER_MAXIMUM_LENGTH = 16 and TABLE_NAME = @TableName 
							open cursor_clumns fetch next from cursor_clumns into @ColumnName 
								while @@FETCH_STATUS = 0 
									begin
										INSERT INTO #Results exec ('select ' +'''' + @TableName + '''' + ', ' + '''' + @ColumnName + '''' + ' from ' + @TableName +' where ' + @ColumnName + ' = ' + @id_to_string)   			
										fetch next from cursor_clumns into @ColumnName
									end
							close cursor_clumns
						DEALLOCATE cursor_clumns  

					fetch next from cursor_tabels into @TableName
					end
				close cursor_tabels
			DEALLOCATE cursor_tabels

			INSERT INTO #Results_group select distinct TabName, TabColumn from #Results
			--drop table if EXISTS #Results
			if OBJECT_ID('tempdb..#Results') IS NOT NULL drop table #Results

			begin transaction
				declare cursor_delete cursor for select TabName, TabColumn from #Results_group group by TabName, TabColumn  
				open cursor_delete fetch next from cursor_delete into @TableName, @ColumnName
					while @@FETCH_STATUS = 0 
						begin
							exec ('delete from ' + '' + @TableName + '' +' where ' + @ColumnName + ' = ' + @id_to_string)  
							fetch next from cursor_delete into @TableName, @ColumnName
						end
				close cursor_delete
				DEALLOCATE cursor_delete 
			commit transaction

			-- информация о ходе выполнения запроса
			set @zopa = CURRENT_TIMESTAMP
			set @del_done = @del_done + 1
			SELECT 
				count(*) as [Найдено таблиц с данными], 
				DATEDIFF(MINUTE, @dt, @zopa) as [Затрачено на удаление мин.],
				@id_for_delete as [id Организации],
				(select _Description from _Reference141 b where _IDRRef = @id_for_delete) as [Наименование]	
				(@del_done * 100)/@org_count as [Выполнено %] 
			FROM #Results_group, 
			/*
				for sql 2008
			*/
			if OBJECT_ID('tempdb..#Results_group') IS NOT NULL drop table #Results_group
			/*
				else 
			*/
			-- drop table if EXISTS #Results_group			
		fetch next from cursor_orgiya into @id_for_delete
		end
	close cursor_orgiya
DEALLOCATE cursor_orgiya

/*
	for sql server 2008
*/
if OBJECT_ID('tempdb..#Links') IS NOT NULL drop table #Links
/*
	else
*/
--drop table if EXISTS #Links

print('Удаление завершено!')