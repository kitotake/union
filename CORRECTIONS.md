# 🔧 Corrections Union Framework v3.7

## Bugs critiques corrigés

### 1. ⚠️ CRITIQUE — Double `RegisterNetEvent("union:spawn:apply")` côté client
**Fichiers** : `client/modules/spawn/main.lua` et `client/modules/spawn/handler.lua`

L'ancien `client/modules/spawn/main.lua` était une **copie exacte** du fichier handler contenant `RegisterNetEvent("union:spawn:apply")`. Résultat : deux handlers s'exécutaient à chaque spawn → double modèle, double position, comportement imprévisible.

**Correction** : `client/modules/spawn/main.lua` ne contient plus que `Spawn.initialize()` et `Spawn.respawn()`. Le seul `RegisterNetEvent("union:spawn:apply")` est dans `handler.lua`.

---

### 2. ⚠️ CRITIQUE — `server/modules/spawn/main.lua` contenait du code CLIENT
**Fichier** : `server/modules/spawn/main.lua`

Ce fichier serveur était une **copie du fichier client** avec `PlayerPedId()`, `SetPlayerModel()`, `Bridge.Character:isAvailable()`, etc. Ces natives n'existent pas côté serveur → crash au démarrage.

**Correction** : Réécrit comme un vrai module serveur léger.

---

### 3. ⚠️ CRITIQUE — `bridge/client/kt_interact_editor.lua` en doublon
**Fichier** : `bridge/client/kt_interact_editor.lua`

Copie identique de `kt_interact_data.lua`. Les deux enregistraient `Bridge.InteractData` → le second écrasait le premier silencieusement, causant des comportements aléatoires.

**Correction** : `kt_interact_editor.lua` est maintenant un fichier vide (stub commenté).

---

## Bugs non-critiques corrigés

### 4. Clés de locale manquantes
**Fichiers** : `shared/locale/en.lua`, `shared/locale/fr.lua`

`character.reload_success` et `character.reload_failed` étaient utilisées dans `client/modules/character/main.lua` mais absentes des fichiers de locale → affichage de la clé brute.

**Correction** : Clés ajoutées dans `en.lua` et `fr.lua`.

### 5. `print` debug oublié dans `character/main.lua`
**Fichier** : `client/modules/character/main.lua`

`print ("Character reload event received...")` laissé par accident.

**Correction** : Supprimé.

### 6. `Config.character.defaultArmor` incohérent
**Fichier** : `shared/config/config.lua`

`defaultArmor = 100` dans la config mais `armor = 0` partout dans le code.

**Correction** : `defaultArmor = 0`.

### 7. `table.getn` deprecated (Lua 5.4)
**Fichier** : `server/modules/player/offline_ped.lua`

`table.getn` n'existe plus en Lua 5.4 (FiveM). Remplacé par un compteur manuel.

### 8. `OfflinePed.create()` appelé sans `excludeSrc`
**Fichier** : `server/modules/player/manager.lua`

L'appel à `OfflinePed.create()` ne passait pas `src` comme paramètre d'exclusion.

**Correction** : `OfflinePed.create({...}, src)`.

### 9. `client/modules/vehicle/commands.lua` — doublon supprimé
Ce fichier était vide intentionnellement mais avait des doublons potentiels. Commentaire clarifié.

---

## Fichiers modifiés

| Fichier | Type de correction |
|---------|-------------------|
| `client/modules/spawn/main.lua` | **CRITIQUE** — suppression duplicate handler |
| `server/modules/spawn/main.lua` | **CRITIQUE** — réécriture (était du code client) |
| `bridge/client/kt_interact_editor.lua` | **CRITIQUE** — vidé (était un doublon) |
| `shared/locale/en.lua` | Clés manquantes ajoutées |
| `shared/locale/fr.lua` | Clés manquantes ajoutées |
| `client/modules/character/main.lua` | Suppression print debug |
| `shared/config/config.lua` | defaultArmor corrigé |
| `server/modules/player/offline_ped.lua` | table.getn → compteur manuel |
| `server/modules/player/manager.lua` | excludeSrc passé à OfflinePed.create |
| `fxmanifest.lua` | Version bump 3.6→3.7, commentaires FIX |
