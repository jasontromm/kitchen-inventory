# Kitchen Inventory — agent notes

Household inventory on MySQL 8 at `mysql.yourhost.name`. **Operational mutator is grok.com (SQL).** Python in this repo is optional later (conversion hub, FIFO `cook_meal`). phpMyAdmin is SELECT / lookup INSERTs.

Live DB: `kitchen_inventory`. Test: `kitchen_inventory_test` (do not cook real food there).

`HOUSEHOLD_TZ` is an IANA zone (example `America/New_York`); change it to your location so expiry “today” matches the household calendar. Remote MySQL allowable hosts: `%` is typical (depends on who hosts the DB).

## Do not

- Read, `cat`, or print `.env`. Do not paste `MYSQL_PASSWORD` into chat.
- `UPDATE lot.qty_remaining` without a matching `movement` in the same transaction.
- `DELETE` lots (deplete to 0). Do not `DELETE` items/recipes that still have lots/ingredients.
- Run `schema/reset.sql` unless the owner asked for a wipe.
- Invent `can` / `bunch` as global units. Count is `each` / `dozen`. Package size goes on `item.count_mass_g` / `count_volume_ml`.
- Treat cups vs pounds as comparable without `item.density_g_per_ml` (and the conversion rules in `docs/design.md`). If units differ and factors are missing, say so — do not guess.

## Dual-write (required)

`lot.qty_remaining` is operational on-hand. `movement.qty_delta` is history, **in the lot’s unit**. After every receive/consume/waste/adjust, `lot.qty_remaining` must equal `SUM(movement.qty_delta)` for that lot. Check: `SELECT * FROM v_lot_ledger_drift;` — must be empty.

Lookups by `code`, not hardcoded ids (ids are stable in seed but codes are the API):

```sql
SELECT id FROM location WHERE code = 'freezer';  -- fridge | freezer | pantry
SELECT id FROM unit WHERE code = 'lb';           -- g kg oz lb ml l tsp tbsp fl_oz cup pint quart gallon each dozen
SELECT id FROM movement_type WHERE code = 'receive';  -- receive 1 / consume -1 / waste -1 / adjust 0 / transfer 0 / split 0
```

`actor` = `'grok'` unless the user said otherwise.

## Receive (add inventory)

1. Ensure `item` exists (`UNIQUE(name, brand)`; unbranded `brand = ''`; empty UPC → NULL).
2. `INSERT lot` with `qty_remaining = qty`, storage `unit_id`, `location_id`, `expires_on` (DATE or NULL).
3. `INSERT movement`: type `receive`, `qty_delta = +qty`, `unit_id` = lot unit, `to_location_id` = lot location.

```sql
START TRANSACTION;

INSERT INTO item (name, brand, default_unit_id, default_location_id)
VALUES ('chicken thighs', '', (SELECT id FROM unit WHERE code = 'lb'),
        (SELECT id FROM location WHERE code = 'freezer'))
ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id);
SET @item_id = LAST_INSERT_ID();

INSERT INTO lot (item_id, location_id, unit_id, qty_remaining, expires_on, notes)
VALUES (
  @item_id,
  (SELECT id FROM location WHERE code = 'freezer'),
  (SELECT id FROM unit WHERE code = 'lb'),
  5.0000,
  '2026-12-01',
  NULL
);
SET @lot_id = LAST_INSERT_ID();

INSERT INTO movement (lot_id, movement_type_id, qty_delta, unit_id, to_location_id, actor, notes)
VALUES (
  @lot_id,
  (SELECT id FROM movement_type WHERE code = 'receive'),
  5.0000,
  (SELECT id FROM unit WHERE code = 'lb'),
  (SELECT id FROM location WHERE code = 'freezer'),
  'grok',
  NULL
);

COMMIT;
```

## Consume / waste

Same lot unit only. Negative `qty_delta`. Refuse if `qty_remaining < qty`.

```sql
START TRANSACTION;
SELECT id, qty_remaining, unit_id, location_id FROM lot WHERE id = ? FOR UPDATE;
-- if qty_remaining < take: ROLLBACK
UPDATE lot SET qty_remaining = qty_remaining - ? WHERE id = ?;
INSERT INTO movement (lot_id, movement_type_id, qty_delta, unit_id, from_location_id, actor, notes)
VALUES (?, (SELECT id FROM movement_type WHERE code = 'consume'), -?, ?, ?, 'grok', NULL);
COMMIT;
```

Use `waste` instead of `consume` when throwing out. Physical recount: `adjust`, `qty_delta = new_qty - old_qty`, notes required, `qty_delta <> 0`.

## On-hand / expiring

```sql
SELECT * FROM v_on_hand ORDER BY location_code, item_name;
SELECT * FROM v_on_hand WHERE expires_on IS NOT NULL AND expires_on <= DATE_ADD(CURDATE(), INTERVAL 7 DAY);
```

`v_expiring` is UTC-date sugar. Prefer an explicit household date if the user cares about local midnight.

## Recipes

`recipe.instructions` is one TEXT. Ingredients are **as pulled from lots** at `default_servings`. Same item may appear twice (dough + dusting).

```sql
INSERT INTO recipe (name, default_servings, instructions) VALUES ('chili', 6, '...');
SET @rid = LAST_INSERT_ID();

INSERT INTO recipe_ingredient (recipe_id, item_id, qty, unit_id, sort_order, optional)
VALUES
  (@rid, @item_id, 2.0000, (SELECT id FROM unit WHERE code = 'lb'), 10, 0);
```

Replace-all ingredients: `DELETE FROM recipe_ingredient WHERE recipe_id = ?` then INSERT.

Read a recipe:

```sql
SELECT r.name, r.default_servings, r.instructions,
       ri.sort_order, i.name AS item, i.brand, ri.qty, u.code AS unit, ri.optional, ri.notes
FROM recipe r
JOIN recipe_ingredient ri ON ri.recipe_id = r.id
JOIN item i ON i.id = ri.item_id
JOIN unit u ON u.id = ri.unit_id
WHERE r.name = ?
ORDER BY ri.sort_order, ri.id;
```

“Can I cook this?” in SQL is only honest when recipe units match lot units (or you convert with documented item factors). If they don’t, list ingredients vs `v_on_hand` and flag the unit mismatch — do not cook-consume across units by guessing.

`cook_meal` / FIFO / shopping-gap conversion: not implemented. Do not mark `meal_plan` cooked unless you also consumed lots in one transaction.

## Schema apply (already done on the owner’s CLI)

`schema/001_init.sql` then `schema/002_seed.sql`, then:

```sql
INSERT INTO schema_migrations (filename) VALUES ('001_init.sql'), ('002_seed.sql');
```

Half-applied `001`: `schema/reset.sql` by hand, then retry.

## Python in this repo

`src/kitchen_inventory/` is connect / `assert_server` / `migrate_apply` only. Lot and recipe modules were deferred. Remote MySQL must allow the client host; `%` is typical (depends on who hosts the DB). phpMyAdmin on the server can succeed while Grok cannot until that grant is in place.

## Read next

1. `docs/design.md` — full rules (conversion hub, FIFO, dual-write)
2. `schema/001_init.sql` + `schema/002_seed.sql`
3. `README.md` — current status
