# Kitchen Clerk examples

Natural-language commands that map onto this MySQL schema. Day-to-day mutator is grok.com SQL against `kitchen_inventory` (production) or `kitchen_inventory_test` (sandbox). No app required.

Speak in household terms. Include **where** and a **number + unit** when adding or using stock.

## Inventory

```
Add 12 carrots to the fridge.
Add a 1 lb package of ground beef to the freezer, expires 2026-09-20.
I have a half gallon of milk in the fridge.
Move the pork chops from freezer to fridge.
I used 2 carrots.
Consume 2 carrots.
I threw out the rest of the sour cream.
I counted 4 eggs left.
Split the ground beef: 0.5 lb stays in the freezer, 0.5 lb goes to the fridge.
What’s in the fridge?
What’s on hand?
What expires this week?
```

Count what is *inside* the package when recipes will ask for pieces (`12 carrots`, not `1 bag`). Use the package as `1 each` only when you treat the whole jar/bag as the unit (`1 jar chili powder`).

Do not invent units like `bag`, `can`, or `bunch`. Count is `each` or `dozen`. Package weight/volume belongs on `item.count_mass_g` / `item.count_volume_ml`.

## Recipes (Google Drive loop)

```
Pull Oven-Fried Pork Chops from Drive and add it as a recipe.
Show me the pork chops recipe.
What do I need for Flourless Fudgie Brownies?
Add what I have for that recipe; ask me if the location isn’t obvious.
Update the brownie recipe from Drive again.
```

Workflow:

1. Pull the recipe from Google Drive.
2. Load ingredients into the database.
3. Compare to physical on-hand stock.
4. Log what you actually have.
5. Whatever is missing is the shopping list.

Recipe units are compared to lot units. Cups vs pounds are not converted unless `item.density_g_per_ml` (and related factors) exist. If they don’t, list the gap and flag the mismatch.

## Menu planning

```
Plan Oven-Fried Pork Chops for dinner tomorrow, 2 servings.
What’s for dinner this week?
Add candied carrots as a side on Monday dinner.
I cooked the pork chops.
Skip Monday dinner.
Move Tuesday dinner to Wednesday.
```

More than one recipe per date + slot is allowed (main + side).

Marking a meal `cooked` must consume lots in the same transaction. Do not flip status alone. FIFO cook / shopping-gap conversion is specified in `docs/design.md` but not automated yet.

## Production vs test

```
Switch to production. Start empty.
Add Counter and Bread Box to production.
Don’t copy test data.
```

`kitchen_inventory_test` is sandbox data only. Production starts with the same schema and empty inventory.

## Checks

```
Show drift.
Show the rows for carrots.
Shopping list for this week’s meal plan.
```

`v_lot_ledger_drift` must stay empty. Every receive / consume / waste / adjust dual-writes `lot.qty_remaining` and a signed `movement`.

## Daily combo

```
Pull [recipe] from Drive. Plan it for [day] [meal]. Tell me what I need to get.
```
