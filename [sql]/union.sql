-- Union Framework Database Schema
-- Version: 5.0.0

-- ============================================================
-- SCHÉMA NORMALISÉ — Union Framework + KT Banque
-- Relation N-N entre users et characters via user_character
-- ============================================================

-- ============================================
-- USERS
-- ============================================
CREATE TABLE IF NOT EXISTS `users` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `discord`    VARCHAR(50)  DEFAULT NULL,
    `slots`      TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `name`       VARCHAR(50)  DEFAULT NULL,
    `group`      VARCHAR(50)  DEFAULT 'user',
    `banned`     TINYINT(1)   DEFAULT 0,
    `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_identifier` (`identifier`),
    INDEX `idx_group` (`group`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- CHARACTERS
-- (plus de FK directe vers users, la relation
--  N-N passe par user_character)
-- ============================================
CREATE TABLE IF NOT EXISTS `characters` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `unique_id`   VARCHAR(36)  NOT NULL,

    `firstname`   VARCHAR(50)  NOT NULL,
    `lastname`    VARCHAR(50)  NOT NULL,
    `dateofbirth` DATE         NOT NULL,

    `ped_model`   VARCHAR(60)  NOT NULL,
    `position`    JSON         DEFAULT NULL,

    `health`      INT          DEFAULT 200,
    `armor`       INT          DEFAULT 0,
    `is_dead`     TINYINT(1)   DEFAULT 0,

    `job`         VARCHAR(50)  DEFAULT 'unemployed',
    `job_grade`   INT          DEFAULT 0,

    `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    `last_played` TIMESTAMP    NULL DEFAULT NULL,
    `updated_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_unique_id` (`unique_id`),
    INDEX `idx_job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- USER_CHARACTER — table de jonction N-N
-- Un user peut posséder plusieurs personnages,
-- un personnage peut appartenir à plusieurs users.
-- created_at = date de création du lien (création du personnage)
-- ============================================
CREATE TABLE IF NOT EXISTS `user_character` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`  VARCHAR(60)  NOT NULL,
    `unique_id`   VARCHAR(36)  NOT NULL,
    `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_user_char` (`identifier`, `unique_id`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_unique_id` (`unique_id`),

    CONSTRAINT `fk_uc_user`
        FOREIGN KEY (`identifier`)
        REFERENCES `users` (`identifier`)
        ON DELETE CASCADE,

    CONSTRAINT `fk_uc_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- KT_INVENTORY
-- ============================================
CREATE TABLE IF NOT EXISTS `kt_inventory` (
    `id`          INT          AUTO_INCREMENT PRIMARY KEY,
    `unique_id`   VARCHAR(36)  NOT NULL,
    `name`        VARCHAR(100) NOT NULL DEFAULT 'player',
    `data`        LONGTEXT     DEFAULT NULL,
    `max_weight`  INT          DEFAULT 10000,
    `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX `idx_unique_id` (`unique_id`),
    UNIQUE KEY `uniq_inventory` (`unique_id`, `name`),

    CONSTRAINT `fk_inventory_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- PLAYER STATUS
-- ============================================
CREATE TABLE IF NOT EXISTS `player_status` (
    `id`          INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    `unique_id`   VARCHAR(36)       NOT NULL,

    `hunger`      TINYINT UNSIGNED  NOT NULL DEFAULT 100,
    `thirst`      TINYINT UNSIGNED  NOT NULL DEFAULT 100,
    `stress`      TINYINT UNSIGNED  NOT NULL DEFAULT 0,

    `last_update` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_unique_id` (`unique_id`),

    CONSTRAINT `fk_status_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- CHARACTER APPEARANCES
-- ============================================
CREATE TABLE IF NOT EXISTS `character_appearances` (
    `id`            INT UNSIGNED AUTO_INCREMENT,
    `unique_id`     VARCHAR(36) NOT NULL,

    `skin_data`     LONGTEXT,
    `face_features` LONGTEXT,
    `tattoos`       LONGTEXT,

    `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_unique_id` (`unique_id`),

    CONSTRAINT `fk_appearance_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- CHARACTER OUTFITS
-- ============================================
CREATE TABLE IF NOT EXISTS `character_outfits` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `unique_id`     VARCHAR(36)  NOT NULL,
    `name`          VARCHAR(50)  NOT NULL,
    `components`    LONGTEXT,
    `props`         LONGTEXT,
    `is_job_outfit` TINYINT(1)   DEFAULT 0,
    `job_name`      VARCHAR(50)  DEFAULT NULL,
    `job_grade`     INT          DEFAULT NULL,
    `created_at`    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    INDEX `idx_unique_id` (`unique_id`),
    INDEX `idx_job` (`job_name`, `job_grade`),

    CONSTRAINT `fk_outfit_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- OWNED VEHICLES
-- ============================================
CREATE TABLE IF NOT EXISTS `owned_vehicles` (
    `id`            INT UNSIGNED AUTO_INCREMENT,
    `plate`         VARCHAR(12) NOT NULL,
    `unique_id`     VARCHAR(36) NOT NULL,

    `vehicle_model` VARCHAR(50) NOT NULL,
    `vehicle_props` LONGTEXT,

    `trunk`         LONGTEXT,
    `glovebox`      LONGTEXT,

    `stored`        TINYINT(1)  DEFAULT 1,
    `garage_name`   VARCHAR(50) DEFAULT 'central',

    `fuel`          FLOAT       DEFAULT 100,
    `engine_health` FLOAT       DEFAULT 1000,
    `body_health`   FLOAT       DEFAULT 1000,
    `dirt_level`    FLOAT       DEFAULT 0,

    `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

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
    `id`          INT         AUTO_INCREMENT,
    `name`        VARCHAR(50) NOT NULL,
    `label`       VARCHAR(50) NOT NULL,
    `whitelisted` TINYINT(1)  DEFAULT 0,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_job_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- JOB GRADES
-- ============================================
CREATE TABLE IF NOT EXISTS `job_grades` (
    `id`          INT         AUTO_INCREMENT,
    `job_name`    VARCHAR(50) NOT NULL,
    `grade`       INT         NOT NULL,
    `name`        VARCHAR(50) NOT NULL,
    `label`       VARCHAR(50) NOT NULL,
    `salary`      INT         DEFAULT 0,
    `permissions` LONGTEXT,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_job_grade` (`job_name`, `grade`),

    CONSTRAINT `fk_jobgrade_job`
        FOREIGN KEY (`job_name`)
        REFERENCES `jobs` (`name`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- LICENSES
-- ============================================
CREATE TABLE IF NOT EXISTS `licenses` (
    `type`  VARCHAR(50) NOT NULL,
    `label` VARCHAR(60) NOT NULL,

    PRIMARY KEY (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- USER LICENSES
-- (liée à un personnage ET un user)
-- ============================================
CREATE TABLE IF NOT EXISTS `user_licenses` (
    `id`         INT         AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `unique_id`  VARCHAR(36) NOT NULL,
    `type`       VARCHAR(50) NOT NULL,

    `granted_at` DATETIME  DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_license` (`unique_id`, `type`),
    INDEX `idx_identifier` (`identifier`),

    CONSTRAINT `fk_userlicense_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE,

    CONSTRAINT `fk_userlicense_type`
        FOREIGN KEY (`type`)
        REFERENCES `licenses` (`type`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- BANK ACCOUNTS (KT Banque v7.4 + Union)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_accounts` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_number`   VARCHAR(10)  NOT NULL,
    `unique_id`        VARCHAR(36)  NOT NULL,
    `owner_identifier` VARCHAR(60)  NOT NULL,
    `iban`             VARCHAR(34)  NOT NULL UNIQUE,
    `label`    VARCHAR(100) DEFAULT 'Compte Personnel',
    `type`     ENUM('personal','business','shared') DEFAULT 'personal',
    `balance`  BIGINT       NOT NULL DEFAULT 0,
    `status`   ENUM('active','suspended','closed') DEFAULT 'active',

    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_account_number` (`account_number`),
    INDEX `idx_unique_id` (`unique_id`),
    INDEX `idx_owner` (`owner_identifier`),

    CONSTRAINT `fk_bankaccount_char`
        FOREIGN KEY (`unique_id`)
        REFERENCES `characters` (`unique_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- BANK TRANSACTIONS (KT Banque v7.4)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_transactions` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`        INT UNSIGNED NOT NULL,
    `transaction_uuid`  VARCHAR(36)  NOT NULL,
    `type`              ENUM('deposit','withdraw','transfer_in','transfer_out','admin') NOT NULL,
    `amount`            BIGINT       NOT NULL,
    `balance_after`     BIGINT       NOT NULL,
    `description`       VARCHAR(255) DEFAULT NULL,
    `source_identifier` VARCHAR(60)  DEFAULT NULL,
    `target_account_id` INT UNSIGNED DEFAULT NULL,
    `created_at`        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_transaction_uuid` (`transaction_uuid`),
    INDEX `idx_account` (`account_id`),
    INDEX `idx_account_date` (`account_id`, `created_at` DESC),

    CONSTRAINT `fk_transaction_account`
        FOREIGN KEY (`account_id`)
        REFERENCES `bank_accounts` (`id`)
        ON DELETE CASCADE,

    CONSTRAINT `fk_transaction_target`
        FOREIGN KEY (`target_account_id`)
        REFERENCES `bank_accounts` (`id`)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- BANK CARDS (KT Banque v7.4)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_cards` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`  INT UNSIGNED NOT NULL,
    `unique_id`   VARCHAR(36)  NOT NULL,
    `card_number` VARCHAR(19)  NOT NULL,
    `pin`         CHAR(4)      NOT NULL,
    `type`        ENUM('basic','gold','diamond') DEFAULT 'basic',
    `active`      TINYINT(1)   DEFAULT 1,
    `expires_at`  DATE         NOT NULL,
    `created_at`  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_card_number` (`card_number`),
    INDEX `idx_account` (`account_id`),

    CONSTRAINT `fk_card_account`
        FOREIGN KEY (`account_id`)
        REFERENCES `bank_accounts` (`id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- BANK LIMITS (KT Banque v7.4)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_limits` (
    `account_id`    INT UNSIGNED NOT NULL,
    `deposit_today`  BIGINT DEFAULT 0,
    `withdraw_today` BIGINT DEFAULT 0,
    `last_reset`    DATE NOT NULL,

    PRIMARY KEY (`account_id`),

    CONSTRAINT `fk_limit_account`
        FOREIGN KEY (`account_id`)
        REFERENCES `bank_accounts` (`id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- BANK LOGS (KT Banque v7.4)
-- ============================================
CREATE TABLE IF NOT EXISTS `bank_logs` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `unique_id`  VARCHAR(36)  NOT NULL,
    `action`     VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    INDEX `idx_unique_id` (`unique_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- KT_INTERACT_DATA
-- ============================================
CREATE TABLE IF NOT EXISTS `kt_interact_data` (
    `id`          VARCHAR(36)   NOT NULL,
    `type`        VARCHAR(32)   NOT NULL,
    `zone_type`   VARCHAR(16)   DEFAULT NULL,
    `label`       VARCHAR(128)  NOT NULL,
    `icon`        VARCHAR(64)   DEFAULT 'fas fa-hand-pointer',
    `icon_color`  VARCHAR(32)   DEFAULT NULL,
    `event_type`  VARCHAR(32)   NOT NULL,
    `event_name`  VARCHAR(255)  NOT NULL,
    `distance`    FLOAT         NOT NULL DEFAULT 3.0,
    `coords`      LONGTEXT      DEFAULT NULL,
    `size`        LONGTEXT      DEFAULT NULL,
    `rotation`    FLOAT         DEFAULT 0.0,
    `radius`      FLOAT         DEFAULT 1.0,
    `model_hash`  VARCHAR(32)   DEFAULT NULL,
    `net_id`      INT           DEFAULT NULL,
    `conditions`  LONGTEXT      DEFAULT NULL,
    `prop_model`  VARCHAR(64)   DEFAULT NULL,
    `prop_offset` LONGTEXT      DEFAULT NULL,
    `created_by`  VARCHAR(64)   DEFAULT NULL,
    `active`      TINYINT(1)    NOT NULL DEFAULT 1,
    `created_at`  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    INDEX `idx_active` (`active`),
    INDEX `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- ACTION LOGS
-- ============================================
CREATE TABLE IF NOT EXISTS `action_logs` (
    `id`           INT          AUTO_INCREMENT,
    `user_id`      INT          UNSIGNED DEFAULT NULL,
    `character_id` INT          UNSIGNED DEFAULT NULL,
    `action`       VARCHAR(100) NOT NULL,
    `details`      TEXT,
    `created_at`   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    INDEX `idx_user` (`user_id`),
    INDEX `idx_character` (`character_id`),
    INDEX `idx_action` (`action`),

    CONSTRAINT `fk_actionlog_user`
        FOREIGN KEY (`user_id`)
        REFERENCES `users` (`id`)
        ON DELETE SET NULL,

    CONSTRAINT `fk_actionlog_char`
        FOREIGN KEY (`character_id`)
        REFERENCES `characters` (`id`)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- WHITELIST
-- ============================================
CREATE TABLE IF NOT EXISTS `whitelist` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`    VARCHAR(60)  NOT NULL,
    `added_by`   VARCHAR(50)  DEFAULT 'console',
    `active`     TINYINT(1)   DEFAULT 1,
    `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- DONNÉES PAR DÉFAUT
-- ============================================================

INSERT IGNORE INTO `jobs` (`name`, `label`, `whitelisted`) VALUES
('unemployed', 'Chômeur',    0),
('police',     'Police',     1),
('ambulance',  'Ambulance',  1),
('mechanic',   'Mécanicien', 0),
('security',   'Sécurité',   0),
('taxi',       'Taxi',       0);

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`) VALUES
('unemployed', 0, 'unemployed',  'Chômeur',      50),
('police',     0, 'recruit',     'Recrue',       200),
('police',     1, 'officer',     'Officier',     250),
('police',     2, 'sergeant',    'Sergent',      300),
('police',     3, 'lieutenant',  'Lieutenant',   350),
('police',     4, 'captain',     'Capitaine',    400),
('police',     5, 'chief',       'Chef',         450),
('ambulance',  0, 'nurse',       'Infirmier',    200),
('ambulance',  1, 'doctor',      'Médecin',      300),
('ambulance',  2, 'surgeon',     'Chirurgien',   400),
('ambulance',  3, 'chief',       'Chef',         450),
('mechanic',   0, 'apprentice',  'Apprenti',     100),
('mechanic',   1, 'novice',      'Novice',       150),
('mechanic',   2, 'experienced', 'Expérimenté',  200),
('mechanic',   3, 'expert',      'Expert',       250),
('mechanic',   4, 'boss',        'Patron',       300),
('security',   0, 'guard',       'Garde',        150),
('security',   1, 'supervisor',  'Superviseur',  200),
('security',   2, 'manager',     'Gérant',       250),
('taxi',       0, 'driver',      'Chauffeur',    100),
('taxi',       1, 'owner',       'Propriétaire', 200);

INSERT IGNORE INTO `licenses` (`type`, `label`) VALUES
('dmv',        'Driving Permit'),
('drive',      'Drivers License'),
('drive_bike', 'Motorcycle License'),
('drive_truck','Truck License'),
('drive_taxi', 'Taxi License'),
('weapon',     'Weapon License'),
('hunt',       'Hunting License'),
('fish',       'Fishing License');

INSERT IGNORE INTO `characters` (`id`,  `unique_id`, `firstname`, `lastname`, `dateofbirth`, `ped_model`, `position`, `health`, `armor`, `is_dead`, `job`, `job_grade`, `created_at`, `last_played`, `updated_at`) VALUES (1, 'chr_939492317496', 'dev', 'kito', '2004-12-25', 'm', NULL, '{"z":106.2835693359375,"y":214.52308654785157,"x":235.6615447998047,"heading":96.37794494628906}', 150, 0, 0, 'unemployed', 0, '2026-04-23 01:12:20', '2026-05-06 14:33:39', '2026-05-06 14:33:39');
INSERT IGNORE INTO `user_character` (`id`, `identifier`, `unique_id`, `created_at`) VALUES (1, 'license:5dd163d48114f6f827098ac7b57fdad1c087f5bb', 'chr_939492317496', '2026-04-23 01:12:20');
INSERT IGNORE INTO `character_appearances` (`id`, `unique_id`, `skin_data`, `face_features`, `tattoos`, `created_at`, `updated_at`) VALUES (1, 'chr_939492317496', '{"headOverlays":{"1":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"0":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"11":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"10":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"5":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"4":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"7":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"6":{"firstColor":0,"secondColor":0,"index":...0,"opacity":1},"9":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"8":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"3":{"firstColor":0,"secondColor":0,"index":0,"opacity":1},"2":{"firstColor":0,"secondColor":0,"index":0,"opacity":1}}}', '{"nose_5":-0.5,"cheeks_2":-0.5,"jaw_3":-0.5}', '[]', '2026-04-23 01:12:20', '2026-05-06 14:33:39');