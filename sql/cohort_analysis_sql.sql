#Sanity Check
SELECT 
    COUNT(*) as total_rows, 
    COUNT(DISTINCT User_ID) as unique_users,
    MIN(Cohort_Month) as start_period,
    MAX(Cohort_Month) as end_period
FROM user_retention_data;

#Cohort Analysis
WITH Cohort_Summary AS (
    SELECT Cohort_Month, COUNT(DISTINCT User_ID) AS original_cohort_size
    FROM user_retention_data WHERE Month_Distance = 0
    GROUP BY Cohort_Month
),
Monthly_Activity AS (
    SELECT Cohort_Month, Month_Distance, COUNT(DISTINCT User_ID) AS active_users, SUM(Transaction_Value) AS monthly_revenue
    FROM user_retention_data
    GROUP BY Cohort_Month, Month_Distance
)
SELECT 
    m.Cohort_Month, m.Month_Distance, m.active_users, c.original_cohort_size,
    ROUND((m.active_users / c.original_cohort_size) * 100, 2) AS retention_rate_pct,
    ROUND(SUM(m.monthly_revenue) OVER (PARTITION BY m.Cohort_Month ORDER BY m.Month_Distance) / c.original_cohort_size, 1) AS cumulative_clv
FROM Monthly_Activity m
JOIN Cohort_Summary c ON m.Cohort_Month = c.Cohort_Month
ORDER BY m.Cohort_Month, m.Month_Distance;

#Segmentation

SELECT 
    Platform,
    -- Calculates the average retention for the first month after signup
    ROUND(AVG(CASE WHEN Month_Distance = 1 THEN retention_rate_pct END), 2) AS avg_month_1_retention_pct,
    -- Calculates the highest average lifetime value achieved per platform
    ROUND(MAX(cumulative_clv), 2) AS total_avg_clv
FROM (
    -- SUBQUERY START: Calculates base metrics per Cohort and Platform
    SELECT 
        m.Platform,
        m.Cohort_Month,
        m.Month_Distance,
        -- Retention Rate calculation for the subquery
        (COUNT(DISTINCT m.User_ID) / c.original_cohort_size) * 100 AS retention_rate_pct,
        -- Cumulative CLV calculation for the subquery
        SUM(SUM(m.Transaction_Value)) OVER (
            PARTITION BY m.Platform, m.Cohort_Month 
            ORDER BY m.Month_Distance
        ) / c.original_cohort_size AS cumulative_clv
    FROM user_retention_data m
    JOIN (
        -- Inner join to get the denominator (Month 0 size) per Cohort AND Platform
        SELECT 
            Cohort_Month, 
            Platform, 
            COUNT(DISTINCT User_ID) AS original_cohort_size
        FROM user_retention_data
        WHERE Month_Distance = 0
        GROUP BY Cohort_Month, Platform
    ) c ON m.Cohort_Month = c.Cohort_Month AND m.Platform = c.Platform
    GROUP BY m.Platform, m.Cohort_Month, m.Month_Distance, c.original_cohort_size
) AS sub
GROUP BY Platform;

#Monetization (CLV)

WITH Cohort_Sizes AS (
    SELECT Cohort_Month, COUNT(DISTINCT User_ID) as Total_Users
    FROM user_retention_data
    WHERE Month_Distance = 0
    GROUP BY Cohort_Month
)
SELECT 
    a.Cohort_Month,
    a.Month_Distance,
    ROUND(SUM(a.Transaction_Value) / s.Total_Users, 2) as Avg_Revenue_Per_User,
    -- Running total to see Cumulative CLV
    ROUND(SUM(SUM(a.Transaction_Value)) OVER (PARTITION BY a.Cohort_Month ORDER BY a.Month_Distance) / s.Total_Users, 2) as Cumulative_CLV
FROM user_retention_data a
JOIN Cohort_Sizes s ON a.Cohort_Month = s.Cohort_Month
GROUP BY a.Cohort_Month, a.Month_Distance, s.Total_Users
ORDER BY a.Cohort_Month, a.Month_Distance;

#Rentained VS Churned 

WITH first_7_days AS (
    -- Count transactions for every user in their first week
    SELECT 
        User_ID,
        Platform,
        COUNT(*) AS tx_count_week_1,
        SUM(Transaction_Value) AS spend_week_1
    FROM user_retention_data
    -- Assuming Month_Distance 0 represents the first month
    WHERE Month_Distance = 0 
    GROUP BY User_ID, Platform
),
retention_status AS (
    -- Identify who came back in Month 1
    SELECT DISTINCT User_ID, 1 AS is_retained
    FROM user_retention_data
    WHERE Month_Distance = 1
)
SELECT 
    f.tx_count_week_1,
    COUNT(f.User_ID) AS total_users,
    ROUND(AVG(COALESCE(r.is_retained, 0)) * 100, 2) AS retention_rate_pct
FROM first_7_days f
LEFT JOIN retention_status r ON f.User_ID = r.User_ID
GROUP BY f.tx_count_week_1
ORDER BY f.tx_count_week_1;

#Spending or activity frequency

WITH user_trends AS (
    SELECT 
        User_ID,
        Platform,
        -- Get current month spending
        SUM(CASE WHEN Month_Distance = (SELECT MAX(Month_Distance) FROM user_retention_data) 
                 THEN Transaction_Value ELSE 0 END) AS current_month_spend,
        -- Get average spending across all prior months
        AVG(Transaction_Value) AS avg_historical_spend,
        MAX(Month_Distance) AS last_active_month
    FROM user_retention_data
    GROUP BY User_ID, Platform
)
SELECT 
    User_ID,
    Platform,
    current_month_spend,
    ROUND(avg_historical_spend, 2) AS avg_historical_spend,
    ROUND(((current_month_spend - avg_historical_spend) / avg_historical_spend) * 100, 2) AS spend_change_pct
FROM user_trends
WHERE current_month_spend < (avg_historical_spend * 0.5) -- Spending dropped by > 50%
  AND last_active_month >= (SELECT MAX(Month_Distance) - 1 FROM user_retention_data) -- Still somewhat recent
ORDER BY spend_change_pct ASC;