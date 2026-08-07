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

---

## 3. Reconstruction Métier du Core Temporel (`int_stock__periods`)

Le Core réconcilie Nova et Legacy sous un modèle temporel unifié : **1 ligne par véhicule × période de statut**.

### Alignement des Périodes :
1. **Nova** : Utilisation d'une fonction fenêtre `LEAD(status_date)` groupée par `stock_vehicle_id` et triée par `status_date ASC, event_seq ASC`. La date de fin d'un statut correspond à la date de début du statut suivant.
2. **Legacy** : Chaque véhicule du snapshot est modélisé par une période allant de `entry_stock_date` à `exit_stock_date` (NULL si le véhicule est présent).
3. **Périmètres de Stock** :
   - `is_in_stock = TRUE` si le statut appartient à `('PHEN', 'PREP', 'SAST', 'DELI')`.
   - `is_in_stock_excl_delivery = TRUE` si le statut appartient à `('PHEN', 'PREP', 'SAST')`.

---

## 4. Conception et Implémentation des Data Marts (`models/marts/`)

Les Data Marts transforment le modèle temporel unifié (`int_stock__periods`) en tables décisionnelles directement consommables par les métiers (Power BI, rapports constructeur, alertes commerciales).

---

### Mart 1 : `fct_stock_courant_nord` (Pilotage Concession Local)

* **Périmètre métier** : Réseau Nord uniquement (`reseau = 'nord'`).
* **Grain** : 1 ligne par véhicule présent en stock à la date de référence (**2026-08-01**).
* **Choix d'architecture** :
* Table « flat » dénormalisée prête à l'emploi (sans jointure nécessaire pour l'outil de BI).
* Segmentation de l'ancienneté en tranches d'âge standardisées (`0-30`, `31-60`, `61-90`, `91-180`, `181-365`, `>365`).
* Ingestion des prix (entrée et affiché) ainsi que du flag de présence hors livraison (`is_in_stock_excl_delivery`).



#### Réponses aux questions de contrôle (Mart Nord)

* **Nombre total de véhicules dans ce mart** : **30**
* **Nombre de véhicules en stock depuis plus de 365 jours** : **11** (soit **36,7 %** du stock Nord immobilisé depuis plus d'un an).

---

### Mart 2 : `fct_stock_historique_constructeur` (Historique Sud Anonymisé)

* **Périmètre métier** : Réseau Sud uniquement (`reseau = 'sud'`).
* **Grain** : 1 ligne par véhicule × période de statut (historique complet, véhicules sortis inclus).
* **Anonymisation & Respect contractuel** :
* Exclusion stricte des identifiants et données financières sensibles : ni `vin`, ni `plate`, ni `entry_price`, ni `listing_price`.
* Calcul de la durée en jours passée dans chaque statut (`days_in_status`).


* **Support des requêtes Point-in-Time** :
Le modèle autorise la reconstitution exacte du parc à n'importe quelle date passée $T$ via la condition :
```sql
WHERE period_start_date <= T
  AND (period_end_date > T OR period_end_date IS NULL)
  AND is_in_stock = TRUE

```



#### Documentation : Requête d'audit au 01/05/2026

```sql
SELECT COUNT(DISTINCT stock_vehicle_id) AS total_sud_stock
FROM fct_stock_historique_constructeur
WHERE period_start_date <= DATE '2026-05-01'
  AND (period_end_date > DATE '2026-05-01' OR period_end_date IS NULL)
  AND is_in_stock = TRUE;

```

#### Réponse à la question de contrôle (Mart Sud)

* **Nombre de véhicules du périmètre Sud en stock au 01/05/2026** : **16**

---

### Mart 3 : `fct_pilotage_destockage` (Détection des Immobilisations & Surstocks)

* **Périmètre métier** : Tous réseaux (Nord + Sud).
* **Grain** : 1 ligne par véhicule actuellement présent en stock au **2026-08-01**.
* **Justification du périmètre de comparaison & Benchmark** :
1. **Groupe principal** : Calcul de la durée moyenne de rotation `entry_stock_date → EXIT` par couple `(configuration_code, make)` sur l'historique des véhicules vendus/sortis (`canonical_status = 'EXIT'`). Cela compare des véhicules homogènes (ex: un VO Peugeot face aux autres VO Peugeot).
2. **Traitement des durées non exploitables** :
* Exclusion des saisies incohérentes où la date de sortie précède la date d'entrée (`period_start_date <= entry_stock_date`).
* **Fallback automatique** : Si un couple `(configuration, marque)` n'a pas assez d'historique de vente, la moyenne globale de la `configuration_code` (`VN`, `VD` ou `VO`) est appliquée dynamiquement via un `COALESCE`.


3. **Seuil d'alerte** : Un véhicule est marqué `is_overstock_alert = TRUE` lorsque son ancienneté dépasse **1,5 × la durée moyenne de rotation** de son groupe.



#### Réponses aux questions de contrôle (Mart Déstockage)

* **Durée moyenne de rotation par type de véhicule (`configuration_code`)** :
* **VN** (Véhicule Neuf) : **16,5 jours** (rotation fluide)
* **VO** (Véhicule d'Occasion) : **196,4 jours** (rotation modérée)
* **VD** (Véhicule de Démonstration) : **644,6 jours** (forte anomalie de rétention)


* **Nombre total de véhicules ressortant en alerte de surstockage** : **12**

---

## 5. Synthèse des Résultats de Contrôle

| Mart / Périmètre | Indicateur Métier | Valeur Calculée |
| --- | --- | --- |
| **fct_stock_courant_nord** | Total véhicules en stock (01/08/2026) | **30** |
| **fct_stock_courant_nord** | Véhicules immobilisés > 365 jours | **11** |
| **fct_stock_historique_constructeur** | Stock Point-in-Time au 01/05/2026 | **16** |
| **fct_pilotage_destockage** | Rotation moyenne VN | **16,5 jours** |
| **fct_pilotage_destockage** | Rotation moyenne VO | **196,4 jours** |
| **fct_pilotage_destockage** | Rotation moyenne VD | **644,6 jours** |
| **fct_pilotage_destockage** | Véhicules en alerte de surstockage | **12** |

---