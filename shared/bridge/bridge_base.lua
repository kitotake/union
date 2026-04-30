-- shared/bridge_base.lua
-- Pattern de base pour tous les bridges Union Framework
-- Ce fichier est chargé en premier dans shared_scripts

Bridge = Bridge or {}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FACTORY : crée un bridge standard pour un module externe
-- Usage :
--   Bridge.Character = Bridge.create("kt_character")
--   Bridge.Character.call("ApplyPreview", charData)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Bridge.create(resourceName)
    local self = {
        resource  = resourceName,
        available = false,
    }

    -- Vérifie l'état au démarrage
    self.available = GetResourceState(resourceName) == "started"

    -- Écoute les starts/stops pour mettre à jour l'état en temps réel
    AddEventHandler("onResourceStart", function(r)
        if r == resourceName then
            self.available = true
            if Bridge._onStart then Bridge._onStart(resourceName) end
        end
    end)

    AddEventHandler("onResourceStop", function(r)
        if r == resourceName then
            self.available = false
            if Bridge._onStop then Bridge._onStop(resourceName) end
        end
    end)

    -- Guard interne
    function self:guard(fnName)
        if not self.available then
            print(("^3[BRIDGE:%s] '%s' non disponible — ignoré^7"):format(self.resource, fnName))
            return false
        end
        return true
    end

    -- Appel sécurisé d'un export
    function self:call(fnName, ...)
        if not self:guard(fnName) then return nil end
        local args = { ... }
        local ok, result = pcall(function()
            return exports[self.resource][fnName](exports[self.resource], table.unpack(args))
        end)
        if not ok then
            print(("^1[BRIDGE:%s] Erreur dans '%s' : %s^7"):format(self.resource, fnName, tostring(result)))
            return nil
        end
        return result
    end

    -- Vérifie si le module est disponible
    function self:isAvailable()
        return self.available
    end

    return self
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REGISTRE des bridges actifs (pour debug)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Bridge._registry = {}

function Bridge.register(name, instance)
    Bridge._registry[name] = instance
    print(("^2[BRIDGE] '%s' enregistré (disponible: %s)^7"):format(name, tostring(instance.available)))
end

function Bridge.getStatus()
    local status = {}
    for name, b in pairs(Bridge._registry) do
        status[name] = b.available
    end
    return status
end

return Bridge
