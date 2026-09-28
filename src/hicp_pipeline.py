import pandas as pd
import requests
from src.db import get_connection

EUROSTAT_URL = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/prc_hicp_minr"


def fetch_hicp_data():
    params = {
        "lang": "EN",
        "freq": "M",
        "unit": "I25",
        "coicop18": "CP01",
        "geo": ["BG", "RO", "DE", "EU27_2020"],
        "sinceTimePeriod": "2022-01",
        "untilTimePeriod": "2026-08"
    }

    response = requests.get(
        EUROSTAT_URL,
        params=params,
        timeout=30
    )

    response.raise_for_status()

    return response.json()


def build_hicp_dataframe(data):
    geo_index = data["dimension"]["geo"]["category"]["index"]
    geo_labels = data["dimension"]["geo"]["category"]["label"]
    time_index = data["dimension"]["time"]["category"]["index"]

    geo_codes = sorted(geo_index, key=geo_index.get)
    time_periods = sorted(time_index, key=time_index.get)

    values = data["value"]

    rows = []
    value_position = 0

    for geo in geo_codes:
        for period in time_periods:
            rows.append({
                "geo": geo,
                "country": geo_labels[geo],
                "month": period,
                "hicp_index": values.get(str(value_position))
            })
            value_position += 1

    return pd.DataFrame(rows)


def prepare_db_rows(df):
    load_df = df.copy()

    load_df["month"] = pd.to_datetime(load_df["month"]).dt.date
    load_df["coicop18"] = "CP01"
    load_df["unit"] = "I25"
    load_df["freq"] = "M"

    db_rows = list(
        load_df[
            ["month", "geo", "coicop18", "unit", "freq", "hicp_index"]
        ].itertuples(index=False, name=None)
    )

    return db_rows

def load_hicp_to_database(db_rows):
    connection = get_connection()
    cursor = connection.cursor()

    insert_sql = """
    INSERT INTO hicp_food_index (
        month,
        geo,
        coicop18,
        unit,
        freq,
        hicp_index
    )
    VALUES (?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
        hicp_index = VALUES(hicp_index);
    """

    cursor.executemany(insert_sql, db_rows)

    connection.commit()

    cursor.close()
    connection.close()

def run_hicp_pipeline():
    data = fetch_hicp_data()
    df = build_hicp_dataframe(data)
    db_rows = prepare_db_rows(df)
    load_hicp_to_database(db_rows)

    return len(db_rows)