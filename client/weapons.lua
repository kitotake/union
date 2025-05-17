-- 📁 client/weapon.lua

RegisterCommand("givegun", function(source, args)
    local weaponId = args[1]
    if not weaponId then
        print("Usage: /givegun [id]")
        return
    end

    local weapon = Weapons[weaponId:lower()]
    if not weapon then
        print("Arme inconnue.")
        return
    end

    GiveWeaponToPed(PlayerPedId(), GetHashKey(weapon.hash), weapon.ammo, false, true)
    print("Arme donnée: " .. weapon.label)
end, false)
