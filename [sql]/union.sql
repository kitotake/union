    ## Structure SQL pour Union Framework

    ```sql

    -- Table des utilisateurs
    CREATE TABLE IF NOT EXISTS `users` (
   
   `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,                      -- Identifiant FiveM ✅
   `identifier` VARCHAR(60) NOT NULL,                       -- Identifiant unique (ex: license) ✅
    `discord` VARCHAR(50) DEFAULT NULL,                      -- ID Discord (ex: 381023442130042880) ✅
    `name` VARCHAR(50) DEFAULT NULL,                         -- Nom du joueur affiché ✅
    `permission_level` INT(11) NOT NULL DEFAULT 0,           -- Niveau de permission pour admin/modération ✅
    `group` VARCHAR(50) DEFAULT 'user',                      -- Groupe utilisateur (admin, user...) ✅
    `banned` TINYINT(1) DEFAULT 0,                           -- Statut de bannissement (0 ou 1) ✅
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,   -- Date de création automatique ✅
    `last_login` TIMESTAMP NULL DEFAULT NULL,                -- Dernière connexion ✅
    PRIMARY KEY (`id`),                              -- Clé primaire sur `identifier` ✅
        UNIQUE KEY `identifier` (`identifier`)                         -- `identifier` doit être unique ✅
    );

    -- Table des personnages
    CREATE TABLE IF NOT EXISTS `characters` (
        `identifier` VARCHAR(60) NOT NULL,         -- Identifiant utilisateur (license) ✅
        `unique_id` VARCHAR(36) NOT NULL UNIQUE,   -- UUID ou identifiant unique perso ✅
        `firstname` VARCHAR(50) NOT NULL,
        `lastname` VARCHAR(50) NOT NULL,
        `dateofbirth` DATE NOT NULL,
        `gender` ENUM('M','F') NOT NULL,
        `model` VARCHAR(50) DEFAULT NULL,
        `position_x` DOUBLE DEFAULT NULL,
        `position_y` DOUBLE DEFAULT NULL,
        `position_z` DOUBLE DEFAULT NULL,
        `heading` DOUBLE DEFAULT NULL,
        `health` INT DEFAULT 200,
        `armor` INT DEFAULT 0,
        `is_dead` TINYINT(1) DEFAULT 0,
        `job` VARCHAR(50) DEFAULT NULL,
        `job_grade` INT DEFAULT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `last_played` TIMESTAMP NULL DEFAULT NULL,
        PRIMARY KEY (`unique_id`),
        KEY `identifier` (`identifier`),
        CONSTRAINT `fk_characters_users` FOREIGN KEY (`identifier`) REFERENCES `users` (`identifier`) ON DELETE CASCADE
    );

    -- Apparence des personnages
    CREATE TABLE IF NOT EXISTS `character_appearances` (
        `unique_id` VARCHAR(36) NOT NULL UNIQUE,                -- Identifiant unique du personnage
        `skin_data` LONGTEXT DEFAULT NULL,
        `face_features` LONGTEXT DEFAULT NULL,
        `tattoos` LONGTEXT DEFAULT NULL,
        `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`unique_id`),
        CONSTRAINT `fk_appearances_characters` FOREIGN KEY (`unique_id`) REFERENCES `characters` (`unique_id`) ON DELETE CASCADE
    );

    -- Véhicules possédés
    CREATE TABLE IF NOT EXISTS `owned_vehicles` (
        `plate` VARCHAR(12) NOT NULL,                           -- Plaque unique du véhicule ✅
        `unique_id` VARCHAR(36) NOT NULL,                       -- Identifiant du personnage propriétaire ✅
        `vehicle_model` VARCHAR(50) NOT NULL,
        `vehicle_props` LONGTEXT DEFAULT NULL,
        `stored` TINYINT(1) DEFAULT 1,
        `garage_name` VARCHAR(50) DEFAULT 'central',
        `fuel` FLOAT DEFAULT 100.0,
        `engine_health` FLOAT DEFAULT 1000.0,
        `body_health` FLOAT DEFAULT 1000.0,
        `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`plate`),                                  -- Clé primaire sur plaque (unique par véhicule) ✅
        KEY `unique_id` (`unique_id`),
        CONSTRAINT `fk_vehicles_characters` FOREIGN KEY (`unique_id`) REFERENCES `characters` (`unique_id`) ON DELETE CASCADE
    );


    -- Emplois
    CREATE TABLE IF NOT EXISTS `jobs` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `name` VARCHAR(50) NOT NULL,
        `label` VARCHAR(50) NOT NULL,
        `whitelisted` TINYINT(1) DEFAULT 0,
        PRIMARY KEY (`id`),
        UNIQUE KEY `name` (`name`)
    );

    -- Grades d'emploi
    CREATE TABLE IF NOT EXISTS `job_grades` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `job_name` VARCHAR(50) NOT NULL,
        `grade` INT(11) NOT NULL,
        `name` VARCHAR(50) NOT NULL,
        `label` VARCHAR(50) NOT NULL,
        `salary` INT(11) DEFAULT 0,
        `permissions` LONGTEXT DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `job_grade` (`job_name`,`grade`),
        CONSTRAINT `fk_job_grades_jobs` FOREIGN KEY (`job_name`) REFERENCES `jobs` (`name`) ON DELETE CASCADE
    );

    -- Comptes bancaires
    CREATE TABLE IF NOT EXISTS `bank_accounts` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `account_number` VARCHAR(10) NOT NULL,
        `owner_type` VARCHAR(50) NOT NULL,
        `owner_id` VARCHAR(50) NOT NULL,
        `unique_id` VARCHAR(50) NOT NULL UNIQUE,
        `type` VARCHAR(50) NOT NULL DEFAULT 'personal',
        `balance` INT(11) DEFAULT 0,
        `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `account_number` (`account_number`),
        KEY `owner` (`owner_type`,`owner_id`)
    );

    -- Transactions bancaires (amélioré)
    CREATE TABLE IF NOT EXISTS `bank_transactions` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `account_id` INT(11) NOT NULL,
        `unique_id` VARCHAR(20) NOT NULL UNIQUE,
        `amount` INT(11) NOT NULL,
        `description` VARCHAR(255) DEFAULT NULL,
        `type` ENUM('deposit','withdraw','transfer') NOT NULL,
        `source` VARCHAR(50) DEFAULT NULL,
        `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `account_id` (`account_id`),
        CONSTRAINT `fk_transactions_accounts` FOREIGN KEY (`account_id`) REFERENCES `bank_accounts` (`id`) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS `licenses` (
        `type` VARCHAR(50) NOT NULL,                    -- ex: weapon, car, moto, boat, etc.
        `label` VARCHAR(60) NOT NULL,                   -- ex: Weapon License, Motorcycle License, etc.
        `granted_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`type`)                            -- Utilisé comme référence (clé primaire simple)
    );

    INSERT INTO `licenses` (`type`, `label`) VALUES
    ('dmv', 'Driving Permit'),
    ('drive', 'Drivers License'),
    ('drive_bike', 'Motorcycle License'),
    ('drive_truck', 'Truck License'),
    ('weapon', 'Weapon License');


    CREATE TABLE IF NOT EXISTS `user_licenses` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `identifier` VARCHAR(100) NOT NULL,             -- Identifiant global joueur (ex: license:xxx)
        `unique_id` VARCHAR(100) NOT NULL,              -- ID unique du personnage
        `type` VARCHAR(50) NOT NULL,                    -- Type de licence (doit exister dans `licenses.type`)
        `granted_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT `fk_license_type` FOREIGN KEY (`type`) REFERENCES `licenses` (`type`) ON DELETE CASCADE,
        CONSTRAINT `unique_license` UNIQUE (`unique_id`, `type`)
    );



    -- Logs (nouvelle table)
    CREATE TABLE IF NOT EXISTS `action_logs` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `user_id` INT(11) DEFAULT NULL,
        `unique_id` INT(11) DEFAULT NULL,
        `action` VARCHAR(100) NOT NULL,
        `details` TEXT DEFAULT NULL,
        `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    );

    -- Insertion de données par défaut
    INSERT INTO `jobs` (`name`, `label`, `whitelisted`) VALUES
    ('unemployed', 'Chomeur', 0),
    ('police', 'Police', 1),
    ('ambulance', 'Ambulance', 1),
    ('mechanic', 'Mécanicien', 0);

    INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`) VALUES
    ('unemployed', 0, 'unemployed', 'Chomeur', 50),
    ('police', 0, 'recruit', 'Recrue', 150),
    ('police', 1, 'officer', 'Officier', 200),
    ('police', 2, 'sergeant', 'Sergent', 250),
    ('police', 3, 'lieutenant', 'Lieutenant', 300),
    ('police', 4, 'boss', 'Commandant', 350),
    ('ambulance', 0, 'ambulance', 'Ambulancier', 150),
    ('ambulance', 1, 'doctor', 'Médecin', 225),
    ('ambulance', 2, 'surgeon', 'Chirurgien', 300),
    ('ambulance', 3, 'boss', 'Directeur', 350),
    ('mechanic', 0, 'recrue', 'Recrue', 125),
    ('mechanic', 1, 'novice', 'Novice', 150),
    ('mechanic', 2, 'experimente', 'Expérimenté', 200),
    ('mechanic', 3, 'chief', 'Chef d\'équipe', 250),
    ('mechanic', 4, 'boss', 'Patron', 300);




    ```
