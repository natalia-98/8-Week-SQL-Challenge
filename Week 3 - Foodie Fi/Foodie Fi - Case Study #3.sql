USE foodie_fi;
-- CASE STUDY QUESTIONS
-- A: Customer Journey 

-- 1)  Description of the 8 sample customer's onboarding experience 
SELECT *
FROM subscriptions
JOIN plans USING(plan_id)
WHERE customer_id IN (1,2,11,13,15,16,18,19)
ORDER BY customer_id;
/* 
customer_id 1: free trial then upgraded to basic monthly plan
customer_id 2: free trial upgraded to pro annual plan
customer_id 11: free trial then cancelled 
customer_id 13: free trial upgraded to basic monthly, after three months upgraded to pro monthly
customer_id 15: free trial upgraded to pro monthly, after one month cancelled
customer_id 16: free trial upgraded to basic monthly, after 4 months upgraded to pro annual 
customer_id 18: free trial upgraded to pro monthly
customer_id 19: free trial upgraded to pro monthly, after 2 months upgraded to pro annual 
*/

-- B: Data Analysis Questions 

-- 1) How many customers has Foodie-Fi ever had?
SELECT COUNT(DISTINCT customer_id) AS num_customers
FROM subscriptions;

/* 2) What is the monthly distribution of trial plan start_date values for our dataset -
use the start of the month as the group by value */
SELECT  EXTRACT(MONTH FROM start_date) AS month
	, DATE_FORMAT(s.start_date,'%M') AS name_name
	, COUNT(*) AS num_sub
FROM subscriptions s
JOIN plans p USING(plan_id)
WHERE p.plan_name = 'trial'
GROUP BY 
	EXTRACT(MONTH FROM start_date) 
	, DATE_FORMAT(start_date,'%M')
ORDER BY month;

/*  3) What plan start_date values occur after the year 2020 for our dataset?
 Show the breakdown by count of events for each plan_name */
SELECT p.plan_name
    , COUNT(*) AS count
FROM subscriptions s
JOIN plans p USING(plan_id) 
WHERE s.start_date > '2020-12-31'
GROUP BY p.plan_name;

/*  4) What is the customer count and percentage of customers 
who have churned rounded to 1 decimal place? */

SELECT COUNT(*) churn_count
	, ROUND(COUNT(*) / ( SELECT COUNT(DISTINCT customer_id)
                    FROM subscriptions ) *100, 1) AS churn_pct
FROM subscriptions s
JOIN plans p USING (plan_id)
WHERE p.plan_name = 'churn';

/* 5) How many customers have churned straight after their initial free trial 
- what percentage is this rounded to the nearest whole number? */

-- a. Confirm that every customer got a free trial
SELECT COUNT(DISTINCT customer_id)
FROM subscriptions ;
-- 1000 customers 
SELECT COUNT(*)
FROM subscriptions
WHERE plan_id = 0;
-- 1000 ocurrences of trials. Every customer had a free trial.

-- b. Customer count that churned straight after free trial.
WITH churn_cte AS(
SELECT customer_id
	, start_date
FROM subscriptions
WHERE plan_id = 4),

trial_cte  AS (
SELECT customer_id 
	, MIN(start_date) AS trial_begin
    , ADDDATE(MIN(start_date), 7) AS trial_end
FROM subscriptions
GROUP BY customer_id ) 

SELECT COUNT(t.customer_id) AS churn_count
	, ROUND(COUNT(t.customer_id) /
					(SELECT COUNT(DISTINCT customer_id) FROM subscriptions) * 100, 0) AS churn_pct
FROM churn_cte c
JOIN trial_cte t
	ON  t.trial_end = c.start_date AND
     t.customer_id = c.customer_id;

/*  6)  What is the number and percentage of customer
 plans after their initial free trial? */

WITH plan_rank AS(

SELECT customer_id
	, plan_id
	, DENSE_RANK() OVER( PARTITION BY customer_id ORDER BY plan_id) AS plan_rank
FROM subscriptions)

SELECT COUNT(*) AS n_plans
	, ROUND(COUNT(*)/ ( 
					SELECT COUNT(DISTINCT customer_id) 
                    FROM subscriptions) * 100, 0) AS plans_pct
FROM plan_rank
WHERE plan_rank = 2 AND plan_id !=4 ;

/*  7) What is the customer count and percentage breakdown 
of all 5 plan_name values at 2020-12-31? */

WITH current_plan AS (

SELECT customer_id
	, plan_id
    , start_date
    , LEAD(start_date,1) OVER(PARTITION BY customer_id ORDER BY start_date) AS lead_date
FROM subscriptions 
) 

SELECT p.plan_name 
	, COUNT(DISTINCT customer_id) customer_count
    , ROUND(COUNT(DISTINCT customer_id) / (
									SELECT COUNT(DISTINCT customer_id)
                                    FROM subscriptions
                                    WHERE start_date <='2020-12-31') *100, 1) customer_pct
FROM current_plan c
JOIN plans p USING(plan_id)
WHERE (lead_date IS NULL AND start_date  <= '2020-12-31') 
	OR (lead_date IS NOT NULL AND (start_date <= '2020-12-31' AND lead_date > '2020-12-31'))
GROUP BY p.plan_name
ORDER BY customer_pct
;

/* 8) How many customers have upgraded to an annual plan in 2020? 
*/

SELECT COUNT(DISTINCT customer_id) AS customer_count
FROM subscriptions s
JOIN plans p USING(plan_id)
WHERE s.start_date BETWEEN '2020-01-001' AND '2020-12-31'
	AND p.plan_name = 'pro annual';

/* 9) How many days on average does it take for a customer to an annual plan
 from the day they join Foodie-Fi? */

WITH customer_join AS(
SELECT customer_id
	, start_date AS join_date
FROM subscriptions
WHERE plan_id = 0),

annual_upgrade AS (
SELECT customer_id
	, start_date AS upgrade_date
FROM subscriptions
WHERE plan_id = 3)

SELECT ROUND(AVG(DATEDIFF(a.upgrade_date, c.join_date)),0) AS avg_days_upgrade
FROM customer_join c
JOIN annual_upgrade a USING(customer_id);

 /* 10) Can you further breakdown this average value into 30 
 day periods (i.e. 0-30 days, 31-60 days etc) */
 
 WITH customer_join AS(
SELECT customer_id
	, start_date AS join_date
FROM subscriptions
WHERE plan_id = 0),

annual_upgrade AS (
SELECT customer_id
	, start_date AS upgrade_date
FROM subscriptions
WHERE plan_id = 3), 

upgrade_timeframe AS (
SELECT customer_id
	, DATEDIFF(a.upgrade_date, c.join_date) AS days_upgrade
    , (CASE 
		WHEN (DATEDIFF(a.upgrade_date, c.join_date)) <= 30
		THEN '0-30 days' 
        WHEN (DATEDIFF(a.upgrade_date, c.join_date)) BETWEEN 31 and 60
        THEN '31-60 days'
        WHEN (DATEDIFF(a.upgrade_date, c.join_date)) BETWEEN 61 and 90
        THEN '61-90 days'
        ELSE '91+ days' END ) AS upgrade_timeframe
FROM customer_join c
JOIN annual_upgrade a USING(customer_id))

SELECT COUNT(customer_id) as customer_count
	, upgrade_timeframe
FROM upgrade_timeframe
GROUP BY upgrade_timeframe
ORDER BY customer_count;

/* 11) How many customers downgraded from a pro monthly to a basic monthly plan in 2020? */
-- uncompleted  :( --
WITH plan_lead AS(
SELECT * 
	, LEAD(plan_id, 1) OVER( PARTITION BY customer_id ORDER BY plan_id) AS next_plan
FROM subscriptions)

SELECT COUNT(*) AS downgrades
FROM plan_lead
WHERE (plan_id = 2 AND next_plan = 1)
AND start_date BETWEEN '2020-01-01' AND '2020-12-31'
ORDER BY customer_id ;

