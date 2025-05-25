print("^6[SPAWN]^0 Lancement du processus de spawn...")
print("DEBUG: Spawn =", Spawn)

if Spawn and Spawn.initialize then
    Spawn.initialize()
else
    print("^1[SPAWN]^0 ERREUR : Spawn.initialize() non trouvé.")
end
