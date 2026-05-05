# 📁 Structure UNION # CORE FRAMEWORK

```bash
UNION/
│   .gitignore
│   fxmanifest.lua
│   README.md
│
├── bridge/                     # Bridge entre ressources (client/server)
│   ├── client/
│   │   ├── kt_character.lua
│   │   ├── kt_hud.lua
│   │   ├── kt_interact_data.lua
│   │   ├── kt_interact_editor.lua
│   │   ├── kt_rotation.lua
│   │   ├── kt_target.lua
│   │   └── k_menu.lua
│   │
│   └── server/
│       ├── kt_inventory.lua
│       └── statebags.lua
│
├── client/
│   │   main.lua
│   │
│   └── modules/                # Modules client
│       ├── bridge/
│       │   └── exports.lua
│       │
│       ├── character/
│       │   ├── characterManager.lua
│       │   ├── create.lua
│       │   ├── main.lua
│       │   └── select.lua
│       │
│       ├── commands/
│       │   ├── admin.lua
│       │   ├── bank.lua
│       │   ├── character.lua
│       │   ├── debug.lua
│       │   ├── job.lua
│       │   ├── taginfo.lua
│       │   └── vehicle.lua
│       │
│       ├── components/         # Utilitaires client
│       │   ├── logger.lua
│       │   ├── notifications.lua
│       │   ├── permissions.lua
│       │   └── position.lua
│       │
│       ├── player/
│       │   │   offline_ped.lua
│       │   │
│       │   └── status/
│       │       └── status_client.lua
│       │
│       ├── spawn/
│       │   ├── handler.lua
│       │   └── main.lua
│       │
│       └── vehicle/
│           ├── commands.lua
│           └── main.lua
│
├── server/
│   │   main.lua
│   │
│   ├── components/             # Utilitaires serveur
│   │   ├── database.lua
│   │   ├── logger.lua
│   │   └── utils.lua
│   │
│   └── modules/                # Modules serveur
│       ├── auth/
│       │   ├── characters.lua
│       │   ├── connect.lua
│       │   ├── identifiers.lua
│       │   ├── webhooks.lua
│       │   └── whitelist.lua
│       │
│       ├── bank/
│       │   ├── database.lua
│       │   └── main.lua
│       │
│       ├── character/
│       │   ├── appearance.lua
│       │   ├── characterManager.lua
│       │   ├── create.lua
│       │   ├── database.lua
│       │   ├── main.lua
│       │   └── select.lua
│       │
│       ├── commands/
│       │   ├── admin.lua
│       │   ├── bank.lua
│       │   ├── character.lua
│       │   ├── debug.lua
│       │   ├── job.lua
│       │   └── taginfo.lua
│       │
│       ├── inventory/
│       │   └── main.lua
│       │
│       ├── job/
│       │   ├── database.lua
│       │   └── main.lua
│       │
│       ├── permission/
│       │   ├── database.lua
│       │   ├── groups.lua
│       │   └── main.lua
│       │
│       ├── player/
│       │   ├── main.lua
│       │   ├── manager.lua
│       │   ├── offline_ped.lua
│       │   ├── persistence.lua
│       │   │
│       │   └── status/
│       │       ├── manager.lua
│       │       └── status_tick.lua
│       │
│       ├── spawn/
│       │   ├── handler.lua
│       │   ├── main.lua
│       │   └── position.lua
│       │
│       └── vehicle/
│           ├── commands.lua
│           ├── database.lua
│           └── main.lua
│
├── shared/                     # Code partagé client/server
│   ├── constants.lua
│   ├── locale.lua
│   ├── utils.lua
│   │
│   ├── bridge/
│   │   └── bridge_base.lua
│   │
│   ├── config/
│   │   ├── config.lua
│   │   ├── status_config.lua
│   │   └── webhooks.lua
│   │
│   └── locale/
│       ├── en.lua
│       └── fr.lua
│
└── [sql]/                     # Base de données
    └── union.sql
```

---

## 🧠 Notes

* `bridge/` → communication inter-ressources
* `client/modules/` → logique client modulaire
* `server/modules/` → logique serveur (auth, job, inventory, etc.)
* `components/` → utilitaires (logger, db, utils…)
* `shared/` → code commun (config, constantes, locale)
* `[sql]/` → structure base de données

---

## ⚠️ Bonnes pratiques

* Séparer clairement **modules métier** et **composants utilitaires**
* Garder `shared/` léger (pas de logique lourde)
* Éviter la duplication client/server inutile
* Centraliser la logique DB dans `server/components/database.lua`

---

## 🚀 Améliorations possibles

---
