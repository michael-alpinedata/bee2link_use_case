# REASONING.md — Architecture & Choix de Modélisation (Test Technique Bee2link)

## 1. Vision Globale & Stratégie d'Architecture

L'objectif de ce projet est d'unifier deux sources de données hétérogènes (**Nova**, SaaS multi-tenant moderne orienté événements, et **Legacy**, DMS historique orienté snapshot courant) au sein d'un **Modèle de Données Canonique (CDM)** unifié, fiable et historisé.

Nous avons retenu une architecture en 3 couches dbt/DuckDB :

```text
  [ Nova CSVs ]      [ Legacy CSVs ]     [ Reseaux Ref ]
        │                   │                   │
        ▼                   ▼                   ▼
  ┌───────────┐       ┌───────────┐       ┌───────────┐
  │  Staging  │       │  Staging  │       │  Staging  │  Typage, nettoyage, déduplication,
  └─────┬─────┘       └─────┬─────┘       └─────┬─────┘  décodage des enums
        │                   │                   │
        └─────────┬─────────┴───────────────────┘
                  ▼
         ┌────────────────┐
         │  Intermediate  │  Reconstruction temporelle (LEAD),
         │     (Core)     │  Surrogate Keys, Réconciliation
         └───────┬────────┘
                 │
      ┌──────────┼──────────┐
      ▼          ▼          ▼
   ┌──────┐   ┌──────┐   ┌──────┐
   │ Mart │   │ Mart │   │ Mart │  Marts métiers (Nord, Sud, Déstockage)
   │ Nord │   │ Sud  │   │ Pilot│
   └──────┘   └──────┘   └──────┘

```

---

## 2. Traitement des Pièges & Traitement en Staging

L'exploration des données brutes a permis d'isoler plusieurs cas particuliers intégrés directement dans la couche de staging (`models/staging/`) :

### A. Isolation Multi-Tenant & Clés Primaires

* **Anomalie** : L'identifiant `vehicle_id` (ou `i_veh_id`) n'est pas unique à l'échelle globale. Dans Nova, `vehicle_id = 100` appartient simultanément au tenant `2` (POS1) et au tenant `5` (POS3).
* **Règle Staging** : Création d'une Surrogate Key composite unique calculée pour chaque véhicule :
`stock_vehicle_id = md5(concat_ws('||', source_system, tenant_id, raw_vehicle_id))`

### B. Déduplication des Événements Nova

* **Anomalie** : Les lignes `e16` et `e49` du log `status_events.csv` sont des doublons stricts (`vehicle_id 102`, `tenant_id 2`, `status_type 7`, `status_from 2026-07-19`).
* **Règle Staging** : Application d'une déduplication explicite (`DISTINCT`) dans `stg_nova__status_events` pour éviter les doublons lors du calcul de fenêtrage d'historique.

### C. Normalisation des Référentiels Métier (Enums)

* **Configurations** :
* Nova (`1`=NEW, `2`=DEMO, `3`=USED) $\rightarrow$ `VN`, `VD`, `VO`.
* Legacy (`0` et `3`=VN, `1`=VO, `2`=VD) $\rightarrow$ `VN`, `VD`, `VO`.


* **Destinations** :
* Legacy : `1` $\rightarrow$ `private`, `2` et `3` $\rightarrow$ `professional`, `4` $\rightarrow$ `scrapyard`, `999` $\rightarrow$ `unknown`.


* **Statuts** :
* Nova : `1`=UNCO, `6`=PREN, `5`=PHEN, `7..13`=PREP, `2`=SAST, `3`=DELI, `4`=EXIT.
* Legacy : Mappage des codes `10x`, `20x`, `30x` vers le dictionnaire canonique (`UNCO`, `PREN`, `PHEN`, `PREP`, `SAST`, `DELI`, `EXIT`).


## 3. Reconstruction Métier du Core Temporel (`int_stock__periods`)

Le Core réconcilie Nova et Legacy sous un modèle temporel unifié : **1 ligne par véhicule × période de statut**.

### Alignement des Périodes :
1. **Nova** : Utilisation d'une fonction fenêtre `LEAD(status_date)` groupée par `stock_vehicle_id` et triée par `status_date ASC, event_seq ASC`. La date de fin d'un statut correspond à la date de début du statut suivant.
2. **Legacy** : Chaque véhicule du snapshot est modélisé par une période allant de `entry_stock_date` à `exit_stock_date` (NULL si le véhicule est présent).
3. **Périmètres de Stock** :
   - `is_in_stock = TRUE` si le statut appartient à `('PHEN', 'PREP', 'SAST', 'DELI')`.
   - `is_in_stock_excl_delivery = TRUE` si le statut appartient à `('PHEN', 'PREP', 'SAST')`.