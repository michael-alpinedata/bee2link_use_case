# Documentation des Sources & Dictionnaire de Données (avec Exemples)

Ce document recense les spécifications techniques, les types et des exemples de valeurs concrètes issus des fichiers sources des deux systèmes (**Nova** et **Legacy**) ainsi que du référentiel réseau.

---

## 1. Système Legacy (`support_test/data/legacy/`)

Le système Legacy représente l'ancien DMS français. Il fournit une vue instantanée du stock (snapshot au `2026-07-31`) sans historique de logs.

### Table `parc.csv`
- **Fréquence** : Snapshot journalier
- **Grain** : 1 ligne par véhicule présent ou récemment sorti

| Colonne | Type Brut | Exemple de Valeur | Description & Règles Métier |
| :--- | :--- | :--- | :--- |
| `i_veh_id` | INTEGER | `200`, `203`, `204` | Identifiant local du véhicule. *Non unique globalement*. |
| `tenant_id` | INTEGER | `1`, `34` | Identifiant du tenant / groupe concessionnaire. |
| `i_pve_id` | INTEGER | `1`, `2`, `9` | Identifiant de la concession / Point de Vente. |
| `vin` | VARCHAR | `VIN_P` | Numéro de série du châssis. |
| `s_veh_marque` | VARCHAR | `RENAULT`, `PEUGEOT` | Libellé de la marque en majuscules. |
| `s_veh_modele` | VARCHAR | `Captur`, `2008` | Libellé du modèle. |
| `s_veh_energie` | VARCHAR | `Essence`, `Diesel` | Carburant/Énergie. |
| `i_veh_km` | INTEGER | `15000`, `0` | Kilométrage au compteur. |
| `d_veh_date_mec` | DATE | `2021-03-15` | Date de première Mise En Circulation (MEC). |
| `s_veh_plaque` | VARCHAR | `JJ-203-JJ` | Plaque d'immatriculation du véhicule. |
| `f_veh_prix_rentree` | DECIMAL | `12500.00` | Prix de revient / d'achat du véhicule (€). |
| `f_veh_prix_vente` | DECIMAL | `14900.00` | Prix de vente affiché en concession (€). |
| `i_veh_configuration`| INTEGER | `0`, `1`, `2`, `3` | Enum : `0` & `3` = VN, `1` = VO, `2` = VD. |
| `i_veh_destination`  | INTEGER | `1`, `2`, `4`, `999` | Enum : `1` = Particulier, `2` = Marchand, `3` = Enchériste, `4` = Casse, `999` = Non renseigné. |
| `i_veh_statut` | INTEGER | `100`, `103`, `200`, `300` | Code statut courant (`statuts.csv`). |
| `d_veh_date_entree_stock` | DATE | `2026-01-18` | Date d'entrée physique du véhicule en concession. |
| `d_veh_date_sortie` | DATE | `2026-07-24`, *NULL* | Date de sortie effective (NULL si toujours en stock). |
| `snapshot_date` | DATE | `2026-07-31` | Date d'extraction de la photo du parc. |

### Table `statuts.csv`
Référentiel des statuts du DMS Legacy.
- `i_statut` (INTEGER) : `100`, `103`, `200`, `300`
- `i_veh_configuration` (INTEGER) : `0`, `1`, `2`, `3`
- `s_libelle` (VARCHAR) : `"Pré-entrée VO"`, `"Stock de vente VO"`, `"Commande usine VN"`

### Table `concessions.csv`
Points de vente du réseau Legacy.
- `i_pve_id` (INTEGER / String) : `1`, `2`, `9`
- `tenant_id` (INTEGER) : `1`, `34`
- `s_nom_concession` (VARCHAR) : `"Concession Lille Nord"`, `"Garage Marseille"`

---

## 2. Système Nova (`support_test/data/nova/`)

Le système Nova est un SaaS moderne anglophone fournissant un historique d'événements de changement de statut.

### Table `vehicles.csv`
- **Grain** : 1 ligne par fiche véhicule créée

| Colonne | Type Brut | Exemple de Valeur | Description & Règles Métier |
| :--- | :--- | :--- | :--- |
| `vehicle_id` | INTEGER | `100`, `105`, `106` | Identifiant local du véhicule. *Collision possible entre tenants*. |
| `tenant_id` | INTEGER | `2`, `5` | Identifiant du tenant SaaS. |
| `pos_id` | VARCHAR | `POS1`, `POS2`, `POS3` | Identifiant du Point de Vente Nova. |
| `vin` | VARCHAR | `VIN_A`, `VIN_H` | Numéro de série châssis. |
| `make` | VARCHAR | `Citroen`, `Peugeot` | Marque du véhicule. |
| `model` | VARCHAR | `C3`, `2008` | Modèle du véhicule. |
| `energy` | VARCHAR | `electric`, `petrol` | Énergie / Motorisation. |
| `mileage` | INTEGER | `0`, `25000` | Kilométrage. |
| `first_registration` | DATE | `2023-05-10` | Date de première immatriculation. |
| `plate` | VARCHAR | `HH-105-HH` | Plaque d'immatriculation. |
| `entry_price` | DECIMAL | `18500.00` | Prix d'achat / rentrée. |
| `listing_price` | DECIMAL | `21000.00` | Prix affiché. |
| `configuration` | INTEGER | `1`, `2`, `3` | Enum : `1` = NEW (VN), `2` = DEMO (VD), `3` = USED (VO). |
| `destination` | INTEGER | `1`, `2`, `3` | Enum : `1` = private, `2` = professional, `3` = scrapyard. |

### Table `status_events.csv`
- **Grain** : 1 ligne par événement de statut (log d'historique)

| Colonne | Type Brut | Exemple de Valeur | Description & Règles Métier |
| :--- | :--- | :--- | :--- |
| `event_id` | VARCHAR | `e1`, `e16`, `e49` | Identifiant d'événement (prefixé par 'e'). |
| `vehicle_id` | INTEGER | `100`, `102` | Identifiant du véhicule. |
| `tenant_id` | INTEGER | `2`, `5` | Identifiant du tenant. |
| `status_type` | INTEGER | `1`, `5`, `7`, `13` | Code de statut Nova (ex: `1`=UNCO, `5`=PHEN, `7..13`=PREP). |
| `status_from` | DATE | `2026-07-19` | Date de prise d'effet du statut. |

### Table `points_of_sale.csv`
- `pos_id` (VARCHAR) : `POS1`, `POS2`, `POS3`, `POS4`
- `tenant_id` (INTEGER) : `2`, `5`
- `pos_name` (VARCHAR) : `"Nova Store Lille"`, `"Nova Store Marseille"`

---

## 3. Référentiel Partagé (`support_test/data/reseaux.csv`)

Permet la correspondance territoriale des identifiants POS/Concession vers les réseaux commerciaux.

| Colonne | Type Brut | Exemple de Valeur | Description |
| :--- | :--- | :--- | :--- |
| `source_system` | VARCHAR | `nova`, `legacy` | Système source d'origine. |
| `pos_id` | VARCHAR | `POS1`, `POS2`, `1`, `2`, `9` | Identifiant du point de vente (`POSx` pour Nova, `i_pve_id` pour Legacy). |
| `reseau` | VARCHAR | `nord`, `sud` | Secteur géographique rattaché. |