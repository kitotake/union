# 📚 Documentation Complète - Union Framework

## 🎯 Vue d'ensemble

**Union Framework** est un framework de roleplay modulaire développé pour **FiveM** (GTA V). Il s'agit d'une base de données complète et extensible conçue pour gérer les systèmes essentiels d'un serveur de roleplay, notamment :

- Authentification des joueurs
- Gestion multi-personnages
- Personnalisation d'apparence
- Inventaire persistent
- Système de jobs et grades
- Gestion bancaire
- Système de statuts des joueurs
- Sauvegarde automatique des données

---

## 🏗️ Architecture Générale

### Principes fondamentaux

1. **Modularité** : Chaque système est isolé dans son propre dossier
2. **Bridge System** : Système de pont pour communiquer avec d'autres ressources
3. **Séparation Client/Server** : Code client et serveur strictement séparés
4. **Configuration centralisée** : Tous les paramètres dans `shared/config/`

### Dépendances

| Dépendance | Rôle | Status |
|-----------|------|--------|
| **kt_lib** | Librairie utilitaire de base | ✅ Requis |
| **oxmysql** | Gestion de la base de données | ✅ Requis |
| **kt_inventory** | Système d'inventaire | ⏳ En développement |
| **kt_character** | Gestion des personnages | ✅ Bridge intégré |
| **kt_hud** | HUD utilisateur | ✅ Bridge intégré |
| **kt_target** | Système de ciblage | ✅ Bridge intégré |
| **kt_interact** | Système d'interaction | ✅ Bridge intégré |

---

## 📁 Structure des dossiers

### 1. **Dossier Root**
```
union/
├── fxmanifest.lua          # Manifeste de la ressource FiveM
├── README.md               # Documentation rapide
├── Structure_union.md      # Vue de la structure
└── [sql]/
    └── union.sql           # Schéma de base de données
```

### 2. **Dossier Shared** - Code partagé Client/Server

```
shared/
├── constants.lua           # Constantes globales
├── utils.lua               # Fonctions utilitaires
├── locale.lua              # Système de localisation
├── bridge/
│   └── bridge_base.lua     # Base du système de bridge
└── config/
    ├── config.lua          # Configuration principale
    ├── status_config.lua    # Configuration des statuts
    └── webhooks.lua        # Webhooks Discord
```

**Fichiers importants :**

- **constants.lua** : Définit les constantes utilisées partout (valeurs de jobs, IDs, etc.)
- **utils.lua** : Fonctions utilitaires partagées (validation, conversion, etc.)
- **config.lua** : Paramètres principaux du serveur (positions de spawn, limites, etc.)
- **status_config.lua** : Configuration des systèmes de statuts (faim, soif, etc.)

---

### 3. **Dossier Client** - Code côté joueur

#### Structure générale
```
client/
├── main.lua                    # Point d'entrée client
└── modules/
    ├── bridge/                 # Interface avec autres ressources
    │   └── exports.lua         # Exports client
    │
    ├── character/              # Gestion des personnages
    │   ├── main.lua           # Logique principale
    │   ├── characterManager.lua # Gestionnaire de personnages
    │   ├── create.lua         # Création de personnage
    │   └── select.lua         # Sélection de personnage
    │
    ├── commands/               # Commandes chat
    │   ├── admin.lua          # Commandes admin
    │   ├── character.lua      # Commandes personnage
    │   ├── bank.lua           # Commandes bancaires
    │   ├── vehicle.lua        # Commandes véhicules
    │   ├── job.lua            # Commandes jobs
    │   ├── taginfo.lua        # Informations des tags
    │   └── debug.lua          # Commandes debug
    │
    ├── components/             # Utilitaires client
    │   ├── logger.lua         # Logging
    │   ├── notifications.lua  # Notifications
    │   ├── permissions.lua    # Système de permissions
    │   └── position.lua       # Gestion des positions
    │
    ├── player/                 # Gestion du joueur
    │   ├── offline_ped.lua    # PED hors ligne
    │   └── status/
    │       └── status_client.lua  # Système de statuts
    │
    ├── spawn/                  # Système de spawn
    │   ├── main.lua
    │   └── handler.lua
    │
    └── vehicle/                # Gestion des véhicules
        ├── main.lua
        └── commands.lua
```

#### Modules clés

**Character Module** ⭐
- Permet au joueur de créer un nouveau personnage
- Sélection entre plusieurs personnages créés
- Chargement des données du personnage
- Initialisation de l'apparence et des attributs

**Commands Module**
- Commandes de debug (`/pos`, `/tp`, etc.)
- Commandes admin (`/give`, `/kill`, etc.)
- Commandes jobs
- Commandes bancaires

**Components**
- **notifications.lua** : Affiche des notifications (TÓast, center, top-right)
- **permissions.lua** : Gère les droits d'accès
- **position.lua** : Sauvegarde/charge les positions du joueur

---

### 4. **Dossier Server** - Code côté serveur

```
server/
├── main.lua                    # Point d'entrée serveur
├── components/                 # Utilitaires serveur
│   ├── database.lua           # Gestion base de données
│   ├── logger.lua             # Logging serveur
│   └── utils.lua              # Fonctions utilitaires
│
└── modules/
    ├── auth/                   # Authentification
    │   ├── connect.lua        # Connexion joueur
    │   ├── characters.lua     # Gestion des personnages
    │   ├── identifiers.lua    # Identifiants (Steam, Discord, License)
    │   ├── whitelist.lua      # Système de whitelist
    │   └── webhooks.lua       # Webhooks de connexion
    │
    ├── character/              # Gestion personnage
    │   ├── main.lua
    │   ├── characterManager.lua
    │   ├── create.lua
    │   ├── select.lua
    │   ├── appearance.lua     # Gestion apparence
    │   └── database.lua
    │
    ├── bank/                   # Système bancaire
    │   ├── main.lua
    │   └── database.lua
    │
    ├── job/                    # Gestion des jobs
    │   ├── main.lua
    │   └── database.lua
    │
    ├── permission/             # Système de permissions
    │   ├── main.lua
    │   ├── groups.lua
    │   └── database.lua
    │
    ├── player/                 # Gestion joueur global
    │   ├── main.lua
    │   ├── manager.lua
    │   ├── persistence.lua    # Persistance des données
    │   ├── offline_ped.lua
    │   └── status/
    │       ├── manager.lua
    │       └── status_tick.lua
    │
    ├── inventory/              # Système inventaire
    │   └── main.lua
    │
    ├── vehicle/                # Gestion véhicules
    │   ├── main.lua
    │   ├── database.lua
    │   └── commands.lua
    │
    └── commands/               # Commandes serveur
        ├── admin.lua
        ├── character.lua
        ├── job.lua
        ├── bank.lua
        ├── permission.lua
        ├── taginfo.lua
        └── debug.lua
```

#### Modules clés

**Auth Module** 🔐
- Authentifie le joueur via ses identifiants (Steam, Discord, License)
- Gère la whitelist
- Initialise la première connexion
- Envoie des webhooks Discord

**Character Module** 👤
- Crée les personnages dans la base de données
- Charge les données (apparence, position, etc.)
- Gère la sélection entre plusieurs personnages
- Sauvegarde les modifications d'apparence

**Player Module** 👥
- Gère les données globales du joueur en mémoire
- Synchronise l'état du joueur avec les clients
- Gère les statuts (faim, soif, etc.)
- Sauvegarde la persistance des données

**Job Module** 💼
- Gère les jobs et les grades
- Associe les joueurs à des organisations
- Vérifie les permissions basées sur les jobs

**Permission Module** 🔒
- Système de groupes et permissions
- Vérifie l'accès aux commandes et fonctionnalités
- Gère les rôles admin/modérateur

---

### 5. **Dossier Bridge** - Intégration avec d'autres ressources

```
bridge/
├── client/                     # Bridges client
│   ├── k_menu.lua
│   ├── kt_character.lua
│   ├── kt_hud.lua
│   ├── kt_interact_data.lua
│   ├── kt_interact_editor.lua
│   ├── kt_rotation.lua
│   └── kt_target.lua
│
└── server/                     # Bridges serveur
    ├── kt_inventory.lua
    └── statebags.lua
```

**Qu'est-ce qu'un bridge ?**

Un bridge est une couche d'abstraction qui permet à Union de communiquer avec d'autres ressources sans dépendre directement de leur code interne. Cela facilite les mises à jour et les remplacements.

**Exemples :**
- `kt_character.lua` : Interface avec la ressource de personnage
- `kt_hud.lua` : Affiche les informations HUD
- `kt_target.lua` : Utilise le système de ciblage

---

## 🔄 Flux d'exécution

### Au démarrage du serveur
1. Chargement de `kt_lib` (dépendance commune)
2. Chargement des scripts **shared** (constants, config, bridge base)
3. Chargement du code **server** (components, puis modules)
4. Chargement du code **client** (components, bridges, puis modules)

### À la connexion d'un joueur

```
1. EVENT: playerConnecting
   └─ Récupération des identifiants (Steam, Discord, License)

2. AUTH MODULE
   └─ Vérification whitelist
   └─ Vérification base de données
   └─ Création compte si nouvelle connexion

3. CHARACTER SELECTION
   └─ Chargement liste personnages
   └─ Affichage UI de sélection
   └─ Chargement données personnage (apparence, position, etc.)

4. SPAWN
   └─ Initialisation joueur
   └─ Définition apparence
   └─ Positionnement joueur
   └─ Synchronisation avec clients

5. PLAYER INITIALIZATION
   └─ Chargement job/grade
   └─ Synchronisation data
   └─ Active UI (HUD, inventaire, etc.)
```

---

## 💾 Base de Données

### Schéma SQL

**Fichier** : `[sql]/union.sql`

Tables principales :

| Table | Rôle |
|-------|------|
| `players` | Informations joueur (identifiants, permissions) |
| `characters` | Personnages créés (nom, DOB, apparence) |
| `character_appearance` | Détails apparence (vêtements, tattoos) |
| `player_status` | Statuts temporaires (faim, soif, position) |
| `jobs` | Définition des jobs/organisations |
| `job_grades` | Grades disponibles dans chaque job |
| `player_job` | Association joueur-job |
| `banks` | Comptes bancaires |
| `permissions` | Permissions par groupe |

### Interaction avec la DB

**Côté serveur** : Utilise `oxmysql` via `db:execute()`, `db:fetch()`, etc.

**Exemple** :
```lua
local character = db:fetch('SELECT * FROM characters WHERE id = ?', {charId})
db:execute('UPDATE player_status SET health = ? WHERE character_id = ?', {100, charId})
```

---

## 🎮 Systèmes clés

### 1. Système de Personnages
- ✅ Multi-personnages (plusieurs slots)
- ✅ Création de personnage (apparence, nom, etc.)
- ✅ Sélection au login
- ⏳ Suppression de personnage

### 2. Système d'Authentification
- ✅ Identifiants multiples (Steam, Discord, License)
- ✅ Whitelist (optionnel)
- ✅ Webhooks Discord
- ✅ Protection contre les doublons

### 3. Système de Jobs
- ✅ Assignation de job/grade
- ✅ Hiérarchie (patron, employés)
- ✅ Permissions basées sur les jobs

### 4. Système de Permissions
- ✅ Groupes de permissions
- ✅ Commandes protégées (admin, modérateur)
- ✅ Vérification granulaire

### 5. Système Bancaire
- ✅ Comptes bancaires persistants
- ✅ Dépôts/retraits
- ⏳ Transferts entre comptes

### 6. Apparence & Customisation
- ✅ Vêtements
- ✅ Tatouages
- ✅ Propriétés physiques (poids, couleur cheveux, etc.)

### 7. Statuts joueur
- ✅ Faim, soif, hygiène
- ✅ Santé, armure
- ✅ Abus de drogues
- ⏳ Système de tick continu (status_tick.lua)

---

## 🔧 Configuration

### `shared/config/config.lua`

Paramètres principaux :

```lua
Config = {
    -- Positions de spawn par défaut
    DefaultSpawnPos = {x = 100, y = 200, z = 50, h = 0},
    
    -- Limite de personnages par joueur
    MaxCharacters = 3,
    
    -- Apparence par défaut (nouveau perso)
    DefaultAppearance = { ... },
    
    -- Jobs disponibles
    Jobs = { ... },
}
```

### `shared/config/status_config.lua`

Configuration des systèmes de statuts (faim, soif, etc.)

### `shared/config/webhooks.lua`

Webhooks Discord pour les logs d'événements

---

## 📦 Installation & Démarrage

### Prérequis
- FiveM Server
- [oxmysql](https://github.com/overextended/oxmysql)
- [kt_lib](https://github.com/kitotake/kt_lib)
- Base de données MySQL

### Étapes d'installation

1. **Placer les ressources** :
   ```
   resources/[ox]/oxmysql/
   resources/[ox]/kt_lib/
   resources/[server]/union/
   ```

2. **Importer la base de données** :
   ```bash
   mysql < union.sql
   ```

3. **Configuration** :
   - Éditer `shared/config/config.lua`
   - Configurer les positions de spawn
   - Configurer les webhooks Discord (optionnel)

4. **Démarrer le serveur** :
   ```
   ensure oxmysql
   ensure kt_lib
   ensure union
   ```

---

## 🚀 Commandes Principales

### Admin
- `/give [player_id] [amount]` - Donner de l'argent
- `/kill [player_id]` - Tuer un joueur
- `/kick [player_id] [raison]` - Expulser un joueur
- `/ban [player_id] [durée] [raison]` - Bannir un joueur

### Joueur
- `/pos` - Afficher sa position actuelle
- `/job` - Afficher son job et grade
- `/bank` - Ouvrir l'interface bancaire
- `/character` - Sélectionner un personnage

### Debug
- `/status` - Afficher statuts joueur
- `/data` - Afficher données personnage
- `/reload` - Recharger la ressource

---

## 🔌 API & Exports

### Côté Client

**Charger un personnage** :
```lua
exports['union']:loadCharacter(characterId)
```

**Obtenir données joueur** :
```lua
local playerData = exports['union']:getPlayerData()
```

**Afficher notification** :
```lua
exports['union']:notify("Message", "info")
```

### Côté Serveur

**Ajouter argent joueur** :
```lua
exports['union']:addMoney(playerId, amount)
```

**Assigner job** :
```lua
exports['union']:setJob(playerId, jobName, grade)
```

**Vérifie permission** :
```lua
if exports['union']:hasPermission(playerId, 'admin') then
    -- ...
end
```

---

## 📊 Architecture Données

### Hiérarchie des données

```
Player (Steam ID, Discord ID, License)
├── Character 1
│   ├── Appearance
│   ├── Status (Health, Hunger, Thirst)
│   ├── Job & Grade
│   └── Position
├── Character 2
│   └── ...
└── Character 3
    └── ...

Banks
├── Account Player 1
├── Account Player 2
└── ...

Permissions
├── Group Admin
├── Group Moderator
└── Group User
```

---

## 🛠️ Développement

### Ajouter un nouveau module

1. Créer dossier : `client/modules/monmodule/` et `server/modules/monmodule/`
2. Créer `main.lua` pour la logique
3. Importer dans `fxmanifest.lua`
4. Ajouter bridge si intégration externe nécessaire

### Ajouter une nouvelle commande

**Côté client** : Dans `client/modules/commands/`, créer un fichier et enregistrer avec `RegisterCommand()`

**Côté serveur** : Dans `server/modules/commands/`, créer un fichier et utiliser `RegisterCommand()`

### Logging

```lua
-- Client
Client.Logger:log("Mon message")
Client.Logger:error("Erreur")

-- Server
Server.Logger:log("Mon message")
Server.Logger:error("Erreur")
```

---

## ⚠️ Points à noter

- ✅ **Production-ready** : Framework mature et bien structuré
- ⏳ **En développement** : Inventaire (kt_inventory), sauvegarde auto
- 🔒 **Sécurité** : Validation côté serveur obligatoire
- 📈 **Scalabilité** : Architecture modulaire permet l'ajout de nouvelles fonctionnalités
- 🐛 **Debug** : Fichiers `debug.lua` pour tests

---

## 📝 Résumé

**Union Framework** est une base solide pour un serveur de roleplay FiveM. Il fournit :

✅ Authentification robuste  
✅ Gestion multi-personnages  
✅ Système de jobs/permissions  
✅ Persistance des données  
✅ Architecture modulaire et extensible  
✅ Intégration facile avec autres ressources (via bridge system)

C'est un excellent point de départ pour personnaliser et construire ton propre serveur !

---

**Version** : 3.6  
**Auteur** : Kitotake  
**Technologie** : FiveM, Lua, MySQL, oxmysql
