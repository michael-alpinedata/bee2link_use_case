"""
runner.py - Orchestrateur du pipeline dbt & DuckDB avec contrôle de qualité, logs et paramètre de date.
"""

import sys
import time
import subprocess
import logging
import argparse
from datetime import date
from pathlib import Path

# Configuration des logs
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("Bee2LinkRunner")

DBT_PROJECT_DIR = Path("./dbt_duckdb") 

def run_command(cmd, cwd=None):
    """Exécute une commande shell et lève une exception en cas d'erreur."""
    logger.info(f"Exécution : {' '.join(cmd)}")
    start = time.time()
    result = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    duration = time.time() - start
    
    if result.returncode != 0:
        logger.error(f"Échec de la commande (Code {result.returncode}) :")
        logger.error(result.stderr)
        raise RuntimeError(f"Erreur lors de l'exécution de : {' '.join(cmd)}")
    
    logger.info(f"Succès ({duration:.2f}s)\n{result.stdout.strip()}")

def main():
    parser = argparse.ArgumentParser(description="Orchestrateur du pipeline dbt Bee2Link")
    parser.add_argument(
        "--date", 
        type=str, 
        default="2026-08-01", 
        help="Date de référence cible au format YYYY-MM-DD (par défaut: 2026-08-01)"
    )
    args = parser.parse_args()
    
    target_date = args.date
    logger.info(f"=== INITIALISATION PIPELINE DATA BEE2LINK (Cible : {target_date}) ===")
    
    try:
        # 1. Vérification des dépendances dbt
        logger.info("Étape 1 : Installation des dépendances dbt...")
        run_command(["dbt", "deps"], cwd=DBT_PROJECT_DIR)

        # 2. Ingestion des Seeds / Fichiers CSV sources (si applicable)
        logger.info("Étape 2 : Chargement des tables sources / seeds...")
        run_command(["dbt", "seed"], cwd=DBT_PROJECT_DIR)

        # 3. Exécution des modèles dbt avec injection dynamique de la date cible
        logger.info(f"Étape 3 : Exécution de la transformation des modèles dbt (target_date={target_date})...")
        run_command([
            "dbt", "run", 
            "--vars", f'{{"target_date": "{target_date}"}}'
        ], cwd=DBT_PROJECT_DIR)

        # 4. Exécution des tests de qualité (Unicité, Non-Null, Tests Métier)
        logger.info("Étape 4 : Exécution des tests de qualité de données (dbt test)...")
        run_command(["dbt", "test"], cwd=DBT_PROJECT_DIR)

        # 5. Génération de la documentation dbt
        logger.info("Étape 5 : Génération du catalogue de données dbt docs...")
        run_command(["dbt", "docs", "generate"], cwd=DBT_PROJECT_DIR)
 
        logger.info("=== PIPELINE EXÉCUTÉ AVEC SUCCÈS ===")

    except Exception as e:
        logger.critical(f"Interruption du pipeline suite à une erreur : {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()