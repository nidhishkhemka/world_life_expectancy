# identifying duplicates
SELECT
	CONCAT(Country,Year), 
	COUNT(CONCAT(Country,Year)) as cnt
FROM world_life_expectancy
GROUP BY CONCAT(Country,Year)
HAVING cnt > 1
;

# getting Row_ID of duplicate values
SELECT Row_ID 
FROM (
	SELECT Row_ID,
	ROW_NUMBER() OVER(PARTITION BY CONCAT(Country,Year) ORDER BY Row_ID) as row_num
	FROM world_life_expectancy
    ) as Row_table
WHERE row_num>1
;

# deleting duplicates using row values from above query
DELETE FROM world_life_expectancy
WHERE Row_ID IN (
	SELECT Row_ID
	FROM (
		SELECT Row_ID, ROW_NUMBER() OVER(PARTITION BY  CONCAT(Country,Year)) as row_num
		FROM world_life_expectancy
		) AS Row_table
	WHERE row_num>1
) 
;

# identifying where Status = ''
SELECT *
FROM world_life_expectancy
WHERE Status = ''
;

# this should work, but is not, because MySQL has a limitation that prevents directly updating a table that is also being referenced in a subquery within the same UPDATE statement. 
# you can't specify target table 'world_life_expectancy' for update in FROM clause.
UPDATE world_life_expectancy 
SET Status = 'Developing'
WHERE Country IN (
	SELECT DISTINCT(Country)
	FROM world_life_expectancy 
	WHERE Status = 'Developing'
)
;

# in this query the above issue is resolved since you are creating a derived table first which is being referenced in the FROM clause, instead of the table being updated.
UPDATE world_life_expectancy
SET Status = 'Developing'
WHERE Status = '' AND Country IN (
	SELECT Country 
	FROM (
		SELECT DISTINCT(Country)
		FROM world_life_expectancy
		WHERE Status = 'Developing'
	) as temp_table
) 
;

# repeating the above query for countries with Status = 'Developed'
UPDATE world_life_expectancy
SET Status = 'Developed'
WHERE Status = '' AND Country IN (
	SELECT Country 
	FROM (
		SELECT DISTINCT(Country)
		FROM world_life_expectancy
		WHERE Status = 'Developed'
	) as temp_table
) 
;

# checking for rows where `Life expectancy` = ''
# use back-ticks for column name
SELECT *
FROM world_life_expectancy
WHERE `Life expectancy` = ''
;

# to update empty value of `Life expectancy` for a given year, we will take the average of `Life expectancy` of the year before and the year after that year.
UPDATE world_life_expectancy t1
SET `Life expectancy` = ROUND(((SELECT `Life expectancy` FROM (select * from world_life_expectancy) as t2 WHERE t1.Year = (t2.Year+1) AND t1.Country = t2.Country)
			 + (SELECT `Life expectancy` FROM (select * from world_life_expectancy) as t3 WHERE t1.Year = (t3.Year-1) AND t1.Country = t3.Country))/2,1)
WHERE t1.`Life expectancy` = ''
;

# the above query is not very optimal
# the below query is much more efficient and accounts for cases when taking average is not possible
UPDATE world_life_expectancy t1
LEFT JOIN world_life_expectancy t2 ON t1.Year = (t2.Year + 1) AND t1.Country = t2.Country
LEFT JOIN world_life_expectancy t3 ON t1.Year = (t3.Year - 1) AND t1.Country = t3.Country
SET t1.`Life expectancy` = 
    CASE
        WHEN t2.`Life expectancy` IS NOT NULL AND t2.`Life expectancy` != '' AND t3.`Life expectancy` IS NOT NULL AND t3.`Life expectancy` != '' THEN ROUND(((t2.`Life expectancy` + t3.`Life expectancy`) / 2), 1)
        WHEN (t2.`Life expectancy` IS NULL OR t2.`Life expectancy` = '') AND (t3.`Life expectancy` IS NOT NULL AND t3.`Life expectancy` != '') THEN t3.`Life expectancy`
        WHEN (t3.`Life expectancy` IS NULL OR t3.`Life expectancy` = '') AND (t2.`Life expectancy` IS NOT NULL AND t2.`Life expectancy` != '') THEN t2.`Life expectancy`
        ELSE t1.`Life expectancy` -- Keep existing value if t2 and t3 is empty
    END
WHERE t1.`Life expectancy` = ''
;



