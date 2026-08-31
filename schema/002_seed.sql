-- Lookup seed only. Do NOT INSERT into schema_migrations from this file.
SET NAMES utf8mb4;

INSERT INTO dimension (id, code, name, si_symbol) VALUES
  (1, 'mass',   'Mass',   'g'),
  (2, 'volume', 'Volume', 'ml'),
  (3, 'count',  'Count',  '1');

INSERT INTO unit (code, name, dimension_id, to_base_factor, sort_order, is_metric) VALUES
  ('g',     'gram',          1, 1.0000000000,     10, 1),
  ('kg',    'kilogram',      1, 1000.0000000000,  20, 1),
  ('oz',    'ounce',         1, 28.3495231250,    30, 0),
  ('lb',    'pound',         1, 453.5923700000,   40, 0),
  -- Volume base = millilitre. US customary (not US legal cup 240, not metric 250).
  ('ml',    'millilitre',    2, 1.0000000000,     10, 1),
  ('l',     'litre',         2, 1000.0000000000,  20, 1),
  ('tsp',   'teaspoon',      2, 4.9289215938,     30, 0),
  ('tbsp',  'tablespoon',    2, 14.7867647813,    40, 0),
  ('fl_oz', 'fluid ounce',   2, 29.5735295625,    50, 0),
  ('cup',   'cup (US)',      2, 236.5882365000,   60, 0),
  ('pint',  'pint (US)',     2, 473.1764730000,   70, 0),
  ('quart', 'quart (US)',    2, 946.3529460000,   80, 0),
  ('gallon','gallon (US)',   2, 3785.4117840000,  90, 0),
  -- Count base = each. dozen is the only global scale. No can/bunch (would 1:1 as each).
  ('each',  'each',          3, 1.0000000000,     10, 1),
  ('dozen', 'dozen',         3, 12.0000000000,    20, 1);

INSERT INTO location (code, name, sort_order) VALUES
  ('fridge',  'Fridge',  10),
  ('freezer', 'Freezer', 20),
  ('pantry',  'Pantry',  30);

INSERT INTO movement_type (id, code, name, qty_sign) VALUES
  (1, 'receive',  'Receive',  1),
  (2, 'consume',  'Consume', -1),
  (3, 'waste',    'Waste',   -1),
  (4, 'adjust',   'Adjust',   0),
  (5, 'transfer', 'Transfer', 0),
  (6, 'split',    'Split',    0);

INSERT INTO meal_slot (id, code, name, sort_order) VALUES
  (1, 'breakfast', 'Breakfast', 10),
  (2, 'lunch',     'Lunch',     20),
  (3, 'dinner',    'Dinner',    30),
  (4, 'snack',     'Snack',     40);

INSERT INTO meal_plan_status (id, code, name) VALUES
  (1, 'planned', 'Planned'),
  (2, 'cooked',  'Cooked'),
  (3, 'skipped', 'Skipped');
