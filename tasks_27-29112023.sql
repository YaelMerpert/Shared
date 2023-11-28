/*tables
events e
    event_id int (autoincrement) --10B distinct values
    event_ts datetime -- 10B
    event_type int (1 = impression, 2 = click, 3 = purchase...) --20
    product_id int  --100K
    client_id int --10M
    client_type int --10
   
event_type_names
    event_type int
    event_name varchar(20)

products p
    product_id int
    product_name varchar(20)*/

/*Question 1:
For the following query, what are the expected outputs, how many rows, and what are the possible answers?

select clinet_type, count(distinct product_id)
from events
where product_id in (100,200) and client_type = 2 and event_ts between '2023/01/01' and '2023/10/01'
group by client_type
having  count(distinct product_id) > 100
order by 2
limit 10;*/

--###Answer###

--0 rows, filters product_id in (100,200) and count(distinct product_id) > 100  deprive us of the chance to get results


/*Pls write SQL queries for the following 
1)
find the top 3 products(product name) by the highest number of clients purchasing them!
the output should look like:

product1 1000
product2 100
product3 40*/

--###  Query 1  ###

SELECT TOP 3  p.product_name, 
              COUNT(DISTINCT e.client_id) as clients
FROM [events] e
    INNER JOIN products p  
	        ON e.product_id = p.product_id
WHERE e.event_type = 3 
GROUP BY 1
ORDER BY 2 DESC;


/*2) find clients who have seen an impression of a product before clicking on it.*/
--(1 = impression, 2 = click, 3 = purchase...)
SELECT DISTINCT e.client_id
FROM [events] e--for impression
     INNER JOIN [events] ev --for clicking
	         ON e.client_id=ev.client_id
             AND e.product_id=ev.product_id
where e.event_type=1 
  AND ev.event_type=2 
  AND e.event_ts < ev.event_ts; --impression before clicking


/*3) how many clients have bought the product after seeing the impression 1 time, 2 times, 3 times?
(the impression is counted only if it is for the product that was bought.
(1 = impression, 2 = click, 3 = purchase...)
Times_seeing_impression | num_of_clients
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1   | 120
2   | 300
3   | 320*/

SELECT Times_seeing_impression,
       COUNT(DISTINCT client_id) as num_of_clients
FROM (
       SELECT e.client_id, --times_seeing_impression for purchased events only
              e.product_id,
              COUNT(*) as Times_seeing_impression
       FROM [events] e
            INNER JOIN (SELECT client_id,  --count_impression for each event client/product
                               product_id,
                               COUNT(*) as count_impr
                        FROM [events]
                        WHERE event_type=1 
                        GROUP BY 1,2 ) ev 
					ON e.client_id=ev.client_id 
			        AND e.product_id=ev.product_id
       WHERE e.event_type=3 
       GROUP BY 1,2
       having COUNT(*)<=3 -- as on example
) as fin_tab
GROUP BY 1
ORDER BY 1

-----toooo heavy query((
/*4)
Find all products that have less than 10 clicks in the LAST MONTH in the events table
for products which had more then 10 clicks month before.
(Note 0 is also less than 10 ;)*/
--(1 = impression, 2 = click, 3 = purchase...)

; WITH click_last_m AS (
                        SELECT product_id,
                               COUNT(*) as click_last_m
                        FROM [events]
                        WHERE  event_type=2  
                           AND event_ts>=DATEADD(mm,-1,GETDATE())  
                        GROUP BY 1
                        ),
       click_prev_m AS (
                        SELECT product_id,
                               COUNT(*) as click_prev_m
                        FROM [events]
                        WHERE event_type=2  
                          AND event_ts>=DATEADD(mm,-2,GETDATE()) 
                          AND event_ts<DATEADD(mm,-1,GETDATE())  
                       GROUP BY 1
                       )

SELECT p.product_id, p.name,
       ISNULL(clm.click_last_m,0) as click_last_m,
       ISNULL(cpm.click_prev_m,0) as click_prev_m
FROM products p
   LEFT JOIN  click_last_m clm ON p.product_id = clm.product_id
   LEFT JOIN  click_prev_m cpm ON p.product_id = cpm.product_id
WHERE ISNULL(clm.click_last_m,0)<10
   AND ISNULL(cpm.click_prev_m,0)>10


/*Bonus
~~~~~
5) find a product with the worst ratio of the number of clicks per number of impressions in the last 6 months
for clients who purchased something last week
--продукт с наихудшим соотношением количества кликов к количеству просмотров */
--(1 = impression, 2 = click, 3 = purchase...)

; WITH click_last_sm AS (                                                           --number of clicks
                        SELECT product_id,
                               COUNT(*) as click_num
                        FROM [events]
                        WHERE  event_type=2  
                           AND event_ts>=DATEADD(mm,-6,GETDATE())  
                        GROUP BY 1
                        ),

       impr_last_sm AS (                                                            -- number of impressions
                        SELECT product_id,
                               COUNT(*) as impr_num
                        FROM [events]
                        WHERE event_type=1  
                          AND event_ts>=DATEADD(mm,-6,GETDATE()) 
                        GROUP BY 1
                       ),
        purchased AS (                                                              --purchased something last week
		               SELECT DISTINCT product_id --100K
                       FROM [events]  --10B
                       WHERE event_type=3  
                         AND event_ts >= DATEADD(dd,-7,GETDATE())  
                       )
SELECT TOP 1  c.product_id, 
              p.product_name,  --CAST(c.click_num as decimal(10,2))/i.impr_num
              CASE WHEN i.impr_num<>0 THEN ROUND(CAST(c.click_num as float)/i.impr_num, 2)--ratio of the number of clicks per number of impressions
			       ELSE 0  
			  END as ratio
FROM  click_last_sm c
   INNER JOIN impr_last_sm i 
         ON с.product_id = i.product_id
   INNER JOIN  purchased p 
         ON c.product_id = p.product_id
ORDER BY 2 



  