#!/usr/bin/env python3
"""Probe MySQL: version, sql_mode, grants, TLS. Never prints the password."""

from __future__ import annotations

import sys
from pathlib import Path

# Allow running without an editable install.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

import pymysql  # noqa: E402

from kitchen_inventory.db import assert_server, connect  # noqa: E402


def main() -> int:
    try:
        conn = connect(autocommit=True)
    except RuntimeError as e:
        print(f"config: {e}", file=sys.stderr)
        return 2
    except pymysql.err.OperationalError as e:
        errno = e.args[0] if e.args else None
        print(f"connect failed: {e}", file=sys.stderr)
        if errno == 1045:
            print(
                "1045 usually means wrong password OR this client host is not "
                "in the MySQL user's allowable hosts. phpMyAdmin on the server "
                "can succeed while a laptop or Grok session cannot. Allow '%' "
                "(typical; depends on who hosts the DB) so clients are not "
                "tied to one IP.",
                file=sys.stderr,
            )
        return 1

    try:
        version = assert_server(conn)
    except Exception as e:
        print(f"assert_server failed: {e}", file=sys.stderr)
        conn.close()
        return 1

    print(f"version: {version}")
    with conn.cursor() as cur:
        cur.execute(
            "SELECT DATABASE() AS db, CURRENT_USER() AS current_user, "
            "@@sql_mode AS sql_mode, @@character_set_database AS charset, "
            "@@collation_database AS collation, @@have_ssl AS have_ssl, "
            "@@require_secure_transport AS require_ssl"
        )
        row = cur.fetchone()
        assert row is not None
        for k, v in row.items():
            print(f"{k}: {v}")

        cur.execute("SHOW STATUS LIKE 'Ssl_cipher'")
        ssl_row = cur.fetchone()
        print(f"ssl_cipher: {(ssl_row or {}).get('Value') or '(none)'}")

        cur.execute("SHOW GRANTS")
        for g in cur.fetchall():
            print(f"grant: {list(g.values())[0]}")

        existing = set()
        cur.execute("SHOW TABLES")
        for t in cur.fetchall():
            existing.add(list(t.values())[0])
        print(f"tables: {sorted(existing) or '(none)'}")

        for lookup in ("unit", "location", "dimension"):
            if lookup in existing:
                cur.execute(f"SELECT COUNT(*) AS n FROM `{lookup}`")
                n = cur.fetchone()["n"]
                print(f"{lookup}_count: {n}")
            else:
                print(f"{lookup}_count: (not migrated)")

        cur.execute(
            "SELECT filename FROM schema_migrations ORDER BY filename"
        ) if "schema_migrations" in existing else None
        if "schema_migrations" in existing:
            files = [r["filename"] for r in cur.fetchall()]
            print(f"migrations: {files or '(none)'}")
        else:
            print("migrations: (schema_migrations missing)")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
