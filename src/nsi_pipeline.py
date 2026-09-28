from pathlib import Path

import pandas as pd

from src.db import get_connection


PROJECT_ROOT = Path(__file__).resolve().parent.parent

NSI_FILE_PATH = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "nsi"
    / "HH_2.2.3_BGN.xlsx"
)

def load_raw_nsi_data():
    raw_df = pd.read_excel(
        NSI_FILE_PATH,
        sheet_name="par_rashod",
        header=None
    )

    return raw_df

def build_food_share_dataframe(raw_df):
    years = raw_df.iloc[2, 1:].astype(int)

    food_share = raw_df.iloc[46, 1:].astype(float)

    food_share_df = pd.DataFrame(
        {
            "year": years.values,
            "food_expenditure_share_pct": food_share.values
        }
    )

    return food_share_df

def prepare_food_share_db_rows(food_share_df):
    db_df = food_share_df.copy()

    db_df["geo"] = "BG"

    db_df = db_df[
        ["year", "geo", "food_expenditure_share_pct"]
    ]

    db_rows = list(
        db_df.itertuples(index=False, name=None)
    )

    return db_rows

def load_food_share_to_database(db_rows):
    connection = get_connection()
    cursor = connection.cursor()

    insert_sql = """
    INSERT INTO household_food_expenditure_share (
        year,
        geo,
        food_expenditure_share_pct
    )
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE
        food_expenditure_share_pct = VALUES(food_expenditure_share_pct);
    """

    cursor.executemany(insert_sql, db_rows)

    connection.commit()

    cursor.close()
    connection.close()

def run_nsi_pipeline():
    raw_df = load_raw_nsi_data()
    food_share_df = build_food_share_dataframe(raw_df)
    db_rows = prepare_food_share_db_rows(food_share_df)
    load_food_share_to_database(db_rows)

    return len(db_rows)