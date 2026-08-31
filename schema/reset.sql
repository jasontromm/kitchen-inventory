-- EMERGENCY RESET. Drops all v1 objects. Not run by migrate.
-- Use when 001_init.sql failed mid-file (half schema, no schema_migrations row).
-- mysql -u youruser -p -h mysql.yourhost.name kitchen_inventory < schema/reset.sql
SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS v_split_drift;
DROP VIEW IF EXISTS v_lot_ledger_drift;
DROP VIEW IF EXISTS v_lot_ledger;
DROP VIEW IF EXISTS v_expiring;
DROP VIEW IF EXISTS v_on_hand;
DROP TABLE IF EXISTS movement;
DROP TABLE IF EXISTS meal_plan;
DROP TABLE IF EXISTS recipe_ingredient;
DROP TABLE IF EXISTS recipe;
DROP TABLE IF EXISTS lot;
DROP TABLE IF EXISTS item;
DROP TABLE IF EXISTS meal_plan_status;
DROP TABLE IF EXISTS meal_slot;
DROP TABLE IF EXISTS movement_type;
DROP TABLE IF EXISTS location;
DROP TABLE IF EXISTS unit;
DROP TABLE IF EXISTS dimension;
DROP TABLE IF EXISTS schema_migrations;
SET FOREIGN_KEY_CHECKS = 1;
