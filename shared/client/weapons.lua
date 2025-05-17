-- 📁 shared/weapons.lua

Weapons = {
    melee = {
        knife = {
            hash = "WEAPON_KNIFE",
            label = "Couteau",
            ammo = 1
        },
        bat = {
            hash = "WEAPON_BAT",
            label = "Batte de baseball",
            ammo = 1
        },
        crowbar = {
            hash = "WEAPON_CROWBAR",
            label = "Pied de biche",
            ammo = 1
        }
    },
    pistols = {
        pistol = {
        hash = "WEAPON_PISTOL",
        label = "Pistolet",
        ammo = 100
    },
    combatpistol = {
        hash = "WEAPON_COMBATPISTOL",
        label = "Pistolet de combat",
        ammo = 150
    },
    appistol = {
        hash = "WEAPON_APPISTOL",
        label = "Pistolet automatique",
        ammo = 150
    },
    heavypistol = {
        hash = "WEAPON_HEAVYPISTOL",
        label = "Pistolet lourd",
        ammo = 120
    },
    pistol50 = {
        hash = "WEAPON_PISTOL50",
        label = "Pistolet .50",
        ammo = 80
    },
    revolver = {
        hash = "WEAPON_REVOLVER",
        label = "Revolver",
        ammo = 60
    },
    microSMG = {
        hash = "WEAPON_MICROSMG",
        label = "Micro SMG",
        ammo = 200
    },
    SMG = {
        hash = "WEAPON_SMG",
        label = "SMG",
        ammo = 200
    },
    stungun = {
        hash = "WEAPON_stungun",
        label = "stungun",
        ammo = 200
    },
    assaultSMG = {
        hash = "WEAPON_ASSAULTSMG",
        label = "SMG d'assaut",
        ammo = 200
    },
    carbine = {
        hash = "WEAPON_CARBINERIFLE",
        label = "Fusil carabine",
        ammo = 250
    },
    advancedRifle = {
        hash = "WEAPON_ADVANCEDRIFLE",
        label = "Fusil avancé",
        ammo = 250
    },
    pumpShotgun = {
        hash = "WEAPON_PUMPSHOTGUN",
        label = "Fusil à pompe",
        ammo = 40
    },
    sawnoffShotgun = {
        hash = "WEAPON_SAWNOFFSHOTGUN",
        label = "Fusil à canon scié",
        ammo = 30
    },
    heavyShotgun = {
        hash = "WEAPON_HEAVYSHOTGUN",
        label = "Fusil à pompe lourd",
        ammo = 40
    },
    sniper = {
        hash = "WEAPON_SNIPERRIFLE",
        label = "Fusil de sniper",
        ammo = 20
    },
    marksman = {
        hash = "WEAPON_MARKSMANRIFLE",
        label = "Fusil marksman",
        ammo = 25
    },
    molotov = {
        hash = "WEAPON_MOLOTOV",
        label = "Molotov",
        ammo = 5
    },
    grenade = {
        hash = "WEAPON_GRENADE",
        label = "Grenade",
        ammo = 5
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