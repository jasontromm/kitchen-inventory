-- kitchen_inventory v1 schema. Target: MySQL 8.0.16+ (not MariaDB).
-- Do NOT INSERT into schema_migrations from this file.
-- Apply only after assert_server() (or ping_db.py) succeeds.
-- mysql -u youruser -p -h mysql.yourhost.name kitchen_inventory < schema/001_init.sql

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE schema_migrations (
  filename   VARCHAR(128) NOT NULL,
  applied_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (filename)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='SQL file ledger; ONLY migrate.apply() inserts rows';

CREATE TABLE dimension (
  id         TINYINT UNSIGNED NOT NULL,
  code       VARCHAR(32)  NOT NULL,
  name       VARCHAR(64)  NOT NULL,
  si_symbol  VARCHAR(16)  NOT NULL COMMENT 'g | ml | 1',
  PRIMARY KEY (id),
  UNIQUE KEY uq_dimension_code (code),
  CONSTRAINT ck_dimension_code CHECK (code COLLATE utf8mb4_0900_as_cs REGEXP '^[a-z][a-z0-9_]{0,31}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE unit (
  id              SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code            VARCHAR(32)  NOT NULL COMMENT 'g, lb, cup, each, dozen',
  name            VARCHAR(64)  NOT NULL,
  dimension_id    TINYINT UNSIGNED NOT NULL,
  to_base_factor  DECIMAL(20,10) NOT NULL COMMENT 'multiply qty by this to get dimension base',
  sort_order      SMALLINT NOT NULL DEFAULT 0,
  is_metric       TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_unit_code (code),
  KEY idx_unit_dimension (dimension_id),
  CONSTRAINT fk_unit_dimension FOREIGN KEY (dimension_id) REFERENCES dimension (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_unit_factor CHECK (to_base_factor > 0),
  CONSTRAINT ck_unit_code CHECK (code COLLATE utf8mb4_0900_as_cs REGEXP '^[a-z][a-z0-9_]{0,31}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE location (
  id          SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code        VARCHAR(32)  NOT NULL,
  name        VARCHAR(64)  NOT NULL,
  sort_order  SMALLINT NOT NULL DEFAULT 0,
  is_active   TINYINT(1) NOT NULL DEFAULT 1,
  created_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_location_code (code),
  CONSTRAINT ck_location_code CHECK (code COLLATE utf8mb4_0900_as_cs REGEXP '^[a-z][a-z0-9_]{0,31}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE movement_type (
  id        TINYINT UNSIGNED NOT NULL,
  code      VARCHAR(32) NOT NULL,
  name      VARCHAR(64) NOT NULL,
  qty_sign  TINYINT NOT NULL COMMENT '1 inbound, -1 outbound, 0 transfer-or-either',
  PRIMARY KEY (id),
  UNIQUE KEY uq_movement_type_code (code),
  CONSTRAINT ck_movement_type_sign CHECK (qty_sign IN (-1, 0, 1)),
  CONSTRAINT ck_movement_type_code CHECK (code COLLATE utf8mb4_0900_as_cs REGEXP '^[a-z][a-z0-9_]{0,31}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE meal_slot (
  id          TINYINT UNSIGNED NOT NULL,
  code        VARCHAR(32) NOT NULL,
  name        VARCHAR(64) NOT NULL,
  sort_order  SMALLINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_meal_slot_code (code),
  CONSTRAINT ck_meal_slot_code CHECK (code COLLATE utf8mb4_0900_as_cs REGEXP '^[a-z][a-z0-9_]{0,31}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE meal_plan_status (
  id    TINYINT UNSIGNED NOT NULL,
  code  VARCHAR(32) NOT NULL,
  name  VARCHAR(64) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_meal_plan_status_code (code),
  CONSTRAINT ck_meal_plan_status_code CHECK (code COLLATE utf8mb4_0900_as_cs REGEXP '^[a-z][a-z0-9_]{0,31}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE item (
  id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name                VARCHAR(128) NOT NULL,
  brand               VARCHAR(128) NOT NULL DEFAULT '' COMMENT 'empty string = unbranded',
  upc                 VARCHAR(14)  NULL COMMENT 'GTIN-8/12/13/14; Python coerces empty to NULL',
  default_unit_id     SMALLINT UNSIGNED NOT NULL COMMENT 'canonical storage / gap / cook working unit',
  default_location_id SMALLINT UNSIGNED NULL,
  density_g_per_ml    DECIMAL(20,10) NULL COMMENT 'mass/volume bridge; water=1',
  count_mass_g        DECIMAL(20,10) NULL COMMENT 'grams per 1 each (count base)',
  count_volume_ml     DECIMAL(20,10) NULL COMMENT 'ml per 1 each',
  notes               VARCHAR(512) NULL,
  archived_at         DATETIME(6) NULL,
  created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_item_name_brand (name, brand),
  UNIQUE KEY uq_item_upc (upc),
  KEY idx_item_archived (archived_at),
  CONSTRAINT fk_item_default_unit FOREIGN KEY (default_unit_id) REFERENCES unit (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_item_default_location FOREIGN KEY (default_location_id) REFERENCES location (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_item_density CHECK (density_g_per_ml IS NULL OR density_g_per_ml > 0),
  CONSTRAINT ck_item_count_mass CHECK (count_mass_g IS NULL OR count_mass_g > 0),
  CONSTRAINT ck_item_count_vol CHECK (count_volume_ml IS NULL OR count_volume_ml > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Catalog noun. Leftovers are items; batches are lots';

CREATE TABLE lot (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  item_id        BIGINT UNSIGNED NOT NULL,
  location_id    SMALLINT UNSIGNED NOT NULL,
  unit_id        SMALLINT UNSIGNED NOT NULL COMMENT 'immutable after insert',
  qty_remaining  DECIMAL(12,4) NOT NULL,
  expires_on     DATE NULL COMMENT 'use-by calendar day; NULL = unknown',
  received_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  opened_at      DATETIME(6) NULL COMMENT 'reserved; unused by v1 API; copied on split',
  notes          VARCHAR(512) NULL,
  created_at     DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at     DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  KEY idx_lot_item_loc (item_id, location_id),
  KEY idx_lot_on_hand (item_id, qty_remaining, location_id),
  KEY idx_lot_expires (expires_on),
  KEY idx_lot_fifo (item_id, expires_on, received_at, id),
  KEY idx_lot_location (location_id),
  CONSTRAINT fk_lot_item FOREIGN KEY (item_id) REFERENCES item (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_lot_location FOREIGN KEY (location_id) REFERENCES location (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_lot_unit FOREIGN KEY (unit_id) REFERENCES unit (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_lot_qty CHECK (qty_remaining >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Physical package/batch. Do not DELETE; deplete to 0';

CREATE TABLE recipe (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name              VARCHAR(128) NOT NULL,
  default_servings  DECIMAL(6,2) NOT NULL,
  instructions      TEXT NULL COMMENT 'v1 single blob; no recipe_step table',
  notes             VARCHAR(512) NULL,
  archived_at       DATETIME(6) NULL,
  created_at        DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at        DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_recipe_name (name),
  CONSTRAINT ck_recipe_servings CHECK (default_servings > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE recipe_ingredient (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  recipe_id   BIGINT UNSIGNED NOT NULL,
  item_id     BIGINT UNSIGNED NOT NULL,
  qty         DECIMAL(12,4) NOT NULL COMMENT 'qty at recipe.default_servings, inventory consumption',
  unit_id     SMALLINT UNSIGNED NOT NULL,
  sort_order  SMALLINT NOT NULL DEFAULT 0,
  optional    TINYINT(1) NOT NULL DEFAULT 0,
  notes       VARCHAR(256) NULL,
  PRIMARY KEY (id),
  KEY idx_ri_recipe (recipe_id, sort_order),
  KEY idx_ri_item (item_id),
  CONSTRAINT fk_ri_recipe FOREIGN KEY (recipe_id) REFERENCES recipe (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_ri_item FOREIGN KEY (item_id) REFERENCES item (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_ri_unit FOREIGN KEY (unit_id) REFERENCES unit (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_ri_qty CHECK (qty > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE meal_plan (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  plan_date         DATE NOT NULL,
  meal_slot_id      TINYINT UNSIGNED NOT NULL,
  recipe_id         BIGINT UNSIGNED NOT NULL,
  planned_servings  DECIMAL(6,2) NOT NULL,
  status_id         TINYINT UNSIGNED NOT NULL,
  cooked_at         DATETIME(6) NULL COMMENT 'Python: cooked <=> cooked_at IS NOT NULL; no DDL tautology',
  notes             VARCHAR(512) NULL,
  created_at        DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at        DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  KEY idx_mp_date_slot (plan_date, meal_slot_id),
  KEY idx_mp_status_date (status_id, plan_date),
  KEY idx_mp_recipe (recipe_id),
  CONSTRAINT fk_mp_slot FOREIGN KEY (meal_slot_id) REFERENCES meal_slot (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_mp_recipe FOREIGN KEY (recipe_id) REFERENCES recipe (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_mp_status FOREIGN KEY (status_id) REFERENCES meal_plan_status (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_mp_servings CHECK (planned_servings > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Multiple recipes per date+slot allowed (main + side)';

CREATE TABLE movement (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  lot_id             BIGINT UNSIGNED NOT NULL,
  movement_type_id   TINYINT UNSIGNED NOT NULL,
  qty_delta          DECIMAL(12,4) NOT NULL COMMENT 'signed, in lot.unit_id',
  unit_id            SMALLINT UNSIGNED NOT NULL COMMENT 'must equal lot.unit_id',
  from_location_id   SMALLINT UNSIGNED NULL,
  to_location_id     SMALLINT UNSIGNED NULL,
  meal_plan_id       BIGINT UNSIGNED NULL,
  group_id           CHAR(36) NULL COMMENT 'uuid linking split pair',
  actor              VARCHAR(64) NULL,
  occurred_at        DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  notes              VARCHAR(512) NULL,
  created_at         DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  KEY idx_mov_lot_time (lot_id, occurred_at),
  KEY idx_mov_type_time (movement_type_id, occurred_at),
  KEY idx_mov_meal (meal_plan_id),
  KEY idx_mov_group (group_id),
  KEY idx_mov_occurred (occurred_at),
  CONSTRAINT fk_mov_lot FOREIGN KEY (lot_id) REFERENCES lot (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_mov_type FOREIGN KEY (movement_type_id) REFERENCES movement_type (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_mov_unit FOREIGN KEY (unit_id) REFERENCES unit (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_mov_from_loc FOREIGN KEY (from_location_id) REFERENCES location (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_mov_to_loc FOREIGN KEY (to_location_id) REFERENCES location (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_mov_meal FOREIGN KEY (meal_plan_id) REFERENCES meal_plan (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Append-mostly ledger. Do not UPDATE qty_delta';

CREATE VIEW v_on_hand AS
SELECT
  lot.id              AS lot_id,
  lot.item_id,
  item.name           AS item_name,
  item.brand,
  lot.location_id,
  location.code       AS location_code,
  location.name       AS location_name,
  lot.unit_id,
  unit.code           AS unit_code,
  unit.dimension_id,
  lot.qty_remaining,
  lot.expires_on,
  lot.received_at,
  lot.opened_at,
  lot.notes
FROM lot
JOIN item     ON item.id = lot.item_id
JOIN location ON location.id = lot.location_id
JOIN unit     ON unit.id = lot.unit_id
WHERE lot.qty_remaining > 0;

-- phpMyAdmin sugar only. Uses session CURDATE() (UTC under our connections).
-- Not the Python API; not parameterized (within_days). Do not treat as source of truth near local midnight.
CREATE VIEW v_expiring AS
SELECT *
FROM v_on_hand
WHERE expires_on IS NOT NULL
  AND expires_on <= (CURDATE() + INTERVAL 7 DAY);

CREATE VIEW v_lot_ledger AS
SELECT
  lot.id AS lot_id,
  lot.qty_remaining,
  COALESCE(SUM(movement.qty_delta), 0) AS ledger_qty,
  lot.qty_remaining - COALESCE(SUM(movement.qty_delta), 0) AS drift
FROM lot
LEFT JOIN movement ON movement.lot_id = lot.id
GROUP BY lot.id, lot.qty_remaining;

CREATE VIEW v_lot_ledger_drift AS
SELECT *
FROM v_lot_ledger
WHERE drift <> 0;

CREATE VIEW v_split_drift AS
SELECT
  movement.group_id,
  SUM(movement.qty_delta) AS qty_sum,
  COUNT(*) AS n
FROM movement
JOIN movement_type ON movement_type.id = movement.movement_type_id
WHERE movement_type.code = 'split'
  AND movement.group_id IS NOT NULL
GROUP BY movement.group_id
HAVING SUM(movement.qty_delta) <> 0 OR COUNT(*) <> 2;
