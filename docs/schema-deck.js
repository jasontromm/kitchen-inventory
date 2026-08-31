/*
 * Kitchen Inventory — MySQL schema & relationships
 * Editorial template language (warm paper, Georgia / Consolas).
 * Run:  node docs/schema-deck.js
 */
const pptxgen = require("pptxgenjs");

const pres = new pptxgen();
pres.defineLayout({ name: "EDITORIAL", width: 20, height: 11.25 });
pres.layout = "EDITORIAL";
pres.title = "Kitchen Inventory — Database Schema";
pres.author = "Kitchen Inventory";
pres.subject = "MySQL 8 table layout and foreign keys";

const C = {
  bg: "F5F1EA",
  card: "EFEADF",
  ink: "14110F",
  muted: "6B6057",
  rule: "3A332C",
  rust: "B8573A",
  rustLt: "E8CFC0",
  white: "FFFFFF",
  pk: "3A332C",
  fk: "B8573A",
};
const F = {
  serif: "Georgia",
  mono: "Consolas",
  sans: "Calibri",
};

pres.defineSlideMaster({
  title: "MAIN",
  width: 20,
  height: 11.25,
  background: { color: C.bg },
});

const W = 20, H = 11.25;
const LM = 1.33;
const FOOT_Y = 10.60;

function header(slide, left, right) {
  slide.addText(left, {
    x: LM, y: 0.50, w: 10, h: 0.22,
    fontFace: F.mono, fontSize: 9, color: C.muted, charSpacing: 2, margin: 0,
  });
  slide.addText(right, {
    x: W - LM - 6, y: 0.50, w: 6, h: 0.22,
    fontFace: F.mono, fontSize: 9, color: C.muted, charSpacing: 2,
    align: "right", margin: 0,
  });
}
function footer(slide, page) {
  slide.addText("KITCHEN INVENTORY  ·  MYSQL 8 SCHEMA", {
    x: LM, y: FOOT_Y, w: 10, h: 0.22,
    fontFace: F.mono, fontSize: 9, color: C.muted, charSpacing: 2, margin: 0,
  });
  slide.addText(page, {
    x: W - LM - 3, y: FOOT_Y, w: 3, h: 0.22,
    fontFace: F.mono, fontSize: 9, color: C.muted, charSpacing: 2,
    align: "right", margin: 0,
  });
}
function hLine(slide, x, y, w, opts = {}) {
  slide.addShape("line", {
    x, y, w, h: 0,
    line: { color: opts.color || C.rule, width: opts.width || 0.75, dashType: opts.dash || "solid" },
  });
}
function vLine(slide, x, y, h, opts = {}) {
  slide.addShape("line", {
    x, y, w: 0, h,
    line: { color: opts.color || C.rule, width: opts.width || 0.75, dashType: opts.dash || "solid" },
  });
}

function tableCard(slide, x, y, w, h, title, lines, kind) {
  const head = kind === "lookup" ? C.rule : kind === "fact" ? C.ink : C.rust;
  slide.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h,
    fill: { color: C.card },
    line: { color: C.rule, width: 0.75 },
  });
  slide.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h: 0.36,
    fill: { color: head },
  });
  slide.addText(title, {
    x, y, w, h: 0.36,
    fontFace: F.mono, fontSize: 12, color: C.white, bold: true,
    align: "center", valign: "middle", margin: 0,
  });
  const runs = lines.map((line, i) => ({
    text: line,
    options: { breakLine: i < lines.length - 1, fontFace: F.mono, fontSize: 11, color: C.ink },
  }));
  slide.addText(runs, {
    x: x + 0.12, y: y + 0.42, w: w - 0.24, h: h - 0.52,
    valign: "top", margin: 0,
  });
}

/* =====================================================================
 * SLIDE 1 — Cover
 * ===================================================================== */
{
  const s = pres.addSlide({ masterName: "MAIN" });
  header(s, "KITCHEN INVENTORY", "MYSQL 8  ·  kitchen_inventory");
  hLine(s, LM, 1.00, W - 2 * LM);

  s.addText("Schema & relationships", {
    x: LM, y: 2.40, w: 16, h: 1.10,
    fontFace: F.serif, fontSize: 48, color: C.ink, margin: 0,
  });
  s.addText("Lot-grained household inventory. Catalog of items, physical lots, signed movements, recipes as consumption specs.", {
    x: LM, y: 3.70, w: 12, h: 0.80,
    fontFace: F.serif, fontSize: 18, italic: true, color: C.muted, margin: 0,
  });

  const facts = [
    ["Host", "mysql.yourhost.name"],
    ["User", "youruser"],
    ["Live / test", "kitchen_inventory  /  kitchen_inventory_test"],
    ["Engine", "InnoDB  ·  utf8mb4_0900_ai_ci"],
    ["FKs", "ON DELETE RESTRICT  ·  no lot deletes"],
    ["Mutator", "SQL (grok.com / CLI)  ·  dual-write qty + movement"],
  ];
  facts.forEach((row, i) => {
    const y = 4.85 + i * 0.62;
    s.addText(row[0], {
      x: LM, y, w: 2.4, h: 0.50,
      fontFace: F.mono, fontSize: 12, color: C.rust, charSpacing: 1, margin: 0, valign: "middle",
    });
    s.addText(row[1], {
      x: LM + 2.6, y, w: 12, h: 0.50,
      fontFace: F.serif, fontSize: 18, color: C.ink, margin: 0, valign: "middle",
    });
  });
  footer(s, "01");
}

/* =====================================================================
 * SLIDE 2 — ER: inventory core
 * ===================================================================== */
{
  const s = pres.addSlide({ masterName: "MAIN" });
  header(s, "FIG. 01  ·  ENTITY RELATIONSHIP", "INVENTORY CORE");
  hLine(s, LM, 0.85, W - 2 * LM);
  s.addText("Lookups feed the catalog. A lot is a physical package. movement is the ledger; lot.qty_remaining is operational on-hand. Both written in one transaction.", {
    x: LM, y: 1.00, w: 17.3, h: 0.45,
    fontFace: F.serif, fontSize: 15, italic: true, color: C.muted, margin: 0,
  });

  tableCard(s, 1.33, 1.60, 3.3, 1.70, "dimension", [
    "PK  id",
    "UK  code   mass | volume | count",
    "    si_symbol   g | ml | 1",
  ], "lookup");

  tableCard(s, 5.30, 1.60, 4.0, 2.10, "unit", [
    "PK  id",
    "UK  code   g lb cup each …",
    "FK  dimension_id  → dimension",
    "    to_base_factor  > 0",
  ], "lookup");

  tableCard(s, 10.00, 1.60, 3.6, 1.90, "location", [
    "PK  id",
    "UK  code   fridge freezer pantry",
    "    is_active  sort_order",
  ], "lookup");

  tableCard(s, 14.40, 1.60, 4.2, 1.90, "movement_type", [
    "PK  id",
    "UK  code   receive consume waste",
    "            adjust transfer split",
    "    qty_sign  +1 | −1 | 0",
  ], "lookup");

  // connectors lookups → item/lot
  vLine(s, 7.30, 3.70, 0.40, { color: C.rust, width: 1.25 });
  vLine(s, 11.80, 3.50, 0.60, { color: C.rust, width: 1.25 });

  tableCard(s, 1.33, 4.20, 5.4, 3.10, "item", [
    "PK  id",
    "UK  (name, brand)   brand '' = unbranded",
    "UK  upc   NULL ok; '' coerced to NULL",
    "FK  default_unit_id  → unit",
    "FK  default_location_id  → location",
    "    density_g_per_ml  count_mass_g  count_volume_ml",
    "    leftovers are items; batches are lots",
  ], "fact");

  tableCard(s, 7.40, 4.20, 5.2, 3.10, "lot", [
    "PK  id     do not DELETE; deplete to 0",
    "FK  item_id  → item",
    "FK  location_id  → location",
    "FK  unit_id  → unit   immutable",
    "    qty_remaining  DECIMAL(12,4) ≥ 0",
    "    expires_on DATE   received_at",
    "    opened_at reserved / unused",
  ], "fact");

  tableCard(s, 13.30, 4.20, 5.3, 3.10, "movement", [
    "PK  id     append-mostly ledger",
    "FK  lot_id  → lot",
    "FK  movement_type_id  → movement_type",
    "FK  unit_id  = lot.unit_id",
    "    qty_delta  signed, lot unit",
    "FK  from_location_id / to_location_id",
    "FK  meal_plan_id  group_id  actor",
  ], "fact");

  hLine(s, 6.73, 5.75, 0.67, { color: C.rust, width: 1.25 });
  hLine(s, 12.60, 5.75, 0.70, { color: C.rust, width: 1.25 });

  s.addText("1 item  →  N lots     ·     1 lot  →  N movements     ·     SUM(qty_delta) must equal qty_remaining   (v_lot_ledger_drift empty)", {
    x: LM, y: 7.50, w: 17.3, h: 0.40,
    fontFace: F.mono, fontSize: 13, color: C.ink, margin: 0,
  });
  footer(s, "02");
}

/* =====================================================================
 * SLIDE 3 — ER: recipes & meals
 * ===================================================================== */
{
  const s = pres.addSlide({ masterName: "MAIN" });
  header(s, "FIG. 02  ·  ENTITY RELATIONSHIP", "RECIPES & MEAL PLAN");
  hLine(s, LM, 0.85, W - 2 * LM);
  s.addText("Recipes consume items, not lots. Cooking is a later all-or-nothing FIFO consume of lots. cook_meal is specified, not required for day-to-day SQL.", {
    x: LM, y: 1.00, w: 17.3, h: 0.45,
    fontFace: F.serif, fontSize: 15, italic: true, color: C.muted, margin: 0,
  });

  tableCard(s, 1.33, 1.65, 4.4, 2.00, "meal_slot", [
    "PK  id",
    "UK  code   breakfast lunch",
    "            dinner snack",
  ], "lookup");
  tableCard(s, 6.20, 1.65, 4.4, 2.00, "meal_plan_status", [
    "PK  id",
    "UK  code   planned cooked skipped",
  ], "lookup");
  tableCard(s, 11.10, 1.65, 6.5, 2.00, "item  (shared with inventory)", [
    "PK  id   catalog noun",
    "    default_unit_id is the working unit",
    "    for demand / conversion / gaps",
  ], "fact");

  tableCard(s, 1.33, 4.10, 5.2, 2.70, "recipe", [
    "PK  id",
    "UK  name",
    "    default_servings  > 0",
    "    instructions TEXT  (no step table)",
    "    archived_at",
  ], "fact");

  tableCard(s, 7.20, 4.10, 5.6, 2.90, "recipe_ingredient", [
    "PK  id   surrogate — same item twice ok",
    "FK  recipe_id  → recipe",
    "FK  item_id  → item",
    "FK  unit_id  → unit",
    "    qty  at default_servings  > 0",
    "    optional  sort_order",
  ], "fact");

  tableCard(s, 13.40, 4.10, 5.2, 2.90, "meal_plan", [
    "PK  id",
    "    plan_date",
    "FK  meal_slot_id  → meal_slot",
    "FK  recipe_id  → recipe",
    "    planned_servings  > 0",
    "FK  status_id  → meal_plan_status",
    "    cooked_at   (cooked iff set)",
  ], "fact");

  hLine(s, 6.53, 5.40, 0.67, { color: C.rust, width: 1.25 });
  hLine(s, 12.80, 5.40, 0.60, { color: C.rust, width: 1.25 });
  vLine(s, 14.35, 3.65, 0.45, { color: C.rust, width: 1.25 });

  s.addText("Multiple recipes per date+slot allowed (main + side). Scale consume by planned_servings / default_servings. cook_meal does not insert leftover lots.", {
    x: LM, y: 7.20, w: 17.3, h: 0.50,
    fontFace: F.mono, fontSize: 13, color: C.ink, margin: 0,
  });
  footer(s, "03");
}

/* =====================================================================
 * SLIDE 4 — Cardinality map
 * ===================================================================== */
{
  const s = pres.addSlide({ masterName: "MAIN" });
  header(s, "FIG. 03  ·  FOREIGN KEYS", "ALL ON DELETE RESTRICT");
  hLine(s, LM, 0.85, W - 2 * LM);

  const hdr = (t) => ({
    text: t,
    options: { fill: { color: C.ink }, color: C.white, bold: true, fontFace: F.mono, fontSize: 12, align: "left", valign: "middle", margin: 6 },
  });
  const cell = (t) => ({
    text: t,
    options: { fill: { color: C.card }, color: C.ink, fontFace: F.mono, fontSize: 12, align: "left", valign: "middle", margin: 6 },
  });

  s.addTable(
    [
      [hdr("Child"), hdr("Column"), hdr("Parent"), hdr("Notes")],
      [cell("unit"), cell("dimension_id"), cell("dimension"), cell("mass / volume / count")],
      [cell("item"), cell("default_unit_id"), cell("unit"), cell("working unit for cook / gap")],
      [cell("item"), cell("default_location_id"), cell("location"), cell("nullable putaway hint")],
      [cell("lot"), cell("item_id, location_id, unit_id"), cell("item, location, unit"), cell("unit_id immutable after insert")],
      [cell("movement"), cell("lot_id, movement_type_id, unit_id"), cell("lot, movement_type, unit"), cell("unit_id must equal lot.unit_id")],
      [cell("movement"), cell("from_location_id, to_location_id"), cell("location"), cell("nullable; transfer/split set both")],
      [cell("movement"), cell("meal_plan_id"), cell("meal_plan"), cell("nullable; cook path")],
      [cell("recipe_ingredient"), cell("recipe_id, item_id, unit_id"), cell("recipe, item, unit"), cell("qty at recipe.default_servings")],
      [cell("meal_plan"), cell("recipe_id, meal_slot_id, status_id"), cell("recipe, meal_slot, meal_plan_status"), cell("N recipes per date+slot")],
    ],
    {
      x: LM, y: 1.15, w: 17.34, h: 8.90,
      colW: [3.2, 5.4, 4.4, 4.34],
      border: [{ pt: 0.5, color: C.rule }, { pt: 0.5, color: C.rule }, { pt: 0.5, color: C.rule }, { pt: 0.5, color: C.rule }],
      valign: "middle",
    }
  );
  footer(s, "04");
}

/* =====================================================================
 * SLIDE 5 — Dual-write
 * ===================================================================== */
{
  const s = pres.addSlide({ masterName: "MAIN" });
  header(s, "FIG. 04  ·  WRITE PATH", "DUAL-WRITE");
  hLine(s, LM, 0.85, W - 2 * LM);

  s.addText("One transaction. Never UPDATE lot.qty_remaining without a movement.", {
    x: LM, y: 1.05, w: 17.3, h: 0.40,
    fontFace: F.serif, fontSize: 18, italic: true, color: C.ink, margin: 0,
  });

  const steps = [
    ["01", "receive", "INSERT lot (qty_remaining = qty)\nINSERT movement  type=receive  qty_delta = +qty  to_location_id set"],
    ["02", "consume / waste", "SELECT lot FOR UPDATE\nUPDATE qty_remaining − take  (refuse if short)\nINSERT movement  qty_delta = −take  from_location_id set"],
    ["03", "adjust", "Physical count. notes required.\nqty_delta = new − old  (refuse 0)\nSET qty_remaining = new"],
    ["04", "transfer / split", "Whole lot: qty_delta = 0, move location_id.\nPartial: new lot copies received_at / expires_on; two split rows, same group_id, SUM=0."],
  ];
  steps.forEach((row, i) => {
    const x = LM + (i % 2) * 8.7;
    const y = 1.65 + Math.floor(i / 2) * 3.70;
    s.addShape(pres.shapes.RECTANGLE, {
      x, y, w: 8.3, h: 3.40,
      fill: { color: C.card },
      line: { color: C.rule, width: 0.75 },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x, y, w: 0.12, h: 3.40,
      fill: { color: C.rust },
    });
    s.addText(row[0], {
      x: x + 0.40, y: y + 0.25, w: 1.4, h: 0.50,
      fontFace: F.mono, fontSize: 20, color: C.rust, margin: 0,
    });
    s.addText(row[1], {
      x: x + 1.90, y: y + 0.28, w: 6.0, h: 0.50,
      fontFace: F.serif, fontSize: 22, color: C.ink, margin: 0,
    });
    const bodyLines = row[2].split("\n");
    s.addText(
      bodyLines.map((line, li) => ({
        text: line,
        options: { breakLine: li < bodyLines.length - 1, fontFace: F.mono, fontSize: 14, color: C.ink },
      })),
      { x: x + 0.40, y: y + 1.00, w: 7.5, h: 2.10, margin: 0, valign: "top" }
    );
  });
  footer(s, "05");
}

/* =====================================================================
 * SLIDE 6 — Lookups seed
 * ===================================================================== */
{
  const s = pres.addSlide({ masterName: "MAIN" });
  header(s, "FIG. 05  ·  SEED", "LOOKUP CODES");
  hLine(s, LM, 0.85, W - 2 * LM);

  function seedCol(x, title, lines) {
    s.addShape(pres.shapes.RECTANGLE, {
      x, y: 1.20, w: 4.05, h: 8.90,
      fill: { color: C.card },
      line: { color: C.rule, width: 0.75 },
    });
    s.addText(title, {
      x: x + 0.22, y: 1.40, w: 3.60, h: 0.45,
      fontFace: F.mono, fontSize: 14, color: C.rust, charSpacing: 1, margin: 0,
    });
    s.addText(
      lines.map((line, i) => ({
        text: line.length ? line : " ",
        options: { breakLine: i < lines.length - 1, fontFace: F.mono, fontSize: 14, color: C.ink },
      })),
      { x: x + 0.22, y: 2.00, w: 3.60, h: 7.80, margin: 0, valign: "top" }
    );
  }

  seedCol(1.33, "DIMENSION / UNIT", [
    "mass     g  kg  oz  lb",
    "volume   ml l tsp tbsp",
    "         fl_oz cup pint",
    "         quart gallon",
    "count    each  dozen",
    "",
    "cup = 236.5882365 ml",
    "(US customary, not 240/250)",
    "",
    "No can / bunch globals.",
  ]);
  seedCol(5.63, "LOCATION / TYPE", [
    "location",
    "  fridge   freezer   pantry",
    "",
    "movement_type",
    "  receive   +1",
    "  consume   −1",
    "  waste     −1",
    "  adjust     0",
    "  transfer   0",
    "  split      0",
  ]);
  seedCol(9.93, "MEAL", [
    "meal_slot",
    "  breakfast  lunch",
    "  dinner     snack",
    "",
    "meal_plan_status",
    "  planned",
    "  cooked",
    "  skipped",
  ]);
  seedCol(14.23, "CODES", [
    "Lookups keyed by code,",
    "not autoincrement ids.",
    "",
    "CHECK:",
    "  ^[a-z][a-z0-9_]{0,31}$",
    "  COLLATE as_cs",
    "",
    "schema_migrations",
    "  001_init.sql",
    "  002_seed.sql",
  ]);
  footer(s, "06");
}

/* =====================================================================
 * SLIDE 7 — Views
 * ===================================================================== */
{
  const s = pres.addSlide({ masterName: "MAIN" });
  header(s, "FIG. 06  ·  VIEWS", "PHPMYADMIN / READ PATH");
  hLine(s, LM, 0.85, W - 2 * LM);

  const views = [
    ["v_on_hand", "Lots with qty_remaining > 0, joined to item, location, unit. Day-to-day on-hand."],
    ["v_expiring", "v_on_hand where expires_on ≤ CURDATE()+7. UTC-date sugar; not parameterized."],
    ["v_lot_ledger", "Per lot: qty_remaining vs SUM(movement.qty_delta) and drift."],
    ["v_lot_ledger_drift", "Rows where drift <> 0. Must be empty after every API/SQL txn."],
    ["v_split_drift", "split movements by group_id where SUM(qty_delta) <> 0 or COUNT(*) <> 2."],
  ];
  views.forEach((row, i) => {
    const y = 1.15 + i * 1.55;
    s.addShape(pres.shapes.RECTANGLE, {
      x: LM, y, w: 17.34, h: 1.40,
      fill: { color: C.card },
      line: { color: C.rule, width: 0.75 },
    });
    s.addShape(pres.shapes.RECTANGLE, {
      x: LM, y, w: 0.12, h: 1.40,
      fill: { color: C.rust },
    });
    s.addText(row[0], {
      x: LM + 0.45, y: y + 0.18, w: 16.5, h: 0.40,
      fontFace: F.mono, fontSize: 18, color: C.ink, margin: 0,
    });
    s.addText(row[1], {
      x: LM + 0.45, y: y + 0.65, w: 16.5, h: 0.55,
      fontFace: F.serif, fontSize: 16, color: C.muted, margin: 0,
    });
  });
  footer(s, "07");
}

/* =====================================================================
 * SLIDE 8 — Isolated + rules
 * ===================================================================== */
{
  const s = pres.addSlide({ masterName: "MAIN" });
  header(s, "FIG. 07  ·  INVARIANTS", "DO NOT VIOLATE");
  hLine(s, LM, 0.85, W - 2 * LM);

  tableCard(s, 1.33, 1.20, 5.5, 2.20, "schema_migrations", [
    "PK  filename",
    "    applied_at",
    "No FKs. Not globbed.",
    "reset.sql is not a migration.",
  ], "lookup");

  const rules = [
    "lot.qty_remaining = SUM(movement.qty_delta) for that lot_id after every commit.",
    "movement.unit_id = lot.unit_id. lot.unit_id never updated.",
    "receive qty_delta > 0; consume/waste < 0; adjust <> 0; whole-lot transfer = 0.",
    "Do not DELETE lots. Do not guess cups↔lb without item density / count factors.",
    "Key lookups by code. actor defaults to grok.",
  ];
  rules.forEach((t, i) => {
    const y = 3.70 + i * 1.15;
    s.addText(String(i + 1).padStart(2, "0"), {
      x: 7.20, y, w: 1.10, h: 0.90,
      fontFace: F.mono, fontSize: 22, color: C.rust, margin: 0, valign: "middle",
    });
    s.addText(t, {
      x: 8.40, y, w: 10.2, h: 0.90,
      fontFace: F.serif, fontSize: 18, color: C.ink, margin: 0, valign: "middle",
    });
  });
  footer(s, "08");
}

pres.writeFile({ fileName: require("path").join(__dirname, "Kitchen-Inventory-Schema.pptx") })
  .then(() => console.log("wrote docs/Kitchen-Inventory-Schema.pptx"))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
