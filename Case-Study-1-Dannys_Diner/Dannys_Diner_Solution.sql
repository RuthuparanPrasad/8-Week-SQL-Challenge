
-- CASE STUDY #1: Danny's Diner

-- Author	:	Ruthuparan Prasad
-- Date		:	19/07/2022
-- Tools	:	PostgreSQL


-- Creating the tables and inserting values, copied from the case study link

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
 
-- SOLUTIONS TO THE CASE STUDY QUESTIONS

-- 1. what is the total amount each customer spent at the restaurant?

SELECT s.customer_id , sum(m.price) AS total_money_spent
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
GROUP BY customer_id
ORDER BY customer_id ;

-- 2. how many days has each customer visited the restaurant?

SELECT customer_id, count(customer_id) AS no_of_times_visited
FROM sales s
GROUP BY customer_id
ORDER BY customer_id;

-- 3. what was the first item from the menu purchased by each customer?

WITH ordered_sales_details AS 
(
SELECT
	s.customer_id,
	s.order_date,
	m.product_name,
	DENSE_RANK() OVER (PARTITION BY s.customer_id
ORDER BY
	s.order_date) AS ranking
FROM
	sales s
INNER JOIN menu m 
ON
	s.product_id = m.product_id
)
SELECT
	customer_id,
	product_name
FROM
	ordered_sales_details
WHERE
	ranking = 1
GROUP BY
	customer_id,
	product_name;

-- 4. what is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT
	m.product_name,
	count(s.product_id) AS no_of_times_purchased
FROM
	sales s
INNER JOIN menu m 
ON
	s.product_id = m.product_id
GROUP BY
	s.product_id,
	m.product_name
ORDER BY
	no_of_times_purchased DESC
LIMIT 1;

-- 5. which item was the most popular for each customer?

WITH ordered_details AS
(
SELECT
	s.customer_id,
	m.product_name,
	count(s.product_id) AS no_of_times_ordered,
	DENSE_RANK() OVER (PARTITION BY s.customer_id
ORDER BY
	count(s.customer_id) DESC) AS ranking
FROM
	sales s
INNER JOIN menu m
ON
	s.product_id = m.product_id
GROUP BY
	s.customer_id,
	m.product_name
)
SELECT
	customer_id,
	product_name,
	no_of_times_ordered
FROM
	ordered_details
WHERE
	ranking = 1;

-- 6. which item was purchased first by the customer after they became a member?

WITH date_details AS
(
SELECT
	s.customer_id,
	m.join_date,
	s.order_date,
	s.product_id,
	DENSE_RANK() OVER (PARTITION BY s.customer_id
ORDER BY
	s.order_date) AS ranking
FROM
	sales s
INNER JOIN members m 
ON
	s.customer_id = m.customer_id
WHERE
	s.order_date >= m.join_date)
SELECT
	date_details.customer_id,
	join_date,
	order_date,
	m2.product_name
FROM
	date_details
INNER JOIN menu m2
ON
	date_details.product_id = m2.product_id
WHERE
	ranking = 1
ORDER BY
	customer_id;

-- 7. which item was purchased just before the customer became a member?

WITH date_details AS
(
SELECT
	s.customer_id,
	m.join_date,
	s.order_date,
	s.product_id
FROM
	sales s
INNER JOIN members m 
ON
	s.customer_id = m.customer_id
WHERE
	s.order_date < m.join_date)
SELECT
	customer_id,
	join_date,
	order_date,
	m2.product_name
FROM
	date_details
INNER JOIN menu m2
ON
	date_details.product_id = m2.product_id
ORDER BY
	customer_id ;

-- 8. what is the total items and amount spent for each member before they became a member?

SELECT
	s.customer_id,
	count(DISTINCT s.product_id) AS count_of_products,
	sum(m2.price)
FROM
	sales s
INNER JOIN members m 
	ON
	s.customer_id = m.customer_id
INNER JOIN menu m2
	ON
	s.product_id = m2.product_id
WHERE
	s.order_date < m.join_date
GROUP BY
	s.customer_id;

-- 9.  if each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH points_details AS 
(
SELECT
	*,
	CASE
		WHEN product_id = 1 THEN price * 10 * 2
		ELSE price * 10
	END AS points
FROM
	menu
)
SELECT
	s.customer_id,
	sum(points_details.points) AS total_points
FROM
	points_details
INNER JOIN sales s
ON
	s.product_id = points_details.product_id
GROUP BY
	s.customer_id
ORDER BY
	s.customer_id;

-- 10. in the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer a and b have at the end of january?

-- logic is that sushi is still price *20 points before the membership begins

WITH points_details AS 
(
    SELECT s.customer_id, m.join_date, s.order_date, DATE(m.join_date + INTERVAL '6 day') AS valid_date, (date_trunc('month', m.join_date::date) + INTERVAL '1 month' - INTERVAL '1 day')::date AS last_date, s.product_id, m2.price, m2.product_name,
    CASE 
	    WHEN m2.product_name = 'sushi' THEN m2.price * 10 * 2
    		WHEN s.order_date BETWEEN m.join_date AND DATE(m.join_date + INTERVAL '6 day') THEN m2.price * 10 * 2
    		ELSE m2.price * 10
    END AS points
    
	FROM sales s 
	JOIN members m 
	ON s.customer_id = m.customer_id 
	JOIN menu m2 
	ON s.product_id = m2.product_id 
	WHERE s.order_date <= (date_trunc('month', m.join_date::date) + INTERVAL '1 month' - INTERVAL '1 day')::date
	ORDER BY s.customer_id, s.order_date 
)

SELECT customer_id, sum(points) AS total_points
FROM points_details
GROUP BY customer_id
ORDER BY customer_id;

-- BONUS QUESTIONS

-- on anlysis of the expected results, we need to see if the customer was a member at the time of placing the order

SELECT s.customer_id, s.order_date, m.product_name, m.price,
CASE 
	WHEN s.order_date < m2.join_date THEN 'N'
	WHEN s.customer_id NOT IN (SELECT customer_id FROM members ) THEN 'N'
	ELSE 'Y'
END AS "member"
FROM sales s 
INNER JOIN menu m 
ON s.product_id = m.product_id 
LEFT JOIN members m2 
ON s.customer_id = m2.customer_id 
ORDER BY s.customer_id, s.order_date 

-- BONUS Question #2

WITH member_or_not AS 
(
SELECT s.customer_id, s.order_date, m.product_name, m.price,
CASE 
	WHEN s.order_date < m2.join_date THEN 'N'
	WHEN s.customer_id NOT IN (SELECT customer_id FROM members ) THEN 'N'
	ELSE 'Y'
END AS isMember
FROM sales s 
INNER JOIN menu m 
ON s.product_id = m.product_id 
LEFT JOIN members m2 
ON s.customer_id = m2.customer_id 
ORDER BY s.customer_id, s.order_date
)
SELECT *,
CASE
	WHEN isMember = 'N' THEN NULL
	ELSE dense_rank() OVER (PARTITION BY customer_id, isMember ORDER BY order_date)
END AS ranking
FROM member_or_not
ORDER BY customer_id, order_date;

