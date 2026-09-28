# European Food Affordability Analytics

**Food prices, incomes and purchasing power across Europe**

European Food Affordability Analytics is a Python, SQL and MariaDB data project that examines food-price dynamics and relative food affordability across selected European economies.

The project combines data from Eurostat, the Bulgarian National Statistical Institute (NSI), and the European Commission Weekly Oil Bulletin.

The current analysis focuses on:

- Bulgaria
- Germany
- Romania
- EU27 aggregate where methodologically appropriate

---

## Project goals

The project addresses four main questions:

1. How have food prices changed over time?
2. Has income growth kept pace with food-price growth?
3. How has the share of Bulgarian household expenditure spent on food changed over time?
4. Is there a descriptive lagged relationship between diesel-price changes and food inflation?

The project is designed both as:

- a data analytics / data engineering portfolio project;
- an applied research project demonstrating reproducible quantitative analysis.

---

## Technology stack

- Python 3.11
- pandas
- requests
- Matplotlib
- MariaDB
- SQL
- Jupyter Notebook
- python-dotenv

---

## Data sources

### Eurostat Food HICP

Dataset:

`prc_hicp_minr`

Food category:

`CP01 — Food and non-alcoholic beverages`

Unit:

`I25 — index, 2025 = 100`

Geographies:

- BG
- DE
- RO
- EU27_2020

The HICP series measures price-index dynamics and should not be interpreted as absolute food prices in euros.

---

### Eurostat income

Median equivalised net income in Purchasing Power Standards (PPS).

Geographies:

- BG
- DE
- RO
- EU27_2020

Available survey years:

- 2023
- 2024
- 2025

For the affordability analysis, the EU-SILC survey year is aligned with its income reference year:

- survey year 2023 → income reference year 2022
- survey year 2024 → income reference year 2023
- survey year 2025 → income reference year 2024

---

### Bulgarian National Statistical Institute

Household expenditure data for Bulgaria are taken from the NSI household budget statistics.

The project tracks the share of monetary household expenditure allocated to:

**Food and non-alcoholic beverages**

Period:

`2008–2025`

This indicator is interpreted as a descriptive measure of household expenditure structure and not as a direct measure of welfare.

---

### European Commission Weekly Oil Bulletin

Historical diesel prices are taken from the European Commission Weekly Oil Bulletin.

The project uses:

**Prices with taxes**

Original unit:

`EUR per 1000 litres`

Countries used in the diesel-food comparison:

- Bulgaria
- Germany
- Romania

Weekly observations are aggregated to monthly averages before analysis.

The European Commission `EU` aggregate is not directly matched with Eurostat `EU27_2020`, because the aggregate definitions are not assumed to be methodologically identical.

---

## Data pipeline

```text
Eurostat APIs / NSI Excel / European Commission Excel
                         ↓
                      Python
               requests + pandas
                         ↓
                 cleaning / validation
                         ↓
                      MariaDB
                         ↓
                    SQL analysis
                         ↓
                      pandas
                         ↓
                    Matplotlib
                         ↓
              interpretation / outputs