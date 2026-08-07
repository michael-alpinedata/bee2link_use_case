"""
runner.py - Orchestrateur du pipeline dbt & DuckDB avec contrôle de qualité et logs.
"""

import sys
import time
import subprocess
import logging
from pathlib import Path

# Configuration des logs
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("Bee2LinkRunner")

DBT_PROJECT_DIR = Path("./dbt_duckdb")  # Répertoire du projet dbt

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
    logger.info("=== INITIALISATION DU PIPELINE DATA BEE2LINK ===")
    
    try:
        # 1. Vérification des dépendances dbt
        logger.info("Étape 1 : Installation des dépendances dbt...")
        run_command(["dbt", "deps"], cwd=DBT_PROJECT_DIR)

        # 2. Ingestion des Seeds / Fichiers CSV sources
        logger.info("Étape 2 : Chargement des tables sources / seeds...")
        run_command(["dbt", "seed"], cwd=DBT_PROJECT_DIR)

        # 3. Exécution des modèles dbt (Staging -> Intermediate -> Marts)
        logger.info("Étape 3 : Exécution de la transformation des modèles dbt...")
        run_command(["dbt", "run"], cwd=DBT_PROJECT_DIR)

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