ALTER TABLE orders ADD CONSTRAINT fk_customer
FOREIGN KEY (customer_id)
REFERENCES customers(customer_id);

ALTER TABLE products ADD CONSTRAINT fk_Product_Categories
FOREIGN KEY (category_id)
REFERENCES categories(category_id);

ALTER TABLE territories ADD CONSTRAINT fk_region
FOREIGN KEY (region_id)
REFERENCES region(region_id);

ALTER TABLE employeeterritories ADD CONSTRAINT fk_region
FOREIGN KEY (territory_id)
REFERENCES territories(territory_id);

ALTER TABLE orders ADD CONSTRAINT fk_ship
FOREIGN KEY (ship_via)
REFERENCES shippers(shipper_id);

ALTER TABLE orders ADD CONSTRAINT fk_Orders_Employees
FOREIGN KEY (employee_id)
REFERENCES employees(employee_id);
					 
ALTER TABLE order_details ADD CONSTRAINT fk_product
FOREIGN KEY (product_id)
REFERENCES products(product_id);

ALTER TABLE order_details ADD CONSTRAINT fk_order
FOREIGN KEY (order_id)
REFERENCES orders(order_id);

ALTER TABLE products ADD CONSTRAINT fk_supplier
FOREIGN KEY (supplier_id)
REFERENCES suppliers(supplier_id);

select * from categories;
select * from customers;
select * from employees;

ALTER TABLE employees
ADD full_name VARCHAR(255);

UPDATE employees
SET full_name = CONCAT(first_name, ' ', last_name);

select * from employeeterritories;
select * from order_details;

--discount_price, total_price ve discount_percentage kolonlarını kalıcı olarak order_details tablosuna ekleme
ALTER TABLE order_details
ADD COLUMN discount_price numeric;

UPDATE order_details
SET discount_price = ROUND((unit_price * quantity * (1 - discount))::numeric, 2);

ALTER TABLE order_details
ADD COLUMN total_price numeric;

UPDATE order_details
SET total_price = ROUND((unit_price * quantity)::numeric, 2);

ALTER TABLE order_details
ADD COLUMN discount_percentage numeric;

UPDATE order_details
SET discount_percentage = ROUND((discount * 100)::numeric, 0);

ALTER TABLE order_details
RENAME COLUMN discount_price TO total_inc_discount_price;

select * from order_details;
select * from orders;

--ÜRÜN ANALİZİ---
--Sipariş sayısı--
-- Sipariş adedine göre en çok sipariş edilen ürünler
SELECT 
    p.product_id, 
    p.product_name,
    COUNT(DISTINCT od.order_id) AS order_count
FROM 
    order_details od
JOIN 
    products p 
ON 
    od.product_id = p.product_id
GROUP BY 
    p.product_id, p.product_name
ORDER BY 
    order_count DESC
	LIMIT 10;


--En Çok Satılan Ürünler:
SELECT	p.product_id, 
		p.product_name,
		SUM(od.quantity) AS total_quantity
FROM order_details od
JOIN products p ON od.product_id = p.product_id
GROUP BY 1,2
ORDER BY total_quantity DESC
LIMIT 10;

--indirim yüzdesi arttıkça satış performansı artan ürünler
SELECT 
    p.product_id,
    p.product_name,
    od.discount_percentage,
    ROUND(SUM(od.total_inc_discount_price)::numeric, 2) AS total_sales_including_discount
FROM order_details od
JOIN products p ON od.product_id = p.product_id
GROUP BY 1,2,3
ORDER BY discount_percentage DESC, total_sales_including_discount DESC
LIMIT 10;
--
--





-- En çok sipariş veren ülkeler (order_id'ye göre)
SELECT 
    c.country,
    COUNT(o.order_id) AS total_orders
FROM 
    customers c
JOIN 
    orders o ON c.customer_id = o.customer_id
GROUP BY 
    c.country
ORDER BY 
    total_orders DESC;

--ülkere göre en çok satılan ürünler--
SELECT 
    c.country,
    p.product_name,
    SUM(od.quantity) AS total_quantity
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_details od ON o.order_id = od.order_id
JOIN products p ON od.product_id = p.product_id
GROUP BY 1,2
ORDER BY 3 DESC;
-
WITH ranked_sales AS (
    SELECT 
        c.country,
        p.product_name,
        SUM(od.quantity) AS total_quantity,
        DENSE_RANK() OVER (PARTITION BY c.country ORDER BY SUM(od.quantity) DESC) AS rank
    FROM 
        customers c
    JOIN 
        orders o ON c.customer_id = o.customer_id
    JOIN 
        order_details od ON o.order_id = od.order_id
    JOIN 
        products p ON od.product_id = p.product_id
    GROUP BY 
        c.country, p.product_name
)
SELECT 
    country,
    product_name,
    total_quantity
FROM 
    ranked_sales
WHERE 
    rank = 1
ORDER BY 
    country;



--ülkeler bazında toplam satış miktarı ve sipariş sayısı--
SELECT 
		COUNT(DISTINCT od.order_id) AS total_orders,
        c.country,
        SUM(od.total_price) AS total_sales
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_details od ON o.order_id = od.order_id
JOIN products p ON od.product_id = p.product_id
GROUP BY 2
ORDER BY 3 DESC;


--ÇALIŞAN PERFORMANS ANALİZİ--
--Çalışan Başına Satış Performansı:
SELECT	e.full_name, 
		COUNT(DISTINCT o.order_id) AS total_orders
FROM employees e
JOIN orders o ON e.employee_id = o.employee_id
GROUP BY 1
ORDER BY total_orders DESC
LIMIT 10;

--Teslimat Performans Analizi--
---Siparişlerin gönderilme sürelerinin ve gerekli tarihten sonra gönderilen siparişlerin gecikme sürelerinin analizi---
--

SELECT order_id, 
       (shipped_date - order_date) AS days_to_ship, 
       (required_date - shipped_date) AS delay_days
FROM orders
WHERE shipped_date IS NOT NULL;

--

SELECT
		e.full_name AS employee_full_name,
		e.title AS employee_title,
		COUNT(DISTINCT od.order_id) AS total_order_count,
		ROUND(SUM(od.total_inc_discount_price)::numeric, 2) AS total_sales_including_discount,
		ROUND(SUM(od.total_price)::numeric, 2) AS total_sales_excluding_discount,
		ROUND(AVG(od.discount_percentage)::numeric, 2) AS avg_discount_percentage,
		ROUND(AVG(o.shipped_date - o.order_date), 0) AS avg_days_to_ship, 
		ROUND(AVG(o.required_date - o.shipped_date), 0) AS avg_delay_days
FROM orders AS o
INNER JOIN employees AS e
ON o.employee_id = e.employee_id
INNER JOIN order_details AS od
ON od.order_id = o.order_id
INNER JOIN products AS p
ON od.product_id = p.product_id
	GROUP BY 1,2
	ORDER BY total_sales_including_discount DESC;



--TESLİMAT YÖNTEMİNE GÖRE ANALİZ

---Teslimat Yöntemi ve Maliyet Analizi--
SELECT 
    o.ship_via, 
    s.company_name,
    ROUND(AVG(o.shipped_date - o.order_date), 0) AS avg_days_to_ship, 
    ROUND(AVG(o.required_date - o.shipped_date), 0) AS avg_delay_days,
    ROUND(AVG(o.freight)::numeric, 2) AS avg_freight
FROM orders o
JOIN shippers s ON o.ship_via = s.shipper_id  -- Join with shippers table to get company_name
WHERE o.shipped_date IS NOT NULL
GROUP BY o.ship_via, s.company_name;


---teslimat yönteminin ülkere göre analizi--

WITH ranked_ship_methods AS (
    SELECT 
        c.country,
        o.ship_via,
        s.company_name,
        COUNT(o.order_id) AS total_orders,
        ROUND(AVG(o.shipped_date - o.order_date), 0) AS avg_days_to_ship, 
        ROUND(AVG(o.required_date - o.shipped_date), 0) AS avg_delay_days,
        ROUND(AVG(o.freight)::numeric, 2) AS avg_freight,
        DENSE_RANK() OVER (PARTITION BY c.country ORDER BY COUNT(o.order_id) DESC) AS rn
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN shippers s ON o.ship_via = s.shipper_id  
    WHERE o.shipped_date IS NOT NULL
    GROUP BY c.country, o.ship_via, s.company_name
)
SELECT 
    country,
    ship_via,
    company_name,
    total_orders,
    avg_days_to_ship,
    avg_delay_days,
    avg_freight
FROM ranked_ship_methods
WHERE rn = 1
ORDER BY country, avg_days_to_ship;



select * from products;
select * from region;
select * from shippers;
select * from shippers_tmp;
select * from suppliers;
select * from territories;
select * from usstates;
select * from usstates;


--KATEGORİ BALI ÜRÜN ANALİZİ
--sipariş adedine göre kategori sıralaması
SELECT 
    c.category_name, 
    COUNT(DISTINCT o.order_id) AS total_orders
FROM 
    order_details od
JOIN 
    products p ON od.product_id = p.product_id
JOIN 
    categories c ON p.category_id = c.category_id
JOIN 
    orders o ON od.order_id = o.order_id
GROUP BY 
    c.category_name
ORDER BY 
    total_orders DESC;
	
	--YIL BAZINDA İNCELEME POWER BI İÇİN
	SELECT 
    c.category_name, 
    EXTRACT(YEAR FROM o.order_date) AS year,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM 
    order_details od
JOIN 
    products p ON od.product_id = p.product_id
JOIN 
    categories c ON p.category_id = c.category_id
JOIN 
    orders o ON od.order_id = o.order_id
GROUP BY 
    c.category_name, year
ORDER BY 
    total_orders DESC;


--Kategorilere Göre Toplam Satış:
SELECT c.category_name, 
       ROUND(SUM(od.total_price)::numeric, 0) AS total_sales
FROM order_details od
JOIN products p ON od.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY c.category_name
ORDER BY total_sales DESC;
--POWER BI İÇİN YIL 
SELECT 
    c.category_name, 
    EXTRACT(YEAR FROM o.order_date) AS year,
    ROUND(SUM(od.total_price)::numeric, 0) AS total_sales
FROM 
    order_details od
JOIN 
    products p ON od.product_id = p.product_id
JOIN 
    categories c ON p.category_id = c.category_id
JOIN 
    orders o ON od.order_id = o.order_id
GROUP BY 
    c.category_name, year
ORDER BY 
    total_sales DESC;

--kategroielre göre en çok gelir getiren ürünler

WITH ranked_products AS (
    SELECT 
        c.category_name,
        p.product_name,
        ROUND(SUM(od.total_price)::numeric, 0) AS total_sales,
        DENSE_RANK() OVER (PARTITION BY c.category_name ORDER BY SUM(od.total_price) DESC) AS rank_by_sales
    FROM order_details od
    JOIN products p ON od.product_id = p.product_id
    JOIN categories c ON p.category_id = c.category_id
    GROUP BY c.category_name, p.product_name
)
SELECT 
    category_name,
    product_name,
    total_sales
FROM ranked_products
WHERE rank_by_sales = 1
ORDER BY total_sales DESC;
--POWER BI İÇİN DATE EKLENDİ 
WITH ranked_products AS (
    SELECT 
        c.category_name,
        p.product_name,
        EXTRACT(YEAR FROM o.order_date) AS year,  -- Yıl bilgisi
        ROUND(SUM(od.total_price)::numeric, 0) AS total_sales,
        DENSE_RANK() OVER (PARTITION BY c.category_name, EXTRACT(YEAR FROM o.order_date) ORDER BY SUM(od.total_price) DESC) AS rank_by_sales
    FROM order_details od
    JOIN products p ON od.product_id = p.product_id
    JOIN categories c ON p.category_id = c.category_id
    JOIN orders o ON od.order_id = o.order_id
    GROUP BY c.category_name, p.product_name, EXTRACT(YEAR FROM o.order_date)
)
SELECT 
    category_name,
    product_name,
    year,  -- Yıl bilgisi
    total_sales
FROM ranked_products
WHERE rank_by_sales = 1
ORDER BY total_sales DESC;


---en çok gelir getiren ürünlerin ülkeleri
WITH ranked_sales AS (
    SELECT 
        c.category_name,
        cu.country,
        ROUND(SUM(od.total_price)::numeric, 0) AS total_sales,
        DENSE_RANK() OVER (
            PARTITION BY c.category_name 
            ORDER BY SUM(od.total_price) DESC
        ) AS rank_by_sales
    FROM order_details od
    JOIN products p ON od.product_id = p.product_id
    JOIN categories c ON p.category_id = c.category_id
    JOIN orders o ON od.order_id = o.order_id
    JOIN customers cu ON o.customer_id = cu.customer_id
    GROUP BY c.category_name, cu.country
)
SELECT 
    category_name,
    country,
    total_sales
FROM ranked_sales
WHERE rank_by_sales = 1
ORDER BY total_sales DESC;




select * from customers
select * from shippers

--ZAMAN BAZINDA ANALİZ
--yıllara göre en çok gelir getiren ürünler
SELECT 
    EXTRACT(YEAR FROM o.order_date) AS year,
    p.product_name,
    ROUND(SUM(od.total_price)) AS total_sales
FROM 
    orders o
JOIN 
    order_details od ON o.order_id = od.order_id
JOIN 
    products p ON od.product_id = p.product_id
GROUP BY 
    1, 2
ORDER BY 
    total_sales DESC;
	
--	1997 ve 1998 yılları arasındaki aylık sipariş sayısı farkını ve toplam gelir farkınıN analizİ
WITH yearly_monthly_sales AS (
    SELECT
        EXTRACT(YEAR FROM o.order_date) AS year,
        EXTRACT(MONTH FROM o.order_date) AS month,
        COUNT(DISTINCT o.order_id) AS order_count,
        ROUND(SUM(od.total_price)::numeric, 2) AS total_revenue
    FROM 
        orders o
    JOIN 
        order_details od ON o.order_id = od.order_id
    WHERE 
        EXTRACT(YEAR FROM o.order_date) IN (1997, 1998)  -- Yalnızca 1997 ve 1998 yılları
    GROUP BY 
        year, month
),
sales_comparison AS (
    SELECT 
        m1.month,
        m1.order_count AS order_count_1997,
        m2.order_count AS order_count_1998,
        (m2.order_count - m1.order_count) AS order_count_diff,
        m1.total_revenue AS revenue_1997,
        m2.total_revenue AS revenue_1998,
        (m2.total_revenue - m1.total_revenue) AS revenue_diff
    FROM 
        yearly_monthly_sales m1
    LEFT JOIN 
        yearly_monthly_sales m2 ON m1.month = m2.month AND m2.year = 1998
    WHERE 
        m1.year = 1997
),
growth_calculation AS (
    SELECT 
        month,
        order_count_1997,
        order_count_1998,
        order_count_diff,
        revenue_1997,
        revenue_1998,
        revenue_diff,
        -- Sipariş sayısı büyüme yüzdesi
        CASE 
            WHEN order_count_1997 > 0 THEN ROUND(((order_count_1998 - order_count_1997) * 100.0 / order_count_1997), 2)
            ELSE NULL
        END AS order_count_growth_percentage,
        -- Gelir büyüme yüzdesi
        CASE 
            WHEN revenue_1997 > 0 THEN ROUND(((revenue_1998 - revenue_1997) * 100.0 / revenue_1997), 2)
            ELSE NULL
        END AS revenue_growth_percentage
    FROM 
        sales_comparison
)
SELECT 
    month,
    order_count_1997,
    order_count_1998,
    order_count_diff,
    order_count_growth_percentage,
    revenue_1997,
    revenue_1998,
    revenue_diff,
    revenue_growth_percentage
FROM 
    growth_calculation
WHERE 
    order_count_1998 IS NOT NULL  -- order_count_1998 NULL olmayan satırları al
ORDER BY 
    month;



-1996 VE 1997 YILI KARŞILAŞTIRILMASI
WITH yearly_monthly_sales AS (
    SELECT
        EXTRACT(YEAR FROM o.order_date) AS year,
        EXTRACT(MONTH FROM o.order_date) AS month,
        COUNT(DISTINCT o.order_id) AS order_count,
        ROUND(SUM(od.total_price)::numeric, 2) AS total_revenue
    FROM 
        orders o
    JOIN 
        order_details od ON o.order_id = od.order_id
    WHERE 
        EXTRACT(YEAR FROM o.order_date) IN (1996, 1997)  -- Yalnızca 1996 ve 1997 yılları
    GROUP BY 
        year, month
),
sales_comparison AS (
    SELECT 
        m1.month,
        m1.order_count AS order_count_1996,
        m2.order_count AS order_count_1997,
        (m2.order_count - m1.order_count) AS order_count_diff,
        m1.total_revenue AS revenue_1996,
        m2.total_revenue AS revenue_1997,
        (m2.total_revenue - m1.total_revenue) AS revenue_diff
    FROM 
        yearly_monthly_sales m1
    LEFT JOIN 
        yearly_monthly_sales m2 ON m1.month = m2.month AND m2.year = 1997
    WHERE 
        m1.year = 1996
),
growth_calculation AS (
    SELECT 
        month,
        order_count_1996,
        order_count_1997,
        order_count_diff,
        revenue_1996,
        revenue_1997,
        revenue_diff,
        -- Sipariş sayısı büyüme yüzdesi
        CASE 
            WHEN order_count_1996 > 0 THEN ROUND(((order_count_1997 - order_count_1996) * 100.0 / order_count_1996), 2)
            ELSE NULL
        END AS order_count_growth_percentage,
        -- Gelir büyüme yüzdesi
        CASE 
            WHEN revenue_1996 > 0 THEN ROUND(((revenue_1997 - revenue_1996) * 100.0 / revenue_1996), 2)
            ELSE NULL
        END AS revenue_growth_percentage
    FROM 
        sales_comparison
)
SELECT 
    month,
    order_count_1996,
    order_count_1997,
    order_count_diff,
    order_count_growth_percentage,
    revenue_1996,
    revenue_1997,
    revenue_diff,
    revenue_growth_percentage
FROM 
    growth_calculation
ORDER BY 
    month;


	
	---MÜŞTERİ ANALİZİ 
	---RFM Analizi:

WITH last_order AS (
    SELECT
        customer_id AS customer,
        MAX(order_date) AS last_orders
    FROM
        orders
    GROUP BY
        customer_id
)
SELECT 
    c.customer_id,
    c.company_name,
    -- Recency: Son sipariş ile en son tarihe kadar geçen süreyi hesapla
    (SELECT MAX(order_date) FROM orders) - last_order.last_orders AS recency,
    -- Frequency: Müşterinin toplam sipariş sayısı
    COUNT(o.order_id) AS frequency,
    -- Monetary: Müşterinin toplam harcama miktarı
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))::numeric, 2) AS monetary
FROM 
    customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_details od ON o.order_id = od.order_id
JOIN last_order ON c.customer_id = last_order.customer
WHERE o.shipped_date IS NOT NULL  -- Yalnızca sevk edilen siparişler
GROUP BY c.customer_id, c.company_name, last_order.last_orders
ORDER BY recency, frequency DESC, monetary DESC;


----R-F-M SCORE

WITH last_order AS (
    SELECT
        customer_id AS customer,
        MAX(order_date) AS last_orders
    FROM
        orders
    GROUP BY
        customer_id
),
rfm_scores AS (
    SELECT 
        c.customer_id,
        c.company_name,
        -- Recency: Son sipariş ile en son tarihe kadar geçen süreyi hesapla
        (SELECT MAX(order_date) FROM orders) - last_order.last_orders AS recency,
        -- Frequency: Müşterinin toplam sipariş sayısı
        COUNT(o.order_id) AS frequency,
        -- Monetary: Müşterinin toplam harcama miktarı
        ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))::numeric, 2) AS monetary
    FROM 
        customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_details od ON o.order_id = od.order_id
    JOIN last_order ON c.customer_id = last_order.customer
    WHERE o.shipped_date IS NOT NULL  -- Yalnızca sevk edilen siparişler
    GROUP BY c.customer_id, c.company_name, last_order.last_orders
)
SELECT 
    rfm_scores.customer_id,
    rfm_scores.company_name,
    rfm_scores.recency,
    rfm_scores.frequency,
    rfm_scores.monetary,
    -- Recency NTILE: Recency skorunu NTILE kullanarak belirle (en düşük Recency'ye 5, en yüksek Recency'ye 1)
    NTILE(5) OVER (ORDER BY rfm_scores.recency DESC) AS recency_ntile,  -- Düzeltildi: DESC sıralama ile en eski müşteriye 1 verilir
    -- Frequency Segmentasyonu: Frequency'ye göre 1-5 arasında puan ver
    CASE 
        WHEN rfm_scores.frequency >= 50 THEN 5
        WHEN rfm_scores.frequency BETWEEN 20 AND 49 THEN 4
        WHEN rfm_scores.frequency BETWEEN 10 AND 19 THEN 3
        ELSE 1
    END AS frequency_score,
    NTILE(5) OVER (ORDER BY rfm_scores.monetary DESC) AS monetary_ntile,
    CONCAT(
        NTILE(5) OVER (ORDER BY rfm_scores.recency DESC), '-', 
        CASE 
            WHEN rfm_scores.frequency >= 50 THEN 5
            WHEN rfm_scores.frequency BETWEEN 20 AND 49 THEN 4
            WHEN rfm_scores.frequency BETWEEN 10 AND 19 THEN 3
            ELSE 1
        END
    ) AS r_f_table
FROM 
    rfm_scores
JOIN orders o ON rfm_scores.customer_id = o.customer_id
GROUP BY 
    rfm_scores.customer_id, 
    rfm_scores.company_name, 
    rfm_scores.recency, 
    rfm_scores.frequency, 
    rfm_scores.monetary
ORDER BY 
    recency_ntile, frequency_score, monetary_ntile DESC;
