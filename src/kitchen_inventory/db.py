"""Connection, server gate, lookups, and forward migrations."""

from __future__ import annotations

import logging
import os
import re
from contextlib import contextmanager
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Iterator
from zoneinfo import ZoneInfo

import pymysql
from dotenv import load_dotenv
from pymysql.connections import Connection
from pymysql.cursors import DictCursor

from kitchen_inventory.errors import InvalidState

log = logging.getLogger("kitchen_inventory")

LOOKUP_TABLES = frozenset({
    "dimension", "unit", "location", "movement_type",
    "meal_slot", "meal_plan_status",
})
V1_TABLES = frozenset({
    "schema_migrations", "dimension", "unit", "location", "movement_type",
    "meal_slot", "meal_plan_status", "item", "lot", "recipe",
    "recipe_ingredient", "meal_plan", "movement",
})
FORWARD_SQL = ("001_init.sql", "002_seed.sql")
LOCK_ERRNOS = frozenset({1205, 1213, 3572})

_REPO_ROOT = Path(__file__).resolve().parents[2]
_SCHEMA_DIR = _REPO_ROOT / "schema"
_CODE_ID_CACHE: dict[tuple[str, str], int] = {}

_REQUIRED_ENV = ("MYSQL_HOST", "MYSQL_USER", "MYSQL_PASSWORD", "MYSQL_DATABASE")


def _require_env(name: str) -> str:
    val = os.environ.get(name)
    if val is None or val == "":
        raise RuntimeError(f"missing env {name}")
    return val


def translate_lock(e: pymysql.err.OperationalError) -> None:
    if e.args and e.args[0] in LOCK_ERRNOS:
        raise InvalidState("lock wait or deadlock") from e
    raise e


def connect(*, autocommit: bool = False) -> Connection:
    load_dotenv(_REPO_ROOT / ".env", override=False)
    host = _require_env("MYSQL_HOST")
    user = _require_env("MYSQL_USER")
    password = _require_env("MYSQL_PASSWORD")
    database = _require_env("MYSQL_DATABASE")
    port_raw = os.environ.get("MYSQL_PORT") or "3306"
    try:
        port = int(port_raw)
    except ValueError as e:
        raise RuntimeError("MYSQL_PORT must be an integer (empty = 3306)") from e

    ssl_raw = os.environ.get("MYSQL_SSL")
    use_ssl = ssl_raw != "0"
    if not use_ssl:
        log.warning("MYSQL_SSL=0: connecting without TLS (accepted risk)")

    kwargs: dict = {
        "host": host,
        "user": user,
        "password": password,
        "database": database,
        "port": port,
        "charset": "utf8mb4",
        "cursorclass": DictCursor,
        "autocommit": autocommit,
        "connect_timeout": 20,
        "read_timeout": 60,
        "write_timeout": 60,
    }
    if use_ssl:
        # PyMySQL 1.2 wants a dict, not ssl=True.
        kwargs["ssl"] = {}

    conn = pymysql.connect(**kwargs)

    with conn.cursor() as cur:
        cur.execute("SET NAMES utf8mb4")
        cur.execute("SET time_zone = %s", ("+00:00",))
        cur.execute("SET SESSION innodb_lock_wait_timeout = %s", (5,))
    if not autocommit:
        conn.commit()
    return conn


def assert_server(conn: Connection) -> str:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT VERSION() AS v, @@version_comment AS comment, "
            "@@sql_mode AS mode, @@character_set_database AS charset, "
            "@@collation_database AS collation"
        )
        row = cur.fetchone()
        assert row is not None
    version = str(row["v"])
    comment = str(row["comment"] or "")
    mode = str(row["mode"] or "")
    charset = str(row["charset"] or "")
    collation = str(row["collation"] or "")

    blob = f"{version} {comment}".lower()
    if "mariadb" in blob:
        raise InvalidState(f"MariaDB is not supported; need MySQL 8.0.16+ (got {version})")

    m = re.search(r"(\d+)\.(\d+)\.(\d+)", version)
    if not m:
        raise InvalidState(f"unparseable MySQL VERSION(): {version}")
    major, minor, patch = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
    if (major, minor, patch) < (8, 0, 16):
        raise InvalidState(f"MySQL >= 8.0.16 required (got {version})")

    if "STRICT_TRANS_TABLES" not in mode:
        raise InvalidState(f"STRICT_TRANS_TABLES required in sql_mode (got {mode})")

    if charset.lower() != "utf8mb4" or collation.lower() != "utf8mb4_0900_ai_ci":
        log.warning(
            "database charset/collation is %s/%s; expected utf8mb4/utf8mb4_0900_ai_ci",
            charset,
            collation,
        )
    return version


def household_today() -> date:
    tz = os.environ.get("HOUSEHOLD_TZ") or "America/New_York"
    return datetime.now(ZoneInfo(tz)).date()


def utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def default_actor(actor: str | None) -> str:
    return actor or os.environ.get("MYSQL_ACTOR") or "grok"


@contextmanager
def tx(conn: Connection) -> Iterator[Connection]:
    conn.rollback()
    conn.begin()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise


def code_id(conn: Connection, table: str, code: str) -> int:
    if table not in LOOKUP_TABLES:
        raise ValueError(f"table not allowlisted for code_id: {table}")
    key = (table, code)
    cached = _CODE_ID_CACHE.get(key)
    if cached is not None:
        return cached
    with conn.cursor() as cur:
        cur.execute(f"SELECT id FROM `{table}` WHERE code=%s", (code,))
        row = cur.fetchone()
    if not row:
        raise InvalidState(f"unknown {table} code {code!r}")
    _CODE_ID_CACHE[key] = int(row["id"])
    return _CODE_ID_CACHE[key]


def _schema_path(name: str) -> Path:
    path = _SCHEMA_DIR / name
    if not path.is_file():
        raise InvalidState(f"missing schema file {path}")
    return path


def _split_sql(sql: str) -> list[str]:
    """Split a file into statements. Shared hosts often disable MULTI_STATEMENTS."""
    stmts: list[str] = []
    buf: list[str] = []
    i = 0
    n = len(sql)
    in_s = in_d = in_line = in_block = False
    while i < n:
        c = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""
        if in_line:
            if c == "\n":
                in_line = False
            i += 1
            continue
        if in_block:
            if c == "*" and nxt == "/":
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_s:
            buf.append(c)
            if c == "\\" and nxt:
                buf.append(nxt)
                i += 2
                continue
            if c == "'":
                in_s = False
            i += 1
            continue
        if in_d:
            buf.append(c)
            if c == '"':
                in_d = False
            i += 1
            continue
        if c == "-" and nxt == "-":
            in_line = True
            i += 2
            continue
        if c == "#" and not buf:
            in_line = True
            i += 1
            continue
        if c == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        if c == "'":
            in_s = True
            buf.append(c)
            i += 1
            continue
        if c == '"':
            in_d = True
            buf.append(c)
            i += 1
            continue
        if c == ";":
            stmt = "".join(buf).strip()
            if stmt:
                stmts.append(stmt)
            buf = []
            i += 1
            continue
        buf.append(c)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        stmts.append(tail)
    return stmts


def _database_name(conn: Connection) -> str:
    db = conn.db
    if isinstance(db, bytes):
        return db.decode()
    if db:
        return str(db)
    with conn.cursor() as cur:
        cur.execute("SELECT DATABASE() AS d")
        row = cur.fetchone()
    return str(row["d"]) if row else ""


def _existing_v1_tables(conn: Connection) -> set[str]:
    db = _database_name(conn)
    names = sorted(V1_TABLES)
    placeholders = ",".join(["%s"] * len(names))
    with conn.cursor() as cur:
        cur.execute(
            f"SELECT TABLE_NAME AS n FROM information_schema.TABLES "
            f"WHERE TABLE_SCHEMA=%s AND TABLE_NAME IN ({placeholders})",
            (db, *names),
        )
        return {str(r["n"]) for r in cur.fetchall()}


def _applied_files(conn: Connection, existing: set[str]) -> set[str]:
    if "schema_migrations" not in existing:
        return set()
    with conn.cursor() as cur:
        cur.execute("SELECT filename FROM schema_migrations")
        return {str(r["filename"]) for r in cur.fetchall()}


def _run_sql_file(conn: Connection, path: Path) -> None:
    sql = path.read_text(encoding="utf-8")
    with conn.cursor() as cur:
        for stmt in _split_sql(sql):
            cur.execute(stmt)


def migrate_apply(conn: Connection) -> None:
    existing = _existing_v1_tables(conn)
    applied = _applied_files(conn, existing)
    for name in FORWARD_SQL:
        if name in applied:
            continue
        if name == "001_init.sql" and existing:
            raise InvalidState(
                "half-applied schema: v1 tables exist but 001_init.sql is not in "
                "schema_migrations. Run schema/reset.sql by hand, then retry migrate."
            )
        _run_sql_file(conn, _schema_path(name))
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO schema_migrations (filename) VALUES (%s)",
                (name,),
            )
        conn.commit()
        log.info("applied %s", name)
        existing = _existing_v1_tables(conn)
        applied = _applied_files(conn, existing)
