import pandas as pd
import requests

from src.db import get_connection


EUROSTAT_INCOME_URL = (
    "https://ec.europa.eu/eurostat/api/dissemination/"
    "statistics/1.0/data/ilc_di03"
)


def fetch_income_data():
    params = {
        "lang": "EN",
        "freq": "A",
        "age": "TOTAL",
        "sex": "T",
        "statinfo": "MED_EI",
        "unit": "PPS",
        "geo": ["BG", "RO", "DE", "EU27_2020"],
        "sinceTimePeriod": "2023",
        "untilTimePeriod": "2025"
    }

    response = requests.get(
        EUROSTAT_INCOME_URL,
        params=params,
        timeout=30
    )

    response.raise_for_status()

    return response.json()


def build_income_dataframe(data):
    geo_index = data["dimension"]["geo"]["category"]["index"]
    geo_labels = data["dimension"]["geo"]["category"]["label"]
    time_index = data["dimension"]["time"]["category"]["index"]

    geo_codes = sorted(geo_index, key=geo_index.get)
    years = sorted(time_index, key=time_index.get)

    values = data["value"]

    rows = []
    value_position = 0

    for geo in geo_codes:
        for year in years:
            income_value = values.get(str(value_position))

            if income_value is not None:
                rows.append(
                    {
                        "year": int(year),
                        "geo": geo,
                        "country": geo_labels[geo],
                        "income_pps": income_value
                    }
                )

            value_position += 1

    return pd.DataFrame(rows)


def prepare_income_db_rows(df):
    db_rows = list(
        df[
            ["year", "geo", "income_pps"]
        ].itertuples(index=False, name=None)
    )

    return db_rows


def load_income_to_database(db_rows):
    connection = get_connection()
    cursor = connection.cursor()

    insert_sql = """
    INSERT INTO income_pps (
        year,
        geo,
        income_pps
    )
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE
        income_pps = VALUES(income_pps);
    """

    cursor.executemany(insert_sql, db_rows)

    connection.commit()

    cursor.close()
    connection.close()


def run_income_pipeline():
    data = fetch_income_data()
    df = build_income_dataframe(data)
    db_rows = prepare_income_db_rows(df)
    load_income_to_database(db_rows)

    return len(db_rows)