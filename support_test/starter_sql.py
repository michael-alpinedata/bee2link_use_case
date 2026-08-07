"""Voie SQL : charge les deux bases dans DuckDB (schemas nova/legacy, texte brut). pip install duckdb"""
import os, glob, duckdb

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
con = duckdb.connect(":memory:")
for db in ("nova", "legacy"):
    con.execute(f"CREATE SCHEMA {db}")
    for path in glob.glob(os.path.join(DATA, db, "*.csv")):
        table = os.path.splitext(os.path.basename(path))[0]
        p = path.replace("'", "''")
        con.execute(f"CREATE TABLE {db}.{table} AS SELECT * FROM read_csv('{p}', header=true, all_varchar=true)")

p = os.path.join(DATA, "reseaux.csv").replace("'", "''")
con.execute(f"CREATE TABLE reseaux AS SELECT * FROM read_csv('{p}', header=true, all_varchar=true)")

if __name__ == "__main__":
    print(con.sql("SELECT table_schema, table_name FROM information_schema.tables ORDER BY 1,2"))
