import os
from pathlib import Path
import duckdb

def main():
    # Racines des dossiers
    root_dir = Path(__file__).resolve().parent.parent
    dbt_dir = root_dir / "dbt_duckdb"

    # Se placer dans dbt_duckdb pour que les chemins relatifs (../data/...) soient exacts
    os.chdir(dbt_dir)

    # Connexion à sandbox.duckdb (dans dbt_duckdb ou la racine selon où elle est générée)
    db_file = dbt_dir / "sandbox.duckdb" if (dbt_dir / "sandbox.duckdb").exists() else root_dir / "sandbox.duckdb"
    con = duckdb.connect(str(db_file))
    
    print("\n=== ANSWERS TO CONTROL QUESTIONS ===")
    
    # 1. Mart Nord
    nord = con.execute("""
        SELECT 
            COUNT(*) AS total,
            SUM(CASE WHEN is_over_365_days THEN 1 ELSE 0 END) AS over_365
        FROM fct_stock_courant_nord
    """).fetchone()
    print(f"Nord Stock Total: {nord[0]} | Over 365d: {nord[1]}")

    # 2. Mart Sud (Point-in-Time 2026-05-01)
    sud = con.execute("""
        SELECT COUNT(DISTINCT stock_vehicle_id)
        FROM fct_stock_historique_constructeur
        WHERE period_start_date <= DATE '2026-05-01'
          AND (period_end_date > DATE '2026-05-01' OR period_end_date IS NULL)
          AND is_in_stock = TRUE
    """).fetchone()
    print(f"Sud Stock at 2026-05-01: {sud[0]}")

    # 3. Pilotage Déstockage
    destock = con.execute("""
        SELECT configuration_code, ROUND(AVG(group_avg_rotation_days), 1)
        FROM fct_pilotage_destockage
        GROUP BY 1 ORDER BY 1
    """).fetchall()
    print(f"Avg Rotation Days: {dict(destock)}")

    alerts = con.execute("""
        SELECT COUNT(*) FROM fct_pilotage_destockage WHERE is_overstock_alert = TRUE
    """).fetchone()
    print(f"Overstock Alerts Count: {alerts[0]}\n")

if __name__ == "__main__":
    main()