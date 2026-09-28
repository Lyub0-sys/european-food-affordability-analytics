CREATE DATABASE IF NOT EXISTS european_food_affordability_analytics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE european_food_affordability_analytics;

CREATE TABLE IF NOT EXISTS hicp_food_index (
    month DATE NOT NULL,
    geo VARCHAR(16) NOT NULL,
    coicop18 VARCHAR(16) NOT NULL,
    unit VARCHAR(10) NOT NULL,
    freq CHAR(1) NOT NULL,
    hicp_index DECIMAL(10,4) NOT NULL,

    PRIMARY KEY (month, geo, coicop18, unit, freq)
);

CREATE TABLE IF NOT EXISTS income_pps (
    year INT NOT NULL,
    geo VARCHAR(16) NOT NULL,
    income_pps DECIMAL(12,2) NOT NULL,

    PRIMARY KEY (year, geo)
);

CREATE TABLE IF NOT EXISTS household_food_expenditure_share (
    year INT NOT NULL,
    geo VARCHAR(16) NOT NULL,
    food_expenditure_share_pct DECIMAL(5,2) NOT NULL,

    PRIMARY KEY (year, geo)
);

CREATE TABLE IF NOT EXISTS diesel_prices (
    month DATE NOT NULL,
    geo VARCHAR(16) NOT NULL,
    diesel_price_per_1000l DECIMAL(10,4) NOT NULL,

    PRIMARY KEY (month, geo)
);