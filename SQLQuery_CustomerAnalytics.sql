/****** Script for SelectTopNRows command from SSMS  ******/

-- Total number of records loaded
SELECT count(*) as Total_Number_Of_Records
FROM [Transactions].[dbo].[transactions]
-- Output- 7947545

-- extracting all data to see table structure
select top 5000 *
from [Transactions].[dbo].[transactions]

-- Queries pertaining to Data Cleaning, Exploration, Missing data etc. 

select max(uid) 
from [Transactions].[dbo].[transactions]
-- Output - 206199

-- Crackers Product name had problem loading, so just checking if it has loaded properly now.
select top 5000 *
from [Transactions].[dbo].[transactions]
where prod_name like 'Crackers%'

-- Product Name Complete Action Pacs has special character so checking if it loaded properly.
select *
from [Transactions].[dbo].[transactions]
where order_id = 3343014

select distinct department_id, department, aisle_id, aisle 
from [Transactions].[dbo].[transactions]
order by department_id

-- All department names
select distinct department_id 
from [Transactions].[dbo].[transactions]


-- Department listed as missing. department_id is 21. aisle_id = 100 -  for 17170 rows
select *
from [Transactions].[dbo].[transactions]
where department = 'missing'

select * 
from [Transactions].[dbo].[transactions]
where prod_name in ('Cilantro Bunch', 'Lemon Bag', 'Sea-Salt Grain-Free Tortilla Chips')

-- Under missing department various sort of prod_name are listed so cannot really classify missing department. Will have to ask Client.

select * 
from [Transactions].[dbo].[transactions]
where department_id = 21 

select * 
from [Transactions].[dbo].[transactions]
where aisle_id = 100 

select *
from [Transactions].[dbo].[transactions]
where aisle = 'missing' 

-- All above 3 queries are giving 17170 rows output so for every aisle_id = 100 aisle is listed as 'missing'.  
--Also for every department_id = 21 department is listed as 'missing' 

select distinct aisle_id, aisle
from [Transactions].[dbo].[transactions]
order by aisle_id


select distinct hour_of_day
from [Transactions].[dbo].[transactions]
order by hour_of_day

-- hour_of_day starts at 0 and ends at 23

select distinct dow
from [Transactions].[dbo].[transactions]

-- dow starts at 0 and ends at 6

-- total distinct users in the transaction table -  output - 50000
select count(distinct(uid))
from [Transactions].[dbo].[transactions]


select * 
from [Transactions].[dbo].[transactions] 
where pid is NULL

-- 50000 rows have null pid, cart_add_order, prod_name, aisle_id, department_id, aisle, department.
-- All these rows are last row for every uid transaction. So we don't know the last product and its details which user purchased.


select distinct(uid)
from [Transactions].[dbo].[transactions]
order by uid

-- Total users are 50000 .  with uid = 1 as first one and 206199 as last one.

select distinct order_id
from [Transactions].[dbo].[transactions]
-- there are about 832120 distinct orders 



/*Business Rule 1
When a customer joins we have 45 days to get them to make a second purchase or they never come back */

-- checking when the customer has made second purchase after the first one
select distinct uid, order_num, days_since_last_order
from [Transactions].[dbo].[transactions]
where order_num in (1,2)
and days_since_last_order >= 45.0
order by uid, order_num

-- No output this leads to conclusion that all customers have made second purchase within 45 days 

-- max days since last order = 30
select max(days_since_last_order) as Max_days_since_last_order 
from [Transactions].[dbo].[transactions]

-- Find users who have not placed second order at all
select distinct uid, order_num, days_since_last_order
from [Transactions].[dbo].[transactions]
where order_num in (1,2)
order by uid, order_num

-- the output is 100,000 rows which indicates 2 entries for every uid for order_num = 1 and then 2. Total uid = 50000.
-- So every user has placed 2nd order.


-- above output shows that all users have placed 2nd order and that too within 30 days. So instead of 45 days we should put in business case 30 days.

select distinct uid
      ,order_num
	  ,days_since_last_order
from [Transactions].[dbo].[transactions]
where days_since_last_order >45.0
order by uid, order_num

-- this also has come null which confirms that even subsequent orders are within 45 days.


-- 2nd Business rule - 5 products that a customer most frequently purchases accounts for vast majority of all purchases they ever make
-- first find the 5 products which customer frequently purchases

-- checking for uid = 1 - the 5 products frequently purchased 
select pid, prod_name, count(pid) as product_count
from [Transactions].[dbo].[transactions] 
where uid = 1
group by pid, prod_name
order by count(pid) desc

-- For all uids - the products in order of their purchase frequency -- Output 3292906 rows
select uid
      ,pid
	  ,prod_name
	  ,count(pid) as product_count
	  ,ROW_NUMBER() over (partition by uid order by uid asc, count(pid) desc)  as rn -- for every uid arrange the product in descending order of their count
from [Transactions].[dbo].[transactions] 
group by uid,pid, prod_name
order by uid, count(pid) desc

-- Building up on the above query. 

select t.uid 
      ,t.rn
      ,sum(t.product_count) over (partition by uid order by uid asc, t.rn asc) as first_five  -- running total of product count for each customer
      ,sum(t.product_count) over (partition by uid ) as total_count                           -- total products purchased by customer
from
(select uid, pid, prod_name, count(pid) as product_count,  ROW_NUMBER() over (partition by uid order by uid asc, count(pid) desc)  as rn
from [Transactions].[dbo].[transactions] 
group by uid,pid, prod_name)t
order by t.uid , t.rn

-- Output  
--uid	rn	first_five	total_count
--1	1	10	59
--1	2	20	59
--1	3	29	59
--1	4	37	59
--1	5	40	59
--1	6	43	59
--1	7	45	59
--1	8	47	59
--1	9	49	59

-- Now we just want the running total till row number 5 for each uid. So we will put that condition in where clause now.

select j.uid
      ,j.first_five   -- sum of first 5 product count
	  ,j.total_count   -- sum of all product count purchased by each user
	  ,(j.total_count - j.first_five) as other_products
--	  ,(j.first_five/j.total_count) * 100 as percent_first_five
	  , case when j.first_five > (j.total_count - j.first_five) then 'Yes' else 'No' end as Majority_Purchase
	  
from
(select t.uid 
      ,t.rn
      ,sum(t.product_count) over (partition by uid order by uid asc, t.rn asc) as first_five
      ,sum(t.product_count) over (partition by uid ) as total_count
from
(select uid, pid, prod_name, count(pid) as product_count,  ROW_NUMBER() over (partition by uid order by uid asc, count(pid) desc)  as rn
from [Transactions].[dbo].[transactions] 
group by uid,pid, prod_name
)t) j
where j.rn = 5   -- this will give us 5th row from t table.  e.g. for uid = 1 we get  uid=1 rn=1 first_five=40 total_count=59. So we get 
--sum of first five product as 40 and total product count as 59  
order by j.uid

-- Output 
--uid	first_five	total_count	other_products	Majority_Purchase
--1	40	59	19	Yes
--3	37	88	51	No
--4	6	18	12	No
--8	13	49	36	No
--13	42	81	39	Yes
--14	41	210	169	No
--17	116	294	178	No

-- This output tells us which user has first five frequently purchased products as their majority purchase.

-- Now we are getting the count of users with Majority purchase and not Majority purchase.

select   sum(CASE WHEN k.Majority_Purchase = 'Yes' then 1 ELSE NULL END) as "No_of_Ppl_with_Majority_Purchase",
         sum(CASE WHEN k.Majority_Purchase = 'No' then 1 ELSE NULL END) as "No_of_Ppl_with_not_Majority_Purchase"
from
(
select j.uid
      ,j.first_five
	  ,j.total_count
	  ,(j.total_count - j.first_five) as other_products
	  ,(j.first_five/j.total_count) * 100 as percent_first_five
	  , case when j.first_five > (j.total_count - j.first_five) then 'Yes' else 'No' end as Majority_Purchase
	  
from
(select t.uid 
      ,t.rn
      ,sum(t.product_count) over (partition by uid order by uid asc, t.rn asc) as first_five
      ,sum(t.product_count) over (partition by uid ) as total_count
from
(select uid, pid, prod_name, count(pid) as product_count,  ROW_NUMBER() over (partition by uid order by uid asc, count(pid) desc)  as rn
from [Transactions].[dbo].[transactions] 
group by uid,pid, prod_name
)t) j
where j.rn = 5) k
--order by j.uid
group by k.Majority_Purchase

--Output
--No_of_Ppl_with_Majority_Purchase	No_of_Ppl_with_not_Majority_Purchase
--NULL	42497
--6988	NULL

-- So we get 42497 uids not having their first 5 frequently purchased product as their major purchase
-- and we get 6988 uids having their first 5 frequently purchased products as their makor purchase
-- select 6988 + 42497 = 49485
-- total distinct uid  count = 50000
-- so 50000 - 49485 = 515 is missing uids

-- Trying to see where in query building we lost 515 uids
select count(distinct(uid))
from
(select uid, pid, prod_name, count(pid) as product_count,  ROW_NUMBER() over (partition by uid order by uid asc, count(pid) desc)  as rn
from [Transactions].[dbo].[transactions] 
group by uid,pid, prod_name) t

--Output - 50000


select count(distinct(tr.uid))
from
(select t.uid 
      ,t.rn
      ,sum(t.product_count) over (partition by uid order by uid asc, t.rn asc) as first_five
      ,sum(t.product_count) over (partition by uid ) as total_count
from
(select uid, pid, prod_name, count(pid) as product_count,  ROW_NUMBER() over (partition by uid order by uid asc, count(pid) desc)  as rn
from [Transactions].[dbo].[transactions] 
group by uid,pid, prod_name
)t
where t.rn = 5) tr

-- here the output is 49485. So we  lost 515 uids with where clause t.rn = 5 which means that this 515 uids purchased less than 5 products overall 
-- or did not purchase 5 different variety of products.

-- Customers who purchased overall less than 5 variety of products. These 515 customers are not there in the above  
--analysis of Business case 2
-- In Below query we get those 515 customers. we said < 4 because every customer has null pid row. So query is extracting customers
--with less than 5  product_count.

select uid, count(distinct(pid)) as product_count
from [Transactions].[dbo].[transactions] 
group by uid
having count(distinct(pid)) < 4
order by uid

--Output
--uid	product_count
--196	2
--392	3
--431	2
--1262	3
--1728	3
--3476	1
--4259	1

--Verifying
select * from [Transactions].[dbo].[transactions]  where uid = 196


--2nd Business rule is not correct as there are many customers whose first five majorly purchased products don't make majority of their purchase.
-- there are about ~42497 customers whose majority of purchase is not first five products.
-- there are about ~6988 customers whose majority of purchase is their first five products.
-- Even if I add 515 customers to 6988 still the gap with 42497 is large.
-- We are saying approximate because every customer has Null pid, prod_name listed as their last order.



--Business case 3  -- Customers can only be classified into 2 useful segments -- those who purchase small numbers of product frequently throughout week
-- those who make single big order consisting of many products weekly or bi weekly

--Step 1: Product count for every order_id

select distinct uid
	  ,order_id
	  ,order_num
	  ,count(pid) over (partition by order_id order by  uid, order_num) as product_count  -- will give you number of products in 1 order
	  ,days_since_last_order
from [Transactions].[dbo].[transactions]
order by uid, order_num

--Output
--uid	order_id	order_num	product_count	days_since_last_order
--1	2539329	1	5	NULL
--1	2398795	2	6	15
--1	473747	3	5	21
--1	2254736	4	5	29
--1	431534	5	8	28
--1	3367565	6	4	19
--1	550135	7	5	20
--1	3108588	8	6	14
--1	2295261	9	6	0

--Step 2
-- Now we also need product count of previous order. So for uid = 1 order_num = 9 is within 7 days of previous order. 
--So we need product count of order_num = 8 also. This total will give us the product count within week period.

-- Building the above query to include previous order count. Also we are filtering by days since last order < 7 i.e 0,1,2,3,4,5,6

select t.uid
      ,t.order_id
	  ,t.order_num
      ,t.product_count
	  ,lag(t.product_count) over (partition by t.uid order by t.uid, t.order_num) as previous_order_productcount
	  ,t.days_since_last_order
from
(
select distinct uid
	  ,order_id
	  ,order_num
	  ,count(pid) over (partition by order_id order by  uid, order_num) as product_count  -- will give you number of products in 1 order
	  ,days_since_last_order
from [Transactions].[dbo].[transactions])t
order by t.uid, t.order_num

--Output
--uid	order_id	order_num	product_count	previous_order_productcount	days_since_last_order
--1	2539329	1	5	NULL	NULL
--1	2398795	2	6	5	15
--1	473747	3	5	6	21
--1	2254736	4	5	5	29
--1	431534	5	8	5	28
--1	3367565	6	4	8	19
--1	550135	7	5	4	20
--1	3108588	8	6	5	14
--1	2295261	9	6	6	0               -- This the row we want since here days_since_last_order is less than 7
--1	2550362	10	9	6	30

-- So we got above output with data arranged in required format. Directly giving filter of 7 days was not calculating properly.
select k.uid
      ,k.order_id
	  ,k.order_num
      ,k.product_count
	  , k.previous_order_productcount
	  ,k.days_since_last_order
from
(select t.uid
      ,t.order_id
	  ,t.order_num
      ,t.product_count
	  ,lag(t.product_count) over (partition by t.uid order by t.uid, t.order_num) as previous_order_productcount
	  ,t.days_since_last_order
from
(
select distinct uid
	  ,order_id
	  ,order_num
	  ,count(pid) over (partition by order_id order by  uid, order_num) as product_count  -- will give you number of products in 1 order
	  ,days_since_last_order
from [Transactions].[dbo].[transactions])t)k
where k.days_since_last_order < 7
order by k.uid, k.order_num


--Output
--uid	order_id	order_num	product_count	previous_order_productcount	days_since_last_order
--1	2295261	9	6	6	0
--4	2557754	5	3	2	0
--13	2288946	3	9	4	6
--13	1378982	5	6	5	6
--13	1789302	12	8	8	6
--14	1366559	3	3	5	2
--14	2045336	12	14	13	4
--17	1681401	2	15	3	3
--17	2680214	3	7	15	5

-- Now we will add previous product count and current product count.
select l.uid
      ,l.product_count + l.previous_order_productcount as Within_Week_product_count
from
(
select k.uid
      ,k.order_id
	  ,k.order_num
      ,k.product_count
	  , k.previous_order_productcount
	  ,k.days_since_last_order
from
(select t.uid
      ,t.order_id
	  ,t.order_num
      ,t.product_count
	  ,lag(t.product_count) over (partition by t.uid order by t.uid, t.order_num) as previous_order_productcount
	  ,t.days_since_last_order
from
(
select distinct uid
	  ,order_id
	  ,order_num
	  ,count(pid) over (partition by order_id order by  uid, order_num) as product_count  -- will give you number of products in 1 order
	  ,days_since_last_order
from [Transactions].[dbo].[transactions])t)k
where k.days_since_last_order < 7) l
order by l.uid

--Output
--uid	Within_Week_product_count
--1	    12
--4	    5
--13	13
--13	11
--13	16
--14	8
--14	27
--17	18
--17	22

-- More Analysis
select 
      min(m.Within_Week_product_count) as  Minimum_Within_Week_product_count
	  ,max(m.Within_Week_product_count) as Maximum_Within_Week_product_count
	  ,avg(m.Within_Week_product_count) as Average_Within_Week_product_count
	  ,count(m.uid) as User_Count
from
(
select l.uid
      ,l.product_count + l.previous_order_productcount as Within_Week_product_count
from
(
select k.uid
      ,k.order_id
	  ,k.order_num
      ,k.product_count
	  , k.previous_order_productcount
	  ,k.days_since_last_order
from
(select t.uid
      ,t.order_id
	  ,t.order_num
      ,t.product_count
	  ,lag(t.product_count) over (partition by t.uid order by t.uid, t.order_num) as previous_order_productcount
	  ,t.days_since_last_order
from
(
select distinct uid
	  ,order_id
	  ,order_num
	  ,count(pid) over (partition by order_id order by  uid, order_num) as product_count  -- will give you number of products in 1 order
	  ,days_since_last_order
from [Transactions].[dbo].[transactions])t)k
where k.days_since_last_order < 7) l)m

--order by m.uid
--k.order_num

--Output
--Minimum_Within_Week_product_count	Maximum_Within_Week_product_count	Average_Within_Week_product_count	User_Count
--1	                                         177	                                18	                      317271


-- uids purchasing products  after week only. So  days_since_last_order should be 7
-- uids purchasing products biweekly only. So  days_since_last_order  should be 14

select distinct uid
	  ,order_id
	  ,order_num
	  ,count(pid) over (partition by order_id order by  uid, order_num) as product_count  -- will give you number of products in 1 order
	  ,days_since_last_order
from [Transactions].[dbo].[transactions]
where days_since_last_order = 7
order by uid, order_num

--Output
--uid	order_id	order_num	product_count	days_since_last_order
--3	1972919	6	8	7
--3	1839752	7	9	7
--3	3225766	8	8	7
--3	3160850	9	5	7
--13	2363981	6	7	7
--13	1906169	7	10	7
--13	519471	9	5	7
--13	2298068	10	9	7
--14	3394109	13	12	7
--17	415389	20	6	7

--Final Query built on same logic as we built within week query.
--Only difference here will be where clause which is k.days_since_last_order = 7 or k.days_since_last_order = 14

select l.uid
      ,l.product_count + l.previous_order_productcount as Weekly_Biweekly_product_count
from
(
select k.uid
      ,k.order_id
	  ,k.order_num
      ,k.product_count
	  , k.previous_order_productcount
	  ,k.days_since_last_order
from
(select t.uid
      ,t.order_id
	  ,t.order_num
      ,t.product_count
	  ,lag(t.product_count) over (partition by t.uid order by t.uid, t.order_num) as previous_order_productcount
	  ,t.days_since_last_order
from
(
select distinct uid
	  ,order_id
	  ,order_num
	  ,count(pid) over (partition by order_id order by  uid, order_num) as product_count  -- will give you number of products in 1 order
	  ,days_since_last_order
from [Transactions].[dbo].[transactions])t)k
where k.days_since_last_order = 7 or k.days_since_last_order = 14) l
order by uid


--Output
--uid	Weekly_product_count
--1	11
--1	9
--3	19
--3	17
--3	17
--3	13
--13	13
--13	17
--13	10

--uid and product count are overlapping values. very similar. So this segmentation is not correct.

-- As you can see the outputs of these 2 queries are already overlapping with 13,14,17 uids being in both of them. Also the product count is around same.
--This Business Case segmentation is not correct. 

-- Customers purchasing biweekly -- extra checks.
select distinct uid
	  ,order_id
	  ,order_num
	  ,count(pid) over (partition by order_id order by  uid, order_num) as product_count  -- will give you number of products in 1 order
	  ,days_since_last_order
from [Transactions].[dbo].[transactions]
where days_since_last_order = 14
order by uid, order_num

-- Output
--uid	order_id	order_num	product_count	days_since_last_order
--1	3108588	8	6	14
--1	1187899	11	0	14
--24	196008	17	2	14
--24	173172	18	1	14
--26	2063028	9	13	14
--37	1740853	13	7	14
--50	1077695	21	12	14

-- Here uid = 1 which is present in within week segmentation is present here in biweekly segmentation. 
--So there is overlap and so we conclude that this segmentation is not proper.

-- To do Customer Segmentation we need more data. More tables
-- With this data we can segment Customers  based on certain department from which they buy. Segmentation based on their lifestyle 

select distinct uid 
from [Transactions].[dbo].[transactions] 
where department = 'babies' 
intersect
select distinct uid
from [Transactions].[dbo].[transactions] 
where department <> 'babies' or department <> 'NULL'

-- Output 8275 uids

select distinct uid 
from [Transactions].[dbo].[transactions] 
where department = 'babies' 

--Output - 8275 uids


select * from [Transactions].[dbo].[transactions]   -- 21531 user id has always purchased only from babies department.
where uid = 21531

-- So customers can be segmented as ones which buy from babies department and ones which don't
-- Customer who buy from Alcohol department and ones who don't
-- Customers who buy from Pets department and ones who don't
-- Other departments are common and have overlap but they can also be grouped together so see if customer buys only from produce department etc.
-- This will give us idea into their buying pattern and we can recommend them offers accordingly.

select distinct uid 
from [Transactions].[dbo].[transactions] 
where department = 'alcohol' 

-- Output 3820 uids


select distinct uid 
from [Transactions].[dbo].[transactions] 
where department = 'pets' 


select *
from [Transactions].[dbo].[transactions]


-- Few more analysis 
-- find avg number of products in 1 order. ALso min and max. Descriptive statistics.

select order_id, count(pid) as product_count
from [Transactions].[dbo].[transactions]
group by order_id
order by product_count desc

-- Maximum products in order are 109 for order_id = 2621625. It is actually outlier
-- Minimum products in order are 1 for order_id 2999189  1067420  1009983  952427. coz NULL pid for every user we are assuming to be 1.

select * from [Transactions].[dbo].[transactions] where order_id in (2999189,1067420, 1009983, 952427)
select * from [Transactions].[dbo].[transactions] where order_id = 2621625

-- Finding average number of products ordered per order_id
select avg(product_count) as avg_no_of_products_ordered
from
(
select order_id, count(pid) as product_count
from [Transactions].[dbo].[transactions]
group by order_id
) t




-- Average number of products in order is 9. Considering NULL value in some orders we will take 9, 10 as average of products in order.

-- Total number of orders in this transaction dataset is 842120

select count(distinct(order_id))
from [Transactions].[dbo].[transactions]

-- Out of this 842120 orders, let's find how many orders are with 9, 10 products.
select order_id, count(pid)
from [Transactions].[dbo].[transactions]
group by order_id
having count(pid) in (9,10)

-- There are about 85229 orders with 9,10 product count

-- that is how much percentage of total orders
select 8522900/842120

-- about 10 percent of orders are with 9, 10 product count

-- Maximum frequency of product count
select t.product_count, count(t.product_count) as order_count
from
(
select order_id, count(pid) as product_count
from [Transactions].[dbo].[transactions]
group by order_id
)t
group by t.product_count
order by count(t.product_count) desc

--There are about 45050 orders with 9 product count.
--There are about 40179 orders with 10 product count.  So the total of this 2 is coming to be 85229 which we got earlier.
-- there are maximum orders with product count as 4







