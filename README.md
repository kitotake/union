# 🐴 Union Framework

Framework roleplay développé pour FiveM (GTA V), construit avec **oxmysql**, et des systèmes personnalisés pour la gestion des joueurs, personnages, inventaire, apparence et sauvegarde.

---

## 🚀 Fonctionnalités principales

- 🔐 Système de connexion via identifiants (Steam, Discord, license)
- 👤 Gestion multi-personnages avec `unique_id` pour chaque slot
- 💼 Support de jobs, grades et affiliations
- 🧍 Apparence & tatouages persistants
- 🎒 Inventaire `kt_inventory` automatique par personnage -- pas encore dispo
- 💾 Sauvegarde automatique (position, santé, etc.) -- pas encore dispo
- 📦 Structure modulaire : `server/`, `client/`, `shared/`

---

## 📁 Structure

-- pas encore dispo

---

## 🧩 Dépendances

- [kt_inventory](https://overextended.dev/)
- [oxmysql](https://github.com/overextended/oxmysql)

---

## 📦 Installation

1. Clone ou télécharge la ressource dans ton dossier `resources/`
2. Ajoute `ensure union` dans ton `server.cfg`
3. Assure-toi que toutes les dépendances (`oxmysql`, etc.) sont installées et démarrées avant.

---

## 🔐 Configuration

Dans `shared/config.lua`, définissez les positions de spawn par défaut :

