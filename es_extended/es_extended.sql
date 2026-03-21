CREATE DATABASE IF NOT EXISTS `es_extended`;

ALTER DATABASE `es_extended`
	DEFAULT CHARACTER SET utf8mb4;

ALTER DATABASE `es_extended`
	DEFAULT COLLATE utf8mb4_unicode_ci;

USE `es_extended`;

-- ============================================================================
-- users
-- ตารางหลักที่ es_extended ใช้งานสำหรับบัญชีผู้เล่น โหลดตัวละคร inventory/loadout
-- metadata, skin, identity และ optimistic-lock versioning
-- ============================================================================
CREATE TABLE IF NOT EXISTS `users` (
	`identifier` VARCHAR(60) NOT NULL,
	`accounts` LONGTEXT NULL DEFAULT NULL,
	`group` VARCHAR(50) NULL DEFAULT 'user',
	`inventory` LONGTEXT NULL DEFAULT NULL,
	`job` VARCHAR(20) NULL DEFAULT 'unemployed',
	`job_grade` INT NULL DEFAULT 0,
	`loadout` LONGTEXT NULL DEFAULT NULL,
	`metadata` LONGTEXT NULL DEFAULT NULL,
	`position` LONGTEXT NULL DEFAULT NULL,
	`skin` LONGTEXT NULL DEFAULT NULL,
	`firstname` VARCHAR(16) NULL DEFAULT NULL,
	`lastname` VARCHAR(16) NULL DEFAULT NULL,
	`dateofbirth` VARCHAR(10) NULL DEFAULT NULL,
	`sex` VARCHAR(1) NULL DEFAULT NULL,
	`height` INT NULL DEFAULT NULL,
	`version` INT NOT NULL DEFAULT 0,

	PRIMARY KEY (`identifier`),
	KEY `idx_users_job` (`job`, `job_grade`),
	KEY `idx_users_group` (`group`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `users`
	ADD COLUMN IF NOT EXISTS `accounts` LONGTEXT NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `group` VARCHAR(50) NULL DEFAULT 'user',
	ADD COLUMN IF NOT EXISTS `inventory` LONGTEXT NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `job` VARCHAR(20) NULL DEFAULT 'unemployed',
	ADD COLUMN IF NOT EXISTS `job_grade` INT NULL DEFAULT 0,
	ADD COLUMN IF NOT EXISTS `loadout` LONGTEXT NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `metadata` LONGTEXT NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `position` LONGTEXT NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `skin` LONGTEXT NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `firstname` VARCHAR(16) NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `lastname` VARCHAR(16) NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `dateofbirth` VARCHAR(10) NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `sex` VARCHAR(1) NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `height` INT NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `version` INT NOT NULL DEFAULT 0;

-- ============================================================================
-- items
-- โหลดผ่าน ESX.RefreshItems / Core.ReloadItems
-- ============================================================================
CREATE TABLE IF NOT EXISTS `items` (
	`name` VARCHAR(50) NOT NULL,
	`label` VARCHAR(50) NOT NULL,
	`weight` INT NOT NULL DEFAULT 1,
	`rare` TINYINT NOT NULL DEFAULT 0,
	`can_remove` TINYINT NOT NULL DEFAULT 1,

	PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- jobs / job_grades
-- ใช้กับ ESX.RefreshJobs และคำสั่ง createJob
-- ============================================================================
CREATE TABLE IF NOT EXISTS `jobs` (
	`name` VARCHAR(50) NOT NULL,
	`label` VARCHAR(50) DEFAULT NULL,

	PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `job_grades` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`job_name` VARCHAR(50) DEFAULT NULL,
	`grade` INT NOT NULL,
	`name` VARCHAR(50) NOT NULL,
	`label` VARCHAR(50) NOT NULL,
	`salary` INT NOT NULL,
	`skin_male` LONGTEXT NOT NULL,
	`skin_female` LONGTEXT NOT NULL,

	PRIMARY KEY (`id`),
	UNIQUE KEY `uk_job_grades_job_grade` (`job_name`, `grade`),
	KEY `idx_job_grades_job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `jobs` (`name`, `label`) VALUES
	('unemployed', 'Unemployed');

INSERT IGNORE INTO `job_grades` (`id`, `job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
	(1, 'unemployed', 0, 'unemployed', 'Unemployed', 200, '{}', '{}');

-- ============================================================================
-- owned_vehicles
-- ใช้กับ server/classes/vehicle.lua สำหรับ spawn / store / impound / transfer
-- ============================================================================
CREATE TABLE IF NOT EXISTS `owned_vehicles` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`owner` VARCHAR(60) NOT NULL,
	`plate` VARCHAR(20) NOT NULL,
	`vehicle` LONGTEXT NOT NULL,
	`type` VARCHAR(20) NULL DEFAULT 'car',
	`job` VARCHAR(20) NULL DEFAULT NULL,
	`stored` TINYINT(1) NOT NULL DEFAULT 1,
	`parking` VARCHAR(60) NULL DEFAULT NULL,
	`pound` VARCHAR(60) NULL DEFAULT NULL,

	PRIMARY KEY (`id`),
	UNIQUE KEY `uk_owned_vehicles_owner_plate` (`owner`, `plate`),
	KEY `idx_owned_vehicles_owner_stored` (`owner`, `stored`),
	KEY `idx_owned_vehicles_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `owned_vehicles`
	ADD COLUMN IF NOT EXISTS `owner` VARCHAR(60) NOT NULL,
	ADD COLUMN IF NOT EXISTS `plate` VARCHAR(20) NOT NULL,
	ADD COLUMN IF NOT EXISTS `vehicle` LONGTEXT NOT NULL,
	ADD COLUMN IF NOT EXISTS `type` VARCHAR(20) NULL DEFAULT 'car',
	ADD COLUMN IF NOT EXISTS `job` VARCHAR(20) NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `stored` TINYINT(1) NOT NULL DEFAULT 1,
	ADD COLUMN IF NOT EXISTS `parking` VARCHAR(60) NULL DEFAULT NULL,
	ADD COLUMN IF NOT EXISTS `pound` VARCHAR(60) NULL DEFAULT NULL;
