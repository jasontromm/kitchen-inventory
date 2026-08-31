# Kitchen Inventory

Household freezer / pantry / fridge inventory on MySQL 8. **Day-to-day mutator is grok.com (SQL)** — add lots, read recipes. No web app in v1; phpMyAdmin is SELECT / lookup inserts. Python in this repo is optional later.

GitHub: `youruser/kitchen-inventory` (rename to your account when publishing).

## Status (2026-08-30)

**Schema is applied. Python lot/recipe APIs are deferred.**

| Piece | State |
|---|---|
| Product decisions | Locked (lots, flat locations, recipes + meal plan, generic names + optional UPC) |
| Design doc | Approved v0.4 — [`docs/design.md`](docs/design.md) |
| DDL + seed | Applied via CLI (`001` + `002`; CHECK regexp uses `utf8mb4_0900_as_cs`) |
| Day-to-day use | grok.com SQL — see [`AGENTS.md`](AGENTS.md) |
| Python connector | Still here (connect / migrate / ping). Not required for receive/list/recipe CRUD |
| Lot / recipe / cook APIs | Specified; **not implemented**. Conversion + FIFO cook stay in the design until we need them |
| Remote MySQL | Allow the client host; `%` is typical (depends on who hosts the DB) |

phpMyAdmin on the same server can work while a laptop or Grok session cannot until allowable hosts include `%` (or that client). Exact grant UI depends on the host.

## What this is

Catalog of **items** plus physical **lots** (a bag of thighs, a jar of sauce, leftover chili) with remaining qty, location, and expiry. Recipes are consumption specs, not plated yield. Cooking a meal-plan row consumes lots FIFO by expiry in one transaction. Unit conversion (cups vs pounds) is a fail-closed hub.

Every qty change dual-writes `lot.qty_remaining` and a signed `movement` in the same transaction. `v_lot_ledger_drift` must stay empty.

## Layout

```
docs/design.md              approved schema, conversion, cook path, PR plan
docs/Kitchen-Inventory-Schema.pptx   8-slide ER / FK / dual-write deck (open in Google Slides)
docs/schema-deck.js         rebuild: `npm install && node docs/schema-deck.js`
schema/001_init.sql         tables, FKs, CHECKs, views
schema/002_seed.sql         dimensions, units, locations, movement types, meal slots
schema/reset.sql            emergency DROP — never auto-applied
src/kitchen_inventory/      PyMySQL package (connector only, so far)
scripts/ping_db.py          version, grants, TLS, tables
AGENTS.md                   grok.com SQL write path (receive, consume, recipes)
.env.example                env names; empty password
```

Lookups seeded: fridge / freezer / pantry; mass / volume / count units (`each` and `dozen` only for count). No items, recipes, or lots in seed.

## Prerequisites

What you need to use this the intended way (Grok talking SQL to the database):

- **MySQL 8.0.16+** (not MariaDB) with `STRICT_TRANS_TABLES`. InnoDB, `utf8mb4`.
- Two databases on that server: `kitchen_inventory` (live) and `kitchen_inventory_test` (sandbox). Apply [`schema/001_init.sql`](schema/001_init.sql) then [`schema/002_seed.sql`](schema/002_seed.sql).
- A MySQL user that can read/write those DBs. Remote clients (laptop, grok.com, Grok app) need an allowable host of **`%`** — typical, but the UI depends on who hosts the DB.
- A **Grok account** (grok.com and/or the Grok app). Point that session at this repo (especially [`AGENTS.md`](AGENTS.md)) so it dual-writes lots and movements instead of editing qty in isolation.

`requirements.txt` / `pyproject.toml` are **optional** Python packages for `ping_db.py` and `migrate_apply()`. You do not need them to add inventory or read recipes.

## Setup (schema)

```bash
mysql -u youruser -p -h mysql.yourhost.name kitchen_inventory_test < schema/001_init.sql
mysql -u youruser -p -h mysql.yourhost.name kitchen_inventory_test < schema/002_seed.sql
mysql -u youruser -p -h mysql.yourhost.name kitchen_inventory_test -e \
  "INSERT INTO schema_migrations (filename) VALUES ('001_init.sql'), ('002_seed.sql');"
```

Repeat for `kitchen_inventory`. If `001` dies mid-file, run `schema/reset.sql` by hand and retry.

phpMyAdmin-first path: source `001` then `002`, then the same `INSERT` into `schema_migrations`.

Set `HOUSEHOLD_TZ` to your IANA zone (example `America/New_York`) if you use the Python date helpers. Password is never in git.

## Optional Python connector

```bash
python3 -m venv .venv   # or: uv venv .venv
.venv/bin/pip install -e ".[dev]"   # or: pip install -r requirements.txt
cp .env.example .env && chmod 0600 .env   # fill MYSQL_PASSWORD; do not commit
.venv/bin/python scripts/ping_db.py
```

Required env: `MYSQL_HOST`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE`. TLS on by default (`MYSQL_SSL=1`). pytest mutators must use `kitchen_inventory_test` only.

```python
from kitchen_inventory.db import connect, assert_server, migrate_apply
conn = connect()
assert_server(conn)
migrate_apply(conn)   # 001 then 002; writes schema_migrations
```

## Next

Use grok.com (or CLI) against the live DB with the SQL in [`AGENTS.md`](AGENTS.md). Revisit Python if conversion / FIFO cook / shopping-gap need to be mechanical rather than conversational.
