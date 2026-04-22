-- Union Framework Database Schema
-- Version: 3.0.0

-- ============================================
-- USERS
-- ============================================
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `discord` VARCHAR(50) DEFAULT NULL,
    `name` VARCHAR(50) DEFAULT NULL,
    `permission_level` INT NOT NULL DEFAULT 0,
    `group` VARCHAR(50) DEFAULT 'user',
    `banned` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_login` TIMESTAMP NULL DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_identifier` (`identifier`),
    INDEX `idx_group` (`group`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- kt_inventory
-- ============================================

CREATE TABLE IF NOT EXISTS `kt_inventory` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `unique_id` VARCHAR(32) NOT NULL, -- personnage unique (IMPORTANT)
    `name` VARCHAR(100) NOT NULL DEFAULT 'player', -- player / trunk / stash / glovebox
    `data` LONGTEXT DEFAULT NULL,
    `max_weight` INT DEFAULT 10000,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_unique_id` (`unique_id`),
    UNIQUE KEY `uniq_inventory` (`unique_id`, `name`)
);


-- ============================================
-- CHARACTERS
-- ============================================
CREATE TABLE IF NOT EXISTS `characters` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `unique_id` VARCHAR(32) NOT NULL,
    `firstname` VARCHAR(50) NOT NULL,
    `lastname` VARCHAR(50) NOT NULL,
    `dateofbirth` DATE NOT NULL,
    `gender` ENUM('m','f') NOT NULL,

    `model` VARCHAR(50),
    `position_x` DOUBLE,
    `position_y` DOUBLE,
    `position_z` DOUBLE,
    `heading` DOUBLE,

    `health` INT DEFAULT 200,
    `armor` INT DEFAULT 0,
    `is_dead` TINYINT(1) DEFAULT 0,

    `job` VARCHAR(50) DEFAULT 'unemployed',
    `job_grade` INT DEFAULT 0,

    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_played` TIMESTAMP NULL DEFAULT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_unique_id` (`unique_id`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_job` (`job`),

    CONSTRAINT `fk_char_user`
        FOREIGN KEY (`identifier`)
        REFERENCES `users` (`identifier`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================
-- CHARACTER APPEARANCES
-- ============================================
CREATE TABLE IF NOT EXISTS `character_appearances` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `unique_id` VARCHAR(32) NOT NULL,

    `skin_data` LONGTEXT,
    `face_features` LONGTEXT,
    `tattoos` LONGTEXT,

    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_unique_id` (`unique_id`),

    CONSTRAINT `fk_appearance_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `character_outfits` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `unique_id`    VARCHAR(32)  NOT NULL,
    `name`         VARCHAR(50)  NOT NULL,
    `components`   LONGTEXT,
    `props`        LONGTEXT,
    `is_job_outfit` TINYINT(1)  DEFAULT 0,
    `job_name`     VARCHAR(50)  DEFAULT NULL,
    `job_grade`    INT          DEFAULT NULL,
    `created_at`   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_unique_id` (`unique_id`),
    INDEX `idx_job` (`job_name`, `job_grade`),
    CONSTRAINT `fk_outfit_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `owned_vehicles` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `plate` VARCHAR(12) NOT NULL,
    `unique_id` VARCHAR(32) NOT NULL,

    `vehicle_model` VARCHAR(50) NOT NULL,
    `vehicle_props` LONGTEXT,

    `trunk` LONGTEXT,
    `glovebox` LONGTEXT,

    `stored` TINYINT(1) DEFAULT 1,
    `garage_name` VARCHAR(50) DEFAULT 'central',

    `fuel` FLOAT DEFAULT 100,
    `engine_health` FLOAT DEFAULT 1000,
    `body_health` FLOAT DEFAULT 1000,
    `dirt_level` FLOAT DEFAULT 0,

    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_plate` (`plate`),
    INDEX `idx_unique_id` (`unique_id`),

    CONSTRAINT `fk_vehicle_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================
-- JOBS
-- ============================================
CREATE TABLE IF NOT EXISTS `jobs` (
    `id` INT AUTO_INCREMENT,
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(50) NOT NULL,
    `whitelisted` TINYINT(1) DEFAULT 0,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_job_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================
-- JOB GRADES
-- ============================================
CREATE TABLE IF NOT EXISTS `job_grades` (
    `id` INT AUTO_INCREMENT,
    `job_name` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL,

    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(50) NOT NULL,
    `salary` INT DEFAULT 0,
    `permissions` LONGTEXT,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_job_grade` (`job_name`, `grade`),

    CONSTRAINT `fk_jobgrade_job`
        FOREIGN KEY (`job_name`)
        REFERENCES `jobs` (`name`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================
-- BANK ACCOUNTS
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_accounts` (
    `id` INT AUTO_INCREMENT,
    `account_number` VARCHAR(10) NOT NULL,
    `owner_type` VARCHAR(50) NOT NULL,
    `owner_id` VARCHAR(50) NOT NULL,

    `unique_id` VARCHAR(32) NOT NULL,
    `type` VARCHAR(50) DEFAULT 'personal',
    `balance` BIGINT DEFAULT 0,

    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_account` (`account_number`),
    INDEX `idx_owner` (`owner_type`, `owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================
-- BANK TRANSACTIONS
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_transactions` (
    `id` INT AUTO_INCREMENT,
    `account_id` INT NOT NULL,

    `unique_id` VARCHAR(32) NOT NULL,
    `amount` BIGINT NOT NULL,
    `description` VARCHAR(255),

    `type` ENUM('deposit','withdraw','transfer') NOT NULL,
    `source` VARCHAR(50),

    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    INDEX `idx_account` (`account_id`),
    INDEX `idx_date` (`created_at`),

    CONSTRAINT `fk_transaction_account`
        FOREIGN KEY (`account_id`)
        REFERENCES `bank_accounts` (`id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================
-- LICENSES
-- ============================================
CREATE TABLE IF NOT EXISTS `licenses` (
    `type` VARCHAR(50) NOT NULL,
    `label` VARCHAR(60) NOT NULL,

    PRIMARY KEY (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================
-- USER LICENSES
-- ============================================
CREATE TABLE IF NOT EXISTS `user_licenses` (
    `id` INT AUTO_INCREMENT,
    `identifier` VARCHAR(100) NOT NULL,
    `unique_id` VARCHAR(32) NOT NULL,
    `type` VARCHAR(50) NOT NULL,

    `granted_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_license` (`unique_id`, `type`),
    INDEX `idx_identifier` (`identifier`),

    CONSTRAINT `fk_userlicense_type`
        FOREIGN KEY (`type`)
        REFERENCES `licenses` (`type`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================
-- ACTION LOGS
-- ============================================
CREATE TABLE IF NOT EXISTS `action_logs` (
    `id` INT AUTO_INCREMENT,
    `user_id` INT,
    `character_id` INT,

    `action` VARCHAR(100) NOT NULL,
    `details` TEXT,

    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    INDEX `idx_user` (`user_id`),
    INDEX `idx_character` (`character_id`),
    INDEX `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- DEFAULT DATA
-- ============================================

-- ============================================
-- WHITELIST
-- ============================================
CREATE TABLE IF NOT EXISTS `whitelist` (
    `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`   VARCHAR(60)  NOT NULL,
    `added_by`  VARCHAR(50)  DEFAULT 'console',
    `active`    TINYINT(1)   DEFAULT 1,
    `created_at` TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert default jobs
INSERT IGNORE INTO `jobs` (`name`, `label`, `whitelisted`) VALUES
('unemployed', 'Chômeur', 0),
('police', 'Police', 1),
('ambulance', 'Ambulance', 1),
('mechanic', 'Mécanicien', 0),
('security', 'Sécurité', 0),
('taxi', 'Taxi', 0);

-- Insert default job grades
INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`) VALUES
-- Unemployed
('unemployed', 0, 'unemployed', 'Chômeur', 50),

-- Police
('police', 0, 'recruit', 'Recrue', 200),
('police', 1, 'officer', 'Officier', 250),
('police', 2, 'sergeant', 'Sergent', 300),
('police', 3, 'lieutenant', 'Lieutenant', 350),
('police', 4, 'captain', 'Capitaine', 400),
('police', 5, 'chief', 'Chef', 450),

-- Ambulance
('ambulance', 0, 'nurse', 'Infirmier', 200),
('ambulance', 1, 'doctor', 'Médecin', 300),
('ambulance', 2, 'surgeon', 'Chirurgien', 400),
('ambulance', 3, 'chief', 'Chef', 450),

-- Mechanic
('mechanic', 0, 'apprentice', 'Apprenti', 100),
('mechanic', 1, 'novice', 'Novice', 150),
('mechanic', 2, 'experienced', 'Expérimenté', 200),
('mechanic', 3, 'expert', 'Expert', 250),
('mechanic', 4, 'boss', 'Patron', 300),

-- Security
('security', 0, 'guard', 'Garde', 150),
('security', 1, 'supervisor', 'Superviseur', 200),
('security', 2, 'manager', 'Gérant', 250),

-- Taxi
('taxi', 0, 'driver', 'Chauffeur', 100),
('taxi', 1, 'owner', 'Propriétaire', 200);

-- Insert default licenses
INSERT IGNORE INTO `licenses` (`type`, `label`) VALUES
('dmv', 'Driving Permit'),
('drive', 'Drivers License'),
('drive_bike', 'Motorcycle License'),
('drive_truck', 'Truck License'),
('drive_taxi', 'Taxi License'),
('weapon', 'Weapon License'),
('hunt', 'Hunting License'),
('fish', 'Fishing License');