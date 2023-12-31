-- подключаем базу 
use cen_test3 
-- отключаем подсчет строк
set nocount on
-- удаление временной таблицы с результатами поиска
drop table if EXISTS #Results
/*
	_Reference57	- имя таблицы в mssql справочник Организации - пример _Reference57
	_IDRRef 		- ссылка на организаций, которую следует удалить - пример 0x857B00142A2E298811DDCDAF49CDF26D	
*/

-- просто убедиться, что удаляяем, то, что нужно 
select * from _Reference57 where _IDRRef = 0x857B00142A2E298811DDCDAF49CDF26D

declare @TableName nvarchar(256), @ColumnName nvarchar(128), @ColID  nvarchar(128), @TestSQL nvarchar(256)

CREATE TABLE #Results (TabName nvarchar(256), TabColumn nvarchar(128))

-- поиск ссылок 
declare cursor_tabels cursor for select TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
	open cursor_tabels 
		fetch next from cursor_tabels into @TableName
		while @@FETCH_STATUS = 0 
		begin
			declare cursor_clumns cursor for select COLUMN_NAME from INFORMATION_SCHEMA.COLUMNS where DATA_TYPE in ('binary') and CHARACTER_MAXIMUM_LENGTH = 16 and TABLE_NAME = @TableName 
				open cursor_clumns fetch next from cursor_clumns into @ColumnName 
					while @@FETCH_STATUS = 0 
						begin
							INSERT INTO #Results exec ('select ' +'''' + @TableName + '''' + ', ' + '''' + @ColumnName + '''' + ' from ' + '' + @TableName + '' +' where ' + @ColumnName + ' = 0x857B00142A2E298811DDCDAF49CDF26D')   			
							fetch next from cursor_clumns into @ColumnName
						end
				close cursor_clumns
			DEALLOCATE cursor_clumns  

		fetch next from cursor_tabels into @TableName
		end
	close cursor_tabels
DEALLOCATE cursor_tabels

SELECT count(*) as [Количество записей для удаления] FROM #Results

-- удаляем найденые записи по всей базе
begin transaction
	declare cursor_delete cursor for select TabName, TabColumn from #Results group by TabName, TabColumn  
	open cursor_delete fetch next from cursor_delete into @TableName, @ColumnName
		while @@FETCH_STATUS = 0 
			begin
				-- условие, не удалять саму организацию из справочника Организации, для проверки и поиска ссылок
				if @TableName <> '_Reference57'
					exec ('delete from ' + '' + @TableName + '' +' where ' + @ColumnName + ' = 0x857B00142A2E298811DDCDAF49CDF26D')  
				fetch next from cursor_delete into @TableName, @ColumnName
			end
	close cursor_delete
	DEALLOCATE cursor_delete 
commit transaction

drop table if EXISTS #Results

print('Удаление завершено!')

	              
