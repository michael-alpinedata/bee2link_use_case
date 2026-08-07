# Bac à sable

Pour traiter `../etude-de-cas.md`. Tu résous à ta sauce : aucun outil imposé.

## Données : deux bases distinctes

Tout est dans `data/` :

| Chemin | Tables |
|---|---|
| `data/nova/` | `vehicles`, `status_events`, `points_of_sale` (SaaS moderne, historique) |
| `data/legacy/` | `parc`, `statuts`, `concessions` (DMS legacy, snapshot courant sans historique) |
| `data/reseaux.csv` | référence partagée : point de vente vers réseau |

Charge et joins les tables de chaque base (extract/load), puis réconcilie les deux. Les CSV se chargent **en texte** : le typage propre fait partie du travail.

## Choisis ta voie
| Voie | Démarrage |
|---|---|
| SQL / DuckDB | `pip install duckdb` puis `python starter_sql.py` |
| Python / pandas | `pip install pandas` puis `python starter_python.py` |
| dbt / dbt-duckdb | `cd dbt_duckdb && pip install dbt-duckdb && DBT_PROFILES_DIR=. dbt run` |

## Livrables attendus
1. Le **code** (dépôt/notebook/scripts).
2. Le **core de stock** + les **3 marts** (Actuel, Historique, KPI).
3. Le **runner Python** idempotent.
4. Un **`REASONING.md`** court : tes règles, les pièges repérés, tes chiffres. Réponses écrites pour ce qui est design.
5. *(Bonus)* une visualisation du KPI.
