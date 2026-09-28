from pathlib import Path

import pandas as pd

from src.db import get_connection


PROJECT_ROOT = Path(__file__).resolve().parent.parent

FUEL_FILE_PATH = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "ec_oil"
    / "Weekly_Oil_Bulletin_Prices_History_maticni_4web.xlsx"
)

def load_raw_fuel_data():
    raw_fuel_df = pd.read_excel(
        FUEL_FILE_PATH,
        sheet_name="Prices with taxes",
        header=None
    )

    return raw_fuel_df

def build_weekly_diesel_dataframe(raw_fuel_df):
    diesel_df = raw_fuel_df.iloc[
        3:,
        [0, 3, 32, 55, 189]
    ].copy()

    diesel_df.columns = [
        "date",
        "EU",
        "BG",
        "DE",
        "RO"
    ]

    diesel_df["date"] = pd.to_datetime(
        diesel_df["date"],
        errors="coerce"
    )

    diesel_df = diesel_df.dropna(
        subset=["date"]
    ).copy()

    for geo in ["EU", "BG", "DE", "RO"]:
        diesel_df[geo] = pd.to_numeric(
            diesel_df[geo],
            errors="coerce"
        )

    return diesel_df

def build_monthly_diesel_dataframe(diesel_df):
    comparison_df = diesel_df[
        diesel_df["date"] >= "2008-01-07"
    ].copy()

    monthly_diesel_df = (
        comparison_df
        .set_index("date")[["EU", "BG", "DE", "RO"]]
        .resample("MS")
        .mean()
        .reset_index()
    )

    return monthly_diesel_df

def build_long_diesel_dataframe(monthly_diesel_df):
    monthly_diesel_long_df = monthly_diesel_df.melt(
        id_vars="date",
        value_vars=["EU", "BG", "DE", "RO"],
        var_name="geo",
        value_name="diesel_price_per_1000l"
    )

    monthly_diesel_long_df = monthly_diesel_long_df.rename(
        columns={"date": "month"}
    )

    monthly_diesel_long_df = monthly_diesel_long_df.sort_values(
        ["month", "geo"]
    ).reset_index(drop=True)

    return monthly_diesel_long_df

def prepare_diesel_db_rows(monthly_diesel_long_df):
    db_rows = list(
        monthly_diesel_long_df.itertuples(
            index=False,
            name=None
        )
    )

    return db_rows

def load_diesel_to_database(db_rows):
    connection = get_connection()
    cursor = connection.cursor()

    insert_sql = """
    INSERT INTO diesel_prices (
        month,
        geo,
        diesel_price_per_1000l
    )
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE
        diesel_price_per_1000l = VALUES(diesel_price_per_1000l);
    """

    cursor.executemany(
        insert_sql,
        db_rows
    )

    connection.commit()

    cursor.close()
    connection.close()

def run_fuel_pipeline():
    raw_fuel_df = load_raw_fuel_data()

    diesel_df = build_weekly_diesel_dataframe(
        raw_fuel_df
    )

    monthly_diesel_df = build_monthly_diesel_dataframe(
        diesel_df
    )

    monthly_diesel_long_df = build_long_diesel_dataframe(
        monthly_diesel_df
    )

    db_rows = prepare_diesel_db_rows(
        monthly_diesel_long_df
    )

    load_diesel_to_database(
        db_rows
    )

    return len(db_rows)