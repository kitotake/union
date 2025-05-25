Weapons = {
    melee = {
        knife = { hash = "WEAPON_KNIFE", label = "Couteau", ammo = 1 },
        bat = { hash = "WEAPON_BAT", label = "Batte de baseball", ammo = 1 },
        crowbar = { hash = "WEAPON_CROWBAR", label = "Pied de biche", ammo = 1 }
    },

    pistols = {
        pistol = { hash = "WEAPON_PISTOL", label = "Pistolet", ammo = 100 },
        revolver = { hash = "WEAPON_REVOLVER", label = "Revolver", ammo = 60 }
    },

    rifles = {
        carbine = { hash = "WEAPON_CARBINERIFLE", label = "Carabine", ammo = 200 },
        sniper = { hash = "WEAPON_SNIPERRIFLE", label = "Sniper", ammo = 10 }
    },

    shotguns = {
        pump = { hash = "WEAPON_PUMPSHOTGUN", label = "Fusil à pompe", ammo = 40 },
        sawnoff = { hash = "WEAPON_SAWNOFFSHOTGUN", label = "Canon scié", ammo = 30 }
    }
}

function GetFlatWeaponsList()
    local flat = {}
    for category, weapons in pairs(Weapons) do
        for id, weapon in pairs(weapons) do
            flat[id] = weapon
        end
    end
    return flat
end
