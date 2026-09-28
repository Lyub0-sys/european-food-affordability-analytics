-- Month-over-Month (MoM) percentage change

WITH monthly_changes AS (
    SELECT
        month,
        geo,
        hicp_index,
        LAG(hicp_index) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS previous_index
    FROM hicp_food_index
)
SELECT
    month,
    geo,
    hicp_index,
    previous_index,
    ROUND(
        (hicp_index - previous_index) / previous_index * 100,
        2
    ) AS mom_change_pct
FROM monthly_changes
ORDER BY geo, month;


-- Year-over-Year (YoY) percentage change

WITH yearly_changes AS (
    SELECT
        month,
        geo,
        hicp_index,
        LAG(hicp_index, 12) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS previous_year_index
    FROM hicp_food_index
)
SELECT
    month,
    geo,
    hicp_index,
    previous_year_index,
    ROUND(
        (hicp_index - previous_year_index) / previous_year_index * 100,
        2
    ) AS yoy_change_pct
FROM yearly_changes
ORDER BY geo, month;


-- Country vs EU27 Year-over-Year gap in percentage points

WITH yearly_changes AS (
    SELECT
        month,
        geo,
        hicp_index,
        LAG(hicp_index, 12) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS previous_year_index
    FROM hicp_food_index
),
yoy_rates AS (
    SELECT
        month,
        geo,
        ROUND(
            (hicp_index - previous_year_index) / previous_year_index * 100,
            2
        ) AS yoy_change_pct
    FROM yearly_changes
    WHERE previous_year_index IS NOT NULL
)
SELECT
    country.month,
    country.geo,
    country.yoy_change_pct,
    eu.yoy_change_pct AS eu27_yoy_change_pct,
    ROUND(
        country.yoy_change_pct - eu.yoy_change_pct,
        2
    ) AS gap_vs_eu27_pp
FROM yoy_rates AS country
JOIN yoy_rates AS eu
    ON country.month = eu.month
    AND eu.geo = 'EU27_2020'
WHERE country.geo <> 'EU27_2020'
ORDER BY country.geo, country.month;


-- Highest and lowest Year-over-Year change by geography

WITH yearly_changes AS (
    SELECT
        month,
        geo,
        hicp_index,
        LAG(hicp_index, 12) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS previous_year_index
    FROM hicp_food_index
),
yoy_rates AS (
    SELECT
        month,
        geo,
        ROUND(
            (hicp_index - previous_year_index) / previous_year_index * 100,
            2
        ) AS yoy_change_pct
    FROM yearly_changes
    WHERE previous_year_index IS NOT NULL
),
ranked_rates AS (
    SELECT
        month,
        geo,
        yoy_change_pct,
        ROW_NUMBER() OVER (
            PARTITION BY geo
            ORDER BY yoy_change_pct DESC
        ) AS highest_rank,
        ROW_NUMBER() OVER (
            PARTITION BY geo
            ORDER BY yoy_change_pct ASC
        ) AS lowest_rank
    FROM yoy_rates
)
SELECT
    month,
    geo,
    yoy_change_pct,
    CASE
        WHEN highest_rank = 1 THEN 'Highest'
        WHEN lowest_rank = 1 THEN 'Lowest'
    END AS change_type
FROM ranked_rates
WHERE highest_rank = 1
   OR lowest_rank = 1
ORDER BY geo, change_type;

-- Year-over-Year summary and volatility by geography

WITH yearly_changes AS (
    SELECT
        month,
        geo,
        hicp_index,
        LAG(hicp_index, 12) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS previous_year_index
    FROM hicp_food_index
),
yoy_rates AS (
    SELECT
        month,
        geo,
        (hicp_index - previous_year_index) / previous_year_index * 100
            AS yoy_change_pct
    FROM yearly_changes
    WHERE previous_year_index IS NOT NULL
)
SELECT
    geo,
    ROUND(AVG(yoy_change_pct), 2) AS avg_yoy_pct,
    ROUND(MIN(yoy_change_pct), 2) AS min_yoy_pct,
    ROUND(MAX(yoy_change_pct), 2) AS max_yoy_pct,
    ROUND(STDDEV_POP(yoy_change_pct), 2) AS yoy_volatility
FROM yoy_rates
GROUP BY geo
ORDER BY geo;

-- Income data by geography and year

SELECT
    year,
    geo,
    income_pps
FROM income_pps
ORDER BY geo, year;

-- Annual income change in PPS and percent

SELECT
    year,
    geo,
    income_pps,
    income_pps - LAG(income_pps) OVER (
        PARTITION BY geo
        ORDER BY year
    ) AS change_pps,
    ROUND(
        (
            income_pps /
            LAG(income_pps) OVER (
                PARTITION BY geo
                ORDER BY year
            )
            - 1
        ) * 100,
        2
    ) AS income_change_pct
FROM income_pps
ORDER BY geo, year;

-- Check HICP monthly coverage by year

SELECT
    YEAR(month) AS year,
    geo,
    COUNT(*) AS months_available
FROM hicp_food_index
GROUP BY YEAR(month), geo
ORDER BY geo, year;

-- Annual average food HICP for complete years

SELECT
    YEAR(month) AS year,
    geo,
    ROUND(AVG(hicp_index), 4) AS avg_hicp_food_index
FROM hicp_food_index
WHERE YEAR(month) BETWEEN 2023 AND 2025
GROUP BY YEAR(month), geo
ORDER BY geo, year;

-- Join annual food HICP with annual income

WITH annual_hicp AS (
    SELECT
        YEAR(month) AS year,
        geo,
        ROUND(AVG(hicp_index), 4) AS avg_hicp_food_index
    FROM hicp_food_index
    WHERE YEAR(month) BETWEEN 2023 AND 2025
    GROUP BY YEAR(month), geo
)

SELECT
    annual_hicp.year,
    annual_hicp.geo,
    annual_hicp.avg_hicp_food_index,
    income_pps.income_pps
FROM annual_hicp
JOIN income_pps
    ON annual_hicp.year = income_pps.year
    AND annual_hicp.geo = income_pps.geo
ORDER BY annual_hicp.geo, annual_hicp.year;

-- Compare annual food HICP growth with annual income growth

WITH annual_hicp AS (
    SELECT
        YEAR(month) AS year,
        geo,
        AVG(hicp_index) AS avg_hicp_food_index
    FROM hicp_food_index
    WHERE YEAR(month) BETWEEN 2023 AND 2025
    GROUP BY YEAR(month), geo
)

SELECT
    annual_hicp.year,
    annual_hicp.geo,

    ROUND(
        (
            annual_hicp.avg_hicp_food_index /
            LAG(annual_hicp.avg_hicp_food_index) OVER (
                PARTITION BY annual_hicp.geo
                ORDER BY annual_hicp.year
            )
            - 1
        ) * 100,
        2
    ) AS food_hicp_change_pct,

    ROUND(
        (
            income_pps.income_pps /
            LAG(income_pps.income_pps) OVER (
                PARTITION BY income_pps.geo
                ORDER BY income_pps.year
            )
            - 1
        ) * 100,
        2
    ) AS income_change_pct

FROM annual_hicp

JOIN income_pps
    ON annual_hicp.year = income_pps.year
    AND annual_hicp.geo = income_pps.geo

ORDER BY annual_hicp.geo, annual_hicp.year;

-- Correct annual HICP-income alignment using the income reference year

WITH annual_hicp AS (
    SELECT
        YEAR(month) AS hicp_year,
        geo,
        ROUND(AVG(hicp_index), 4) AS avg_hicp_food_index
    FROM hicp_food_index
    WHERE YEAR(month) BETWEEN 2022 AND 2024
    GROUP BY YEAR(month), geo
)

SELECT
    income_pps.year AS income_survey_year,
    income_pps.year - 1 AS income_reference_year,
    annual_hicp.geo,
    annual_hicp.avg_hicp_food_index,
    income_pps.income_pps
FROM annual_hicp
JOIN income_pps
    ON annual_hicp.hicp_year = income_pps.year - 1
    AND annual_hicp.geo = income_pps.geo
ORDER BY annual_hicp.geo, income_pps.year;

-- Correct annual growth comparison using income reference years

WITH annual_hicp AS (
    SELECT
        YEAR(month) AS hicp_year,
        geo,
        AVG(hicp_index) AS avg_hicp_food_index
    FROM hicp_food_index
    WHERE YEAR(month) BETWEEN 2022 AND 2024
    GROUP BY YEAR(month), geo
)

SELECT
    income_pps.year AS income_survey_year,
    income_pps.year - 1 AS income_reference_year,
    annual_hicp.geo,

    ROUND(
        (
            annual_hicp.avg_hicp_food_index /
            LAG(annual_hicp.avg_hicp_food_index) OVER (
                PARTITION BY annual_hicp.geo
                ORDER BY income_pps.year
            )
            - 1
        ) * 100,
        2
    ) AS food_hicp_change_pct,

    ROUND(
        (
            income_pps.income_pps /
            LAG(income_pps.income_pps) OVER (
                PARTITION BY income_pps.geo
                ORDER BY income_pps.year
            )
            - 1
        ) * 100,
        2
    ) AS income_change_pct

FROM annual_hicp
JOIN income_pps
    ON annual_hicp.hicp_year = income_pps.year - 1
    AND annual_hicp.geo = income_pps.geo

ORDER BY annual_hicp.geo, income_pps.year;

-- Affordability change proxy:
-- income growth minus food HICP growth

WITH annual_hicp AS (
    SELECT
        YEAR(month) AS hicp_year,
        geo,
        AVG(hicp_index) AS avg_hicp_food_index
    FROM hicp_food_index
    WHERE YEAR(month) BETWEEN 2022 AND 2024
    GROUP BY YEAR(month), geo
),

growth_rates AS (
    SELECT
        income_pps.year AS income_survey_year,
        income_pps.year - 1 AS income_reference_year,
        annual_hicp.geo,

        ROUND(
            (
                annual_hicp.avg_hicp_food_index /
                LAG(annual_hicp.avg_hicp_food_index) OVER (
                    PARTITION BY annual_hicp.geo
                    ORDER BY income_pps.year
                )
                - 1
            ) * 100,
            2
        ) AS food_hicp_change_pct,

        ROUND(
            (
                income_pps.income_pps /
                LAG(income_pps.income_pps) OVER (
                    PARTITION BY income_pps.geo
                    ORDER BY income_pps.year
                )
                - 1
            ) * 100,
            2
        ) AS income_change_pct

    FROM annual_hicp
    JOIN income_pps
        ON annual_hicp.hicp_year = income_pps.year - 1
        AND annual_hicp.geo = income_pps.geo
)

SELECT
    income_survey_year,
    income_reference_year,
    geo,
    food_hicp_change_pct,
    income_change_pct,
    ROUND(
        income_change_pct - food_hicp_change_pct,
        2
    ) AS affordability_gap_pp
FROM growth_rates
ORDER BY geo, income_survey_year;

-- Show only years with a calculated affordability change proxy

WITH annual_hicp AS (
    SELECT
        YEAR(month) AS hicp_year,
        geo,
        AVG(hicp_index) AS avg_hicp_food_index
    FROM hicp_food_index
    WHERE YEAR(month) BETWEEN 2022 AND 2024
    GROUP BY YEAR(month), geo
),

growth_rates AS (
    SELECT
        income_pps.year AS income_survey_year,
        income_pps.year - 1 AS income_reference_year,
        annual_hicp.geo,

        ROUND(
            (
                annual_hicp.avg_hicp_food_index /
                LAG(annual_hicp.avg_hicp_food_index) OVER (
                    PARTITION BY annual_hicp.geo
                    ORDER BY income_pps.year
                )
                - 1
            ) * 100,
            2
        ) AS food_hicp_change_pct,

        ROUND(
            (
                income_pps.income_pps /
                LAG(income_pps.income_pps) OVER (
                    PARTITION BY income_pps.geo
                    ORDER BY income_pps.year
                )
                - 1
            ) * 100,
            2
        ) AS income_pps_change_pct

    FROM annual_hicp
    JOIN income_pps
        ON annual_hicp.hicp_year = income_pps.year - 1
        AND annual_hicp.geo = income_pps.geo
),

affordability AS (
    SELECT
        income_reference_year,
        geo,
        food_hicp_change_pct,
        income_pps_change_pct,
        ROUND(
            income_pps_change_pct - food_hicp_change_pct,
            2
        ) AS affordability_change_proxy_pp
    FROM growth_rates
)

SELECT *
FROM affordability
WHERE affordability_change_proxy_pp IS NOT NULL
ORDER BY income_reference_year, geo;

-- Diesel prices: latest observations
SELECT
    month,
    geo,
    diesel_price_per_1000l
FROM diesel_prices
WHERE month >= '2026-01-01'
ORDER BY month, geo;

-- Diesel prices: month-over-month change
WITH diesel_with_previous AS (
    SELECT
        month,
        geo,
        diesel_price_per_1000l,
        LAG(diesel_price_per_1000l) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS previous_month_price
    FROM diesel_prices
)
SELECT
    month,
    geo,
    diesel_price_per_1000l,
    previous_month_price,
    ROUND(
        (
            (diesel_price_per_1000l - previous_month_price)
            / NULLIF(previous_month_price, 0)
        ) * 100,
        2
    ) AS mom_change_pct
FROM diesel_with_previous
WHERE month >= '2026-01-01'
ORDER BY month, geo;

-- Diesel prices: year-over-year change
WITH diesel_with_previous_year AS (
    SELECT
        month,
        geo,
        diesel_price_per_1000l,
        LAG(diesel_price_per_1000l, 12) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS previous_year_price
    FROM diesel_prices
)
SELECT
    month,
    geo,
    diesel_price_per_1000l,
    previous_year_price,
    ROUND(
        (
            (diesel_price_per_1000l - previous_year_price)
            / NULLIF(previous_year_price, 0)
        ) * 100,
        2
    ) AS yoy_change_pct
FROM diesel_with_previous_year
WHERE month >= '2026-01-01'
ORDER BY month, geo;

-- Diesel prices: year-over-year change
WITH diesel_with_previous_year AS (
    SELECT
        month,
        geo,
        diesel_price_per_1000l,
        LAG(diesel_price_per_1000l, 12) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS previous_year_price
    FROM diesel_prices
)
SELECT
    month,
    geo,
    diesel_price_per_1000l,
    DATE_SUB(month, INTERVAL 1 YEAR) AS previous_year_month,
    previous_year_price,
    ROUND(
        (
            (diesel_price_per_1000l - previous_year_price)
            / NULLIF(previous_year_price, 0)
        ) * 100,
        2
    ) AS yoy_change_pct
FROM diesel_with_previous_year
WHERE month >= '2026-01-01'
ORDER BY month, geo;

-- Diesel YoY versus food HICP YoY
WITH diesel_yoy AS (
    SELECT
        month,
        geo,
        diesel_price_per_1000l,
        ROUND(
            (
                diesel_price_per_1000l
                - LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
            * 100,
            2
        ) AS diesel_yoy_pct
    FROM diesel_prices
    WHERE geo IN ('BG', 'DE', 'RO')
),

food_yoy AS (
    SELECT
        month,
        geo,
        hicp_index,
        ROUND(
            (
                hicp_index
                - LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
            * 100,
            2
        ) AS food_hicp_yoy_pct
    FROM hicp_food_index
    WHERE geo IN ('BG', 'DE', 'RO')
)

SELECT
    d.month,
    d.geo,
    d.diesel_yoy_pct,
    f.food_hicp_yoy_pct
FROM diesel_yoy AS d
INNER JOIN food_yoy AS f
    ON d.month = f.month
    AND d.geo = f.geo
WHERE d.month >= '2026-01-01'
ORDER BY d.month, d.geo;

-- Diesel YoY lags versus food HICP YoY
WITH diesel_yoy AS (
    SELECT
        month,
        geo,
        ROUND(
            (
                diesel_price_per_1000l
                - LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
            * 100,
            2
        ) AS diesel_yoy_pct
    FROM diesel_prices
    WHERE geo IN ('BG', 'DE', 'RO')
),

diesel_lags AS (
    SELECT
        month,
        geo,
        diesel_yoy_pct,

        LAG(diesel_yoy_pct, 1) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS diesel_yoy_lag1,

        LAG(diesel_yoy_pct, 2) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS diesel_yoy_lag2,

        LAG(diesel_yoy_pct, 3) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS diesel_yoy_lag3

    FROM diesel_yoy
),

food_yoy AS (
    SELECT
        month,
        geo,
        ROUND(
            (
                hicp_index
                - LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
            * 100,
            2
        ) AS food_hicp_yoy_pct
    FROM hicp_food_index
    WHERE geo IN ('BG', 'DE', 'RO')
)

SELECT
    d.month,
    d.geo,
    d.diesel_yoy_pct,
    d.diesel_yoy_lag1,
    d.diesel_yoy_lag2,
    d.diesel_yoy_lag3,
    f.food_hicp_yoy_pct
FROM diesel_lags AS d
INNER JOIN food_yoy AS f
    ON d.month = f.month
    AND d.geo = f.geo
WHERE d.month >= '2026-01-01'
ORDER BY d.month, d.geo;

-- Correlation between diesel YoY changes and food HICP YoY
WITH diesel_yoy AS (
    SELECT
        month,
        geo,
        (
            (
                diesel_price_per_1000l
                - LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
        ) * 100 AS diesel_yoy_pct
    FROM diesel_prices
    WHERE geo IN ('BG', 'DE', 'RO')
),

diesel_lags AS (
    SELECT
        month,
        geo,
        diesel_yoy_pct,

        LAG(diesel_yoy_pct, 1) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS diesel_yoy_lag1,

        LAG(diesel_yoy_pct, 2) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS diesel_yoy_lag2,

        LAG(diesel_yoy_pct, 3) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS diesel_yoy_lag3

    FROM diesel_yoy
),

food_yoy AS (
    SELECT
        month,
        geo,
        (
            (
                hicp_index
                - LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
        ) * 100 AS food_hicp_yoy_pct
    FROM hicp_food_index
    WHERE geo IN ('BG', 'DE', 'RO')
),

joined_data AS (
    SELECT
        d.month,
        d.geo,
        d.diesel_yoy_pct,
        d.diesel_yoy_lag1,
        d.diesel_yoy_lag2,
        d.diesel_yoy_lag3,
        f.food_hicp_yoy_pct
    FROM diesel_lags AS d
    INNER JOIN food_yoy AS f
        ON d.month = f.month
        AND d.geo = f.geo
    WHERE d.month >= '2023-01-01'
)

SELECT
    geo,

    ROUND(
        (
            AVG(diesel_yoy_pct * food_hicp_yoy_pct)
            - AVG(diesel_yoy_pct) * AVG(food_hicp_yoy_pct)
        )
        /
        NULLIF(
            STDDEV_POP(diesel_yoy_pct)
            * STDDEV_POP(food_hicp_yoy_pct),
            0
        ),
        3
    ) AS correlation_lag0,

    ROUND(
        (
            AVG(diesel_yoy_lag1 * food_hicp_yoy_pct)
            - AVG(diesel_yoy_lag1) * AVG(food_hicp_yoy_pct)
        )
        /
        NULLIF(
            STDDEV_POP(diesel_yoy_lag1)
            * STDDEV_POP(food_hicp_yoy_pct),
            0
        ),
        3
    ) AS correlation_lag1,

    ROUND(
        (
            AVG(diesel_yoy_lag2 * food_hicp_yoy_pct)
            - AVG(diesel_yoy_lag2) * AVG(food_hicp_yoy_pct)
        )
        /
        NULLIF(
            STDDEV_POP(diesel_yoy_lag2)
            * STDDEV_POP(food_hicp_yoy_pct),
            0
        ),
        3
    ) AS correlation_lag2,

    ROUND(
        (
            AVG(diesel_yoy_lag3 * food_hicp_yoy_pct)
            - AVG(diesel_yoy_lag3) * AVG(food_hicp_yoy_pct)
        )
        /
        NULLIF(
            STDDEV_POP(diesel_yoy_lag3)
            * STDDEV_POP(food_hicp_yoy_pct),
            0
        ),
        3
    ) AS correlation_lag3

FROM joined_data
GROUP BY geo
ORDER BY geo;

-- Number of observations used in lag analysis
SELECT
    geo,
    COUNT(*) AS total_rows,
    COUNT(diesel_yoy_pct) AS lag0_observations,
    COUNT(diesel_yoy_lag1) AS lag1_observations,
    COUNT(diesel_yoy_lag2) AS lag2_observations,
    COUNT(diesel_yoy_lag3) AS lag3_observations,
    COUNT(food_hicp_yoy_pct) AS food_yoy_observations
FROM joined_data
GROUP BY geo
ORDER BY geo;

-- Diesel price direction versus food HICP YoY
WITH diesel_yoy AS (
    SELECT
        month,
        geo,
        (
            (
                diesel_price_per_1000l
                - LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
        ) * 100 AS diesel_yoy_pct
    FROM diesel_prices
    WHERE geo IN ('BG', 'DE', 'RO')
),

food_yoy AS (
    SELECT
        month,
        geo,
        (
            (
                hicp_index
                - LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
        ) * 100 AS food_hicp_yoy_pct
    FROM hicp_food_index
    WHERE geo IN ('BG', 'DE', 'RO')
),

joined_data AS (
    SELECT
        d.month,
        d.geo,
        d.diesel_yoy_pct,
        f.food_hicp_yoy_pct
    FROM diesel_yoy AS d
    INNER JOIN food_yoy AS f
        ON d.month = f.month
        AND d.geo = f.geo
    WHERE d.month >= '2023-01-01'
)

SELECT
    geo,

    CASE
        WHEN diesel_yoy_pct > 0 THEN 'diesel_up'
        WHEN diesel_yoy_pct < 0 THEN 'diesel_down'
        ELSE 'diesel_flat'
    END AS diesel_direction,

    COUNT(*) AS observations,

    ROUND(
        AVG(food_hicp_yoy_pct),
        2
    ) AS avg_food_hicp_yoy_pct

FROM joined_data
GROUP BY
    geo,
    diesel_direction
ORDER BY
    geo,
    diesel_direction;

    -- Diesel direction three months earlier versus food HICP YoY
WITH diesel_yoy AS (
    SELECT
        month,
        geo,
        (
            (
                diesel_price_per_1000l
                - LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
        ) * 100 AS diesel_yoy_pct
    FROM diesel_prices
    WHERE geo IN ('BG', 'DE', 'RO')
),

diesel_lags AS (
    SELECT
        month,
        geo,
        diesel_yoy_pct,

        LAG(diesel_yoy_pct, 3) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS diesel_yoy_lag3

    FROM diesel_yoy
),

food_yoy AS (
    SELECT
        month,
        geo,
        (
            (
                hicp_index
                - LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
        ) * 100 AS food_hicp_yoy_pct
    FROM hicp_food_index
    WHERE geo IN ('BG', 'DE', 'RO')
),

joined_data AS (
    SELECT
        d.month,
        d.geo,
        d.diesel_yoy_lag3,
        f.food_hicp_yoy_pct
    FROM diesel_lags AS d
    INNER JOIN food_yoy AS f
        ON d.month = f.month
        AND d.geo = f.geo
    WHERE d.month >= '2023-01-01'
)

SELECT
    geo,

    CASE
        WHEN diesel_yoy_lag3 > 0 THEN 'diesel_up_3m_earlier'
        WHEN diesel_yoy_lag3 < 0 THEN 'diesel_down_3m_earlier'
        ELSE 'diesel_flat_3m_earlier'
    END AS diesel_direction_lag3,

    COUNT(*) AS observations,

    ROUND(
        AVG(food_hicp_yoy_pct),
        2
    ) AS avg_food_hicp_yoy_pct

FROM joined_data
GROUP BY
    geo,
    diesel_direction_lag3
ORDER BY
    geo,
    diesel_direction_lag3;

    -- Lag-3 diesel direction: compact comparison by country
WITH diesel_yoy AS (
    SELECT
        month,
        geo,
        (
            (
                diesel_price_per_1000l
                - LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(diesel_price_per_1000l, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
        ) * 100 AS diesel_yoy_pct
    FROM diesel_prices
    WHERE geo IN ('BG', 'DE', 'RO')
),

diesel_lags AS (
    SELECT
        month,
        geo,
        LAG(diesel_yoy_pct, 3) OVER (
            PARTITION BY geo
            ORDER BY month
        ) AS diesel_yoy_lag3
    FROM diesel_yoy
),

food_yoy AS (
    SELECT
        month,
        geo,
        (
            (
                hicp_index
                - LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                )
            )
            /
            NULLIF(
                LAG(hicp_index, 12) OVER (
                    PARTITION BY geo
                    ORDER BY month
                ),
                0
            )
        ) * 100 AS food_hicp_yoy_pct
    FROM hicp_food_index
    WHERE geo IN ('BG', 'DE', 'RO')
),

joined_data AS (
    SELECT
        d.month,
        d.geo,
        d.diesel_yoy_lag3,
        f.food_hicp_yoy_pct
    FROM diesel_lags AS d
    INNER JOIN food_yoy AS f
        ON d.month = f.month
        AND d.geo = f.geo
    WHERE d.month >= '2023-01-01'
)

SELECT
    geo,

    COUNT(
        CASE
            WHEN diesel_yoy_lag3 > 0
            THEN 1
        END
    ) AS diesel_up_observations,

    COUNT(
        CASE
            WHEN diesel_yoy_lag3 < 0
            THEN 1
        END
    ) AS diesel_down_observations,

    ROUND(
        AVG(
            CASE
                WHEN diesel_yoy_lag3 > 0
                THEN food_hicp_yoy_pct
            END
        ),
        2
    ) AS avg_food_when_diesel_up,

    ROUND(
        AVG(
            CASE
                WHEN diesel_yoy_lag3 < 0
                THEN food_hicp_yoy_pct
            END
        ),
        2
    ) AS avg_food_when_diesel_down,

    ROUND(
        AVG(
            CASE
                WHEN diesel_yoy_lag3 > 0
                THEN food_hicp_yoy_pct
            END
        )
        -
        AVG(
            CASE
                WHEN diesel_yoy_lag3 < 0
                THEN food_hicp_yoy_pct
            END
        ),
        2
    ) AS difference_pp

FROM joined_data
GROUP BY geo
ORDER BY geo;

-- Food affordability: income growth adjusted for food-price growth
-- income growth adjusted for food-price growth

WITH income_reference_year AS (
    SELECT
        year - 1 AS reference_year,
        geo,
        income_pps
    FROM income_pps
),

income_growth AS (
    SELECT
        reference_year,
        geo,
        income_pps,

        (
            (
                income_pps
                - LAG(income_pps) OVER (
                    PARTITION BY geo
                    ORDER BY reference_year
                )
            )
            /
            NULLIF(
                LAG(income_pps) OVER (
                    PARTITION BY geo
                    ORDER BY reference_year
                ),
                0
            )
        ) * 100 AS income_growth_pct

    FROM income_reference_year
),

annual_food_hicp AS (
    SELECT
        YEAR(month) AS year,
        geo,
        AVG(hicp_index) AS annual_food_hicp_index
    FROM hicp_food_index
    WHERE geo IN ('BG', 'DE', 'RO', 'EU27_2020')
    GROUP BY
        YEAR(month),
        geo
),

food_growth AS (
    SELECT
        year,
        geo,
        annual_food_hicp_index,

        (
            (
                annual_food_hicp_index
                - LAG(annual_food_hicp_index) OVER (
                    PARTITION BY geo
                    ORDER BY year
                )
            )
            /
            NULLIF(
                LAG(annual_food_hicp_index) OVER (
                    PARTITION BY geo
                    ORDER BY year
                ),
                0
            )
        ) * 100 AS food_hicp_growth_pct

    FROM annual_food_hicp
)

SELECT
    i.reference_year,
    i.geo,

    ROUND(
        i.income_growth_pct,
        2
    ) AS income_growth_pct,

    ROUND(
        f.food_hicp_growth_pct,
        2
    ) AS food_hicp_growth_pct,

    ROUND(
        i.income_growth_pct
        - f.food_hicp_growth_pct,
        2
    ) AS simple_difference_pp,

    ROUND(
        (
            (
                1 + i.income_growth_pct / 100
            )
            /
            (
                1 + f.food_hicp_growth_pct / 100
            )
            - 1
        ) * 100,
        2
    ) AS food_adjusted_income_growth_pct

FROM income_growth AS i
INNER JOIN food_growth AS f
    ON i.reference_year = f.year
    AND i.geo = f.geo

WHERE i.income_growth_pct IS NOT NULL
ORDER BY
    i.reference_year,
    i.geo;