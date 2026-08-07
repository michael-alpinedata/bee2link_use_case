# Étude de cas : Analytics / Data Engineer

## Contexte

On unifie deux systèmes sources décrivant le même métier : le **stock de véhicules**.

- **Nova** : SaaS moderne, multi-tenant (`tenant_id`). Fournit l'**historique complet** des statuts (log d'événements).
- **Legacy** : logiciel en migration, multi-tenant (`tenant_id`). Fournit seulement un **snapshot courant** (aucun historique).

Le stock est une donnée **temporelle** : un véhicule traverse plusieurs statuts avant de sortir. Ton travail : en faire un modèle propre, puis en tirer **3 tables de sortie (marts)**, chacune destinée à un usage précis.

## Cadre

- **2-3 h attendues, ne dépasse pas 3 h 30.** Les LLM (Claude, etc.) sont **autorisés** : on ne juge pas ta vitesse de frappe mais tes choix, qu'on creusera en visio.
- **Outils libres** : SQL/DuckDB, Python, dbt. Bac à sable et données dans `support_test/` (3 voies de démarrage, dbt non requis). Le chargement brut t'est fourni ; **le typage, la structure de staging et les jointures sont à toi.**
- **Lis les données avant de coder.** Elles contiennent des cas particuliers volontaires.

## Les sources : deux bases distinctes

Deux bases séparées (`support_test/data/nova/` et `support_test/data/legacy/`), plus un fichier de référence partagé. Commence par les **charger et les explorer**, puis joins-les.

**`nova/`** (SaaS moderne, anglais), historique dans un log d'événements :
- `vehicles` : `vehicle_id, tenant_id, vin, make, model, energy, mileage, first_registration, plate, entry_price, listing_price, destination, configuration, pos_id`
- `status_events` : `event_id, vehicle_id, tenant_id, status_type, status_from`
- `points_of_sale` : `pos_id, tenant_id, pos_name`

**`legacy/`** (DMS legacy, français), snapshot courant sans historique :
- `parc` : `i_veh_id, tenant_id, vin, s_veh_marque, s_veh_modele, s_veh_energie, i_veh_km, d_veh_date_mec, s_veh_plaque, f_veh_prix_rentree, f_veh_prix_vente, i_veh_destination, i_veh_configuration, i_pve_id, i_veh_statut, d_veh_date_entree_stock, d_veh_date_sortie, snapshot_date`
- `statuts` : `i_statut, i_veh_configuration, s_libelle` (référentiel des statuts)
- `concessions` : `i_pve_id, tenant_id, s_nom_concession`

**Référence partagée** : `data/reseaux.csv`, colonnes `source_system, pos_id, reseau`. Rattache chaque point de vente à un réseau commercial (`nord` ou `sud`).

## Dictionnaires

### Cycle de vie canonique (les codes cibles du DWH)

| Code | Étape | En stock ? |
|---|---|---|
| `UNCO` | Commande usine | non |
| `PREN` | Pré-entrée | non |
| `PHEN` | Entrée physique | **oui** |
| `PREP` | Préparation | **oui** |
| `SAST` | Stock de vente | **oui** |
| `DELI` | En livraison | **oui** |
| `EXIT` | Sortie | non |

**Règle** : un véhicule est **en stock** quand son statut courant est `PHEN`, `PREP`, `SAST` ou `DELI`. Certains consommateurs demandent en plus une variante **hors livraison** (`PHEN`, `PREP`, `SAST` seulement).

### Nova : `status_type` vers code canonique
`1` = UNCO · `6` = PREN · `5` = PHEN · **`7` à `13` = PREP** (toutes les activités de préparation : mécanique, esthétique, photos, contrôle technique…) · `2` = SAST · `3` = DELI · `4` = EXIT

### Legacy : statuts
Le référentiel est dans la table `statuts`, avec des libellés en français à rattacher aux codes canoniques.

### Configuration (type de véhicule)
- **Nova** `configuration` : `1` = NEW (véhicule neuf) · `2` = DEMO (véhicule de démonstration) · `3` = USED (occasion)
- **Legacy** `i_veh_configuration` : `0` et `3` = VN (neuf) · `1` = VO (occasion) · `2` = VD (démonstration)

### Destination
- **Nova** `destination`, référentiel **canonique** : `1` = private · `2` = professional · `3` = scrapyard *(Nova n'émet jamais 4)*
- **Legacy** `i_veh_destination`, codes bruts : `1` = Particulier · `2` = Marchand · `3` = Enchériste · `4` = Casse · `999` = Non renseigné

### Date de référence
« Aujourd'hui » = **`2026-08-01`**.

## Tâches

### 1. Core de stock
Charge et joins les tables de chaque base, puis réconcilie l'historique Nova et le snapshot Legacy en **un modèle historisé unique** (une période de statut par véhicule). Harmonise statuts, configuration et destination vers un canonique commun, avec une **clé** qui identifie un véhicule de stock à travers sources et tenants.

Explique **pourquoi** ta structure rendra les 3 marts ci-dessous faciles à produire.

### 2. Mart `stock_courant_nord` : alimente un dashboard Power BI concession
Périmètre : réseau **nord**. Grain : **1 ligne par véhicule en stock** à la date de référence.

Table large, prête à consommer sans jointure supplémentaire : clé, système source, concession, attributs véhicule (marque, modèle, énergie, km, VIN, plaque), configuration, destination, code de statut canonique, date d'entrée en stock, date du statut courant, **jours en stock**, **tranche d'âge** (`0-30`, `31-60`, `61-90`, `91-180`, `181-365`, `>365`), prix d'entrée et prix affiché, et les flags utiles au consommateur (dont la variante **hors livraison**).

**Question de contrôle** : combien de véhicules ce mart contient-il, et combien sont en stock depuis plus de 365 jours ?

### 3. Mart `stock_historique_constructeur` : livré à un constructeur
Périmètre : réseau **sud**. Grain : **1 ligne par véhicule × période de statut**, tous véhicules (sortis inclus).

Contrainte contractuelle : **aucune donnée identifiante** (pas de VIN, pas de plaque, pas de prix). Colonnes : clé, concession, marque/modèle, configuration, code canonique, début/fin de période, jours dans le statut, flags (période courante, en stock).

Le constructeur doit pouvoir interroger le stock **à une date passée** : documente la requête qui donne le stock au `2026-05-01`.

**Question de contrôle** : combien de véhicules de ce périmètre étaient en stock au `2026-05-01` ?

### 4. Mart `pilotage_destockage` : équipe commerciale (interne)
Tous réseaux. Grain : **1 ligne par véhicule encore en stock**, enrichie d'un repère de comparaison :
- son âge en stock et sa tranche d'âge,
- la **durée moyenne de rotation de son groupe de comparaison** (entrée → sortie, calculée sur les véhicules déjà sortis). **À toi de définir le bon périmètre de comparaison et de le justifier.**
- un **flag d'alerte** quand le véhicule dépasse nettement la norme de son groupe.

Précise ce que tu fais des véhicules dont la durée n'est pas exploitable.

**Question de contrôle** : quelle est la durée moyenne de rotation pour chaque type de véhicule (VN, VD, VO), et combien de véhicules ressortent en alerte ?

### 5. Runner
Un point d'entrée **Python** qui exécute tout le pipeline, **idempotent** (rejouable sans doublon), avec la date de référence en paramètre. *(dbt : enrobe `dbt run` ; SQL pur : exécute tes scripts dans l'ordre.)*

---

Dans un court `REASONING.md` : tes règles, les **cas particuliers repérés** et ce que tu as décidé d'en faire, tes hypothèses, et les **réponses aux 3 questions de contrôle**.

## Rendu
Dépôt/notebook/scripts + `REASONING.md`. On finit par une **visio de 45-60 min** où on relit ta copie ensemble.
