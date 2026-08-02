# 📁 Structure UNION — CORE FRAMEWORK

> Généré le 02/08 à partir de l'arborescence réelle du repo `union` (branche `main`).
> Remplace l'ancien `Structure_union.md`, obsolète depuis la réorganisation en sous-dossiers
> `manager/` / `persistence/` / `creation/` / `selection/`.

```bash
UNION/
│   .gitignore
│   fxmanifest.lua
│
├── [sql]/
│   └── union.sql
│
├── bridge/                          # Bridge entre ressources (client/server)
│   ├── client/
│   │   ├── k_menu.lua
│   │   ├── kt_character.lua
│   │   ├── kt_hud.lua
│   │   ├── kt_interact_data.lua
│   │   ├── kt_interact_editor.lua   # stub vide (doublon de kt_interact_data)
│   │   ├── kt_rotation.lua
│   │   └── kt_target.lua
│   │
│   └── server/
│       ├── kt_inventory.lua
│       └── statebags.lua
│
├── client/
│   │   main.lua                     # Entry point client
│   │
│   └── modules/
│       ├── bridge/
│       │   └── manager/
│       │       └── exports.lua
│       │
│       ├── character/
│       │   ├── main.lua
│       │   ├── appearance.lua
│       │   ├── creation/
│       │   │   └── create.lua
│       │   ├── manager/
│       │   │   └── characterManager.lua
│       │   └── selection/
│       │       └── select.lua
│       │
│       ├── commands/
│       │   └── manager/
│       │       ├── admin.lua
│       │       ├── bank.lua
│       │       ├── character.lua
│       │       ├── debug.lua
│       │       ├── job.lua
│       │       ├── taginfo.lua
│       │       └── vehicle.lua
│       │
│       ├── components/              # Utilitaires client
│       │   ├── logger.lua
│       │   ├── notifications.lua
│       │   ├── permissions.lua
│       │   └── position.lua
│       │
│       ├── player/
│       │   └── manager/
│       │       └── offline_ped.lua
│       │
│       ├── spawn/
│       │   └── manager/
│       │       ├── main.lua         # déclare Spawn = {}
│       │       └── handler.lua      # seul RegisterNetEvent("union:spawn:apply")
│       │
│       └── vehicle/
│           └── manager/
│               ├── commands.lua
│               └── main.lua
│
├── server/
│   │   main.lua                     # Entry point serveur
│   │
│   ├── components/                  # Utilitaires serveur
│   │   ├── database.lua
│   │   ├── logger.lua
│   │   └── utils.lua
│   │
│   └── modules/
│       ├── auth/
│       │   ├── manager/
│       │   │   ├── characters.lua
│       │   │   ├── connect.lua
│       │   │   ├── identifiers.lua
│       │   │   └── webhooks.lua     # Auth.Webhooks — Discord (login/logout/kick/ban)
│       │   └── selection/
│       │       └── whitelist.lua
│       │
│       ├── bank/
│       │   ├── manager/
│       │   │   └── main.lua
│       │   └── persistence/
│       │       └── database.lua
│       │
│       ├── character/
│       │   ├── main.lua
│       │   ├── appearance.lua
│       │   ├── creation/
│       │   │   └── create.lua
│       │   ├── manager/
│       │   │   └── characterManager.lua
│       │   ├── persistence/
│       │   │   └── database.lua
│       │   └── selection/
│       │       └── select.lua
│       │
│       ├── commands/
│       │   └── manager/
│       │       ├── admin.lua
│       │       ├── bank.lua
│       │       ├── cardlist.lua
│       │       ├── character.lua
│       │       ├── debug.lua
│       │       ├── job.lua
│       │       ├── permission.lua
│       │       └── taginfo.lua
│       │
│       ├── inventory/
│       │   └── manager/
│       │       └── main.lua
│       │
│       ├── job/
│       │   ├── manager/
│       │   │   └── main.lua
│       │   └── persistence/
│       │       └── database.lua
│       │
│       ├── permission/
│       │   ├── manager/
│       │   │   ├── groups.lua
│       │   │   └── main.lua
│       │   └── persistence/
│       │       └── database.lua
│       │
│       ├── player/
│       │   ├── manager/
│       │   │   ├── main.lua
│       │   │   ├── manager.lua
│       │   │   └── offline_ped.lua
│       │   └── persistence/
│       │       └── persistence.lua
│       │
│       ├── spawn/
│       │   ├── manager/
│       │   │   ├── main.lua
│       │   │   └── handler.lua
│       │   └── persistence/
│       │       └── position.lua
│       │
│       └── vehicle/
│           ├── manager/
│           │   ├── commands.lua
│           │   └── main.lua
│           └── persistence/
│               └── database.lua
│
└── shared/
    ├── constants.lua
    ├── locale.lua
    ├── utils.lua
    │
    ├── bridge/
    │   └── bridge_base.lua          # Bridge.create / Bridge.register / pcall wrapper
    │
    ├── config/
    │   ├── config.lua
    │   └── webhooks.lua             # ⚠️ RÉFÉRENCÉ dans fxmanifest.lua MAIS ABSENT DU REPO
    │                                 #    (voir carte Trello "shared/config/webhooks.lua toujours manquant")
    │
    └── locale/
        ├── en.lua
        └── fr.lua
```

## Notes de chargement (ordre fxmanifest.lua)

L'ordre de chargement client/serveur reste géré manuellement par commentaires numérotés
(①②③...) dans `fxmanifest.lua` — pas de vrai module loader avec déclaration de
dépendances (carte Trello "Implémenter le gestionnaire des modules", toujours en cours).

**Client** : components → main.lua → bridges client → spawn/manager/main → character
(creation/selection/manager) → player/manager → character/appearance → vehicle/manager →
commands → bridge/manager/exports → spawn/manager/handler (en dernier, contient le seul
`union:spawn:apply`).

**Serveur** : oxmysql → components → main.lua → bridges serveur → auth → permission
(groups avant main) → player (main avant manager) → character (database avant main,
selection avant manager) → spawn → inventory → vehicle → job → bank (database avant
main) → commands (permission.lua inclus).

## Écarts connus avec le code actuel (à corriger, voir Trello)

- `shared/config/webhooks.lua` est déclaré dans `fxmanifest.lua` (`shared_script`) mais
  n'existe pas dans le repo pour evite les leak donc a creer le webhooks.lua pour que → `Config.webhooks` marche vue pas dispo donc (login/logout/kick/ban) sont Silencieuse voir désactivés.

- Pas de `README.md` à la racine du repo (contrairement à ce que l'ancienne version de ce
  document indiquait).