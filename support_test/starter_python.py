"""Voie Python : charge les deux bases dans des DataFrames (texte brut). pip install pandas"""
import os, glob, pandas as pd

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
tables = {}
for db in ("nova", "legacy"):
    for path in glob.glob(os.path.join(DATA, db, "*.csv")):
        name = f"{db}.{os.path.splitext(os.path.basename(path))[0]}"
        tables[name] = pd.read_csv(path, dtype=str)

tables["reseaux"] = pd.read_csv(os.path.join(DATA, "reseaux.csv"), dtype=str)

if __name__ == "__main__":
    for name, df in tables.items():
        print(f"== {name} ==")
        print(df.to_string(index=False))
