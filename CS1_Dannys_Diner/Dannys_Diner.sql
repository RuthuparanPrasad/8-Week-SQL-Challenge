

-- Dropping Schema and tables if they exist 

DROP SCHEMA IF EXISTS dannys_diner CASCADE;

DROP TABLE IF EXISTS sales, member, menu; 

-- Create Schema and set search_path

CREATE SCHEMA dannys_diner;

SET search_path = dannys_diner;

-- Creating tables and inserting values

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



-- What is the total amount each customer spent at the restaurant?


SELECT s.customer_id, SUM(m.price) AS amount_spent
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id; 

-- How many days has each customer visited the restaurant?

SELECT s.customer_id, count(DISTINCT s.order_date)
FROM dannys_diner.sales s
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- What was the first item from the menu purchased by each customer?

WITH ordered_items AS 
(
    SELECT s.customer_id, m.product_name,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.product_id) AS item_number
    FROM dannys_diner.sales s
    INNER JOIN dannys_diner.menu m
    ON s.product_id = m.product_id
)
SELECT customer_id, product_name AS first_item
FROM ordered_items
WHERE item_number = 1
GROUP BY customer_id, product_name;


-- What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT m.product_name, count(s.product_id) AS most_purchased
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY most_purchased DESC
LIMIT 1;

-- Which item was the most popular for each customer?

WITH ordered_details AS
(
    SELECT s.customer_id, m.product_name, count(m.product_name) AS no_of_times_ordered,
        DENSE_RANK() OVER (PARTITION BY s.customer_id
        ORDER BY count(m.product_name) DESC) AS ranking
    FROM dannys_diner.sales s
    INNER JOIN dannys_diner.menu m 
    ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
    ORDER BY s.customer_id, no_of_times_ordered DESC
)

SELECT customer_id, product_name, no_of_times_ordered
FROM ordered_details
WHERE ranking = 1;

-- Which item was purchased first by the customer after they became a member?

WITH member_orders AS
(
    SELECT s.customer_id, m.product_name, s.order_date, m2.join_date, DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS ranking
    FROM dannys_diner.sales s
    INNER JOIN dannys_diner.menu m
    ON s.product_id = m.product_id
    INNER JOIN dannys_diner.members m2
    ON s.customer_id = m2.customer_id
    WHERE s.order_date >= m2.join_date
    ORDER BY s.customer_id, s.order_date
)
SELECT customer_id, product_name AS first_item_purchased
FROM member_orders
WHERE ranking = 1
ORDER BY customer_id;



-- Which item was purchased just before the customer became a member?

WITH pre_member AS
(
  SELECT s.customer_id, m.product_name, s.order_date, 
  m2.join_date, DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS ranking
  FROM dannys_diner.sales s 
  INNER JOIN dannys_diner.menu m
  ON s.product_id = m.product_id
  INNER JOIN dannys_diner.members m2
  ON m2.customer_id = s.customer_id 
  WHERE s.order_date < m2.join_date
  ORDER BY s.customer_id
)
SELECT customer_id, product_name
FROM pre_member
WHERE ranking = 1
ORDER BY customer_id;

-- What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, count(s.product_id) AS count_of_products,
  SUM(m.price) AS amount_spent
FROM dannys_diner.sales s
INNER JOIN dannys_diner.members m2 
ON s.customer_id = m2.customer_id
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
WHERE s.order_date < m2.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

-- Assuming that the points scheme is only for customers who join the membership programme. Can be modified to accommodate all customers by removing the join on "members" table

WITH points_details AS
(
  SELECT s.customer_id, m.product_name, m.price, 
    CASE
    WHEN m.product_id = 1 THEN m.price * 20
    ELSE m.price * 10
    END AS points
  FROM dannys_diner.menu m
  INNER JOIN dannys_diner.sales s
  ON s.product_id = m.product_id
  INNER JOIN dannys_diner.members m2
  ON m2.customer_id = s.customer_id
  WHERE m2.join_date <= s.order_date
  ORDER BY s.customer_id
)
SELECT customer_id, SUM(points)
FROM points_details
GROUP BY customer_id
ORDER BY customer_id;


-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH points_details_january AS
(
  SELECT s.customer_id, m.product_name, m.price,
  CASE
    WHEN s.order_date - m2.join_date <=7 THEN m.price * 20
    WHEN s.order_date - m2.join_date > 7 AND s.product_id = 1 THEN m.price * 20
    ELSE m.price * 10
  END AS points,
  s.order_date, m2.join_date, s.order_date - m2.join_date as days_as_member
  FROM dannys_diner.sales s 
  INNER JOIN dannys_diner.menu m 
  ON m.product_id = s.product_id
  INNER JOIN dannys_diner.members m2
  ON m2.customer_id = s.customer_id
  WHERE s.order_date >= m2.join_date
  ORDER BY customer_id
)
SELECT customer_id, SUM(points) as points_in_january
FROM points_details_january
WHERE order_date <= DATE('2021-01-31')
GROUP BY customer_id
ORDER BY customer_id;

-- BONUS QUESTION

-- Recreating table 1

SELECT s.customer_id, s.order_date, m.product_name, m.price,
  CASE
  WHEN m2.join_date > s.order_date THEN 'N'
  WHEN s.customer_id NOT IN (SELECT customer_id FROM members) THEN 'N'
  ELSE 'Y'
  END AS member
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m
ON m.product_id = s.product_id
FULL OUTER JOIN dannys_diner.members m2
ON m2.customer_id = s.customer_id
ORDER BY s.customer_id, s.order_date;

-- Recreating table 2

WITH member_ranked_table AS
(
  SELECT s.customer_id, s.order_date, m.product_name, m.price,
  CASE
  WHEN m2.join_date > s.order_date THEN 'N'
  WHEN s.customer_id NOT IN (SELECT customer_id FROM members) THEN 'N'
  ELSE 'Y'
  END AS member
  FROM dannys_diner.sales s
  INNER JOIN dannys_diner.menu m
  ON m.product_id = s.product_id
  FULL OUTER JOIN dannys_diner.members m2
  ON m2.customer_id = s.customer_id
  ORDER BY s.customer_id, s.order_date
)
SELECT *,
  CASE
  WHEN member = 'N' THEN NULL
  ELSE DENSE_RANK() OVER (PARTITION BY customer_id, member ORDER BY order_date)
  END AS ranking
FROM member_ranked_table
ORDER BY customer_id, order_date;