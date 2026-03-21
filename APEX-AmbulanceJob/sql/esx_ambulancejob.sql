-- esx_ambulancejob required SQL
-- Import this file once into your ESX database.

START TRANSACTION;

-- Job definition
INSERT IGNORE INTO `jobs` (`name`, `label`) VALUES
  ('ambulance', 'EMS');

-- Job grades
INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
  ('ambulance', 0, 'trainee',    'Trainee',    300, '{}', '{}'),
  ('ambulance', 1, 'paramedic',  'Paramedic',  450, '{}', '{}'),
  ('ambulance', 2, 'doctor',     'Doctor',     600, '{}', '{}'),
  ('ambulance', 3, 'surgeon',    'Surgeon',    800, '{}', '{}'),
  ('ambulance', 4, 'boss',       'Chief',     1000, '{}', '{}');

-- Society account / datastore / inventory used by ambulance billing & management flows
INSERT IGNORE INTO `addon_account` (`name`, `label`, `shared`) VALUES
  ('society_ambulance', 'Ambulance', 1);

INSERT IGNORE INTO `datastore` (`name`, `label`, `shared`) VALUES
  ('society_ambulance', 'Ambulance', 1);

INSERT IGNORE INTO `addon_inventory` (`name`, `label`, `shared`) VALUES
  ('society_ambulance', 'Ambulance', 1);

COMMIT;

SET @has_is_dead := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'users'
    AND COLUMN_NAME = 'is_dead'
);
SET @add_is_dead_sql := IF(
  @has_is_dead = 0,
  'ALTER TABLE `users` ADD COLUMN `is_dead` TINYINT(1) NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt FROM @add_is_dead_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_items_table := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'items'
);
SET @items_has_weight := IF(
  @has_items_table > 0,
  (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'items'
      AND COLUMN_NAME = 'weight'
  ),
  0
);
SET @items_has_limit := IF(
  @has_items_table > 0,
  (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'items'
      AND COLUMN_NAME = 'limit'
  ),
  0
);
SET @items_has_rare := IF(
  @has_items_table > 0,
  (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'items'
      AND COLUMN_NAME = 'rare'
  ),
  0
);
SET @items_has_can_remove := IF(
  @has_items_table > 0,
  (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'items'
      AND COLUMN_NAME = 'can_remove'
  ),
  0
);

SET @items_sql := IF(
  @items_has_weight > 0,
  IF(
    @items_has_rare > 0 AND @items_has_can_remove > 0,
    'INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
      (''md_medikit'', ''ชุดปฐมพยาบาล'', 1, 0, 1),
      (''md_syringe'', ''เข็มฉีดยา'', 1, 0, 1),
      (''ag_medikit'', ''First Aid Kit'', 1, 0, 1),
      (''ag_scuba'', ''Oxygen Mask'', 1, 0, 1),
      (''coin_xp'', ''EXP Coin'', 1, 0, 1)',
    'INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES
      (''md_medikit'', ''ชุดปฐมพยาบาล'', 1),
      (''md_syringe'', ''เข็มฉีดยา'', 1),
      (''ag_medikit'', ''First Aid Kit'', 1),
      (''ag_scuba'', ''Oxygen Mask'', 1),
      (''coin_xp'', ''EXP Coin'', 1)'
  ),
  IF(
    @items_has_limit > 0,
    IF(
      @items_has_rare > 0 AND @items_has_can_remove > 0,
      'INSERT IGNORE INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES
        (''md_medikit'', ''ชุดปฐมพยาบาล'', -1, 0, 1),
        (''md_syringe'', ''เข็มฉีดยา'', -1, 0, 1),
        (''coin_xp'', ''EXP Coin'', -1, 0, 1)',
      'INSERT IGNORE INTO `items` (`name`, `label`, `limit`) VALUES
        (''md_medikit'', ''ชุดปฐมพยาบาล'', -1),
        (''md_syringe'', ''เข็มฉีดยา'', -1),
        (''coin_xp'', ''EXP Coin'', -1)'
    ),
    'SELECT 1'
  )
);
PREPARE stmt FROM @items_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
