#!/usr/bin/env python3
"""
partsdb.py - a small parts manager for an Altium DbLib backed by SQLite.

Runs on Windows, macOS and Linux. Only needs the Python standard library
(tkinter + sqlite3). Point Altium's DbLib at the same .db file over the
SQLite ODBC driver; this app maintains the views that Altium reads.

Symbol and footprint libraries sitting beside this file are picked up on
startup, so the library fields offer the real component names, and the ten
symbols and footprints you used last stay at the top of those lists.

    python3 partsdb.py [path/to/parts.db]
    python3 partsdb.py --libs          # list the libraries found, no GUI
    python3 partsdb.py --selftest      # no GUI, checks the db/parse logic
"""

import os
import re
import sqlite3
import struct
import sys
from datetime import date
from pathlib import Path

APP_NAME = "Parts"
CONFIG = Path.home() / ".partsdb_path"
SCRIPT_DIR = Path(__file__).resolve().parent
RECENT_LIMIT = 10
MUTED = "#555"
WARN = "#a00"


# --------------------------------------------------------------------------
# value parsing
# --------------------------------------------------------------------------

MULTIPLIERS = {
    "ohms": {"r": 1, "k": 1e3, "m": 1e6, "meg": 1e6, "g": 1e9},
    "farads": {"p": 1e-12, "n": 1e-9, "u": 1e-6, "\u00b5": 1e-6, "m": 1e-3, "f": 1},
    "henries": {"p": 1e-12, "n": 1e-9, "u": 1e-6, "\u00b5": 1e-6, "m": 1e-3, "h": 1},
}

UNIT_SUFFIX = {
    "ohms": ("ohms", "ohm", "\u03c9"),
    "farads": ("farads", "farad", "f"),
    "henries": ("henries", "henry", "h"),
}

UNIT_SYMBOL = {"ohms": "\u03a9", "farads": "F", "henries": "H"}


def parse_value(text, kind):
    """'4k7' / '10k' / '100nF' / '0.1u' -> float in base units. None if unparseable.

    Note for ohms: a bare number is ohms, and 'M' means mega. For farads and
    henries a bare number is taken as base units, which is almost never what
    you meant - the readout beside the field is there so you notice.
    """
    if text is None:
        return None
    s = str(text).strip().lower().replace(" ", "")
    if not s:
        return None
    mult = MULTIPLIERS[kind]

    # strip a trailing unit word: 10ohm -> 10, 100nF -> 100n, 10uH -> 10u.
    # 'R' is left alone for ohms because the multiplier table covers it,
    # which keeps '10R' and '1R2' working.
    for suf in sorted(UNIT_SUFFIX[kind], key=len, reverse=True):
        if s.endswith(suf) and len(s) > len(suf):
            s = s[:-len(suf)]
            break

    # RKM code: 4k7, 1r2, 1u5, 2n2
    m = re.fullmatch(r"(\d+)([a-z\u00b5]+)(\d+)", s)
    if m and m.group(2) in mult:
        return float(f"{m.group(1)}.{m.group(3)}") * mult[m.group(2)]

    # 10k, 4.7u, 100n, 220
    m = re.fullmatch(r"(\d*\.?\d+)([a-z\u00b5]*)", s)
    if not m:
        return None
    num = float(m.group(1))
    suf = m.group(2)
    if not suf:
        return num
    if suf in mult:
        return num * mult[suf]
    return None


def format_value(v, kind):
    """1e-7, 'farads' -> '100 nF'"""
    if v is None:
        return ""
    unit = UNIT_SYMBOL[kind]
    if v == 0:
        return f"0 {unit}"
    for exp, prefix in ((9, "G"), (6, "M"), (3, "k"), (0, ""),
                        (-3, "m"), (-6, "\u00b5"), (-9, "n"), (-12, "p")):
        if abs(v) >= 10 ** exp or exp == -12:
            return f"{v / 10 ** exp:g} {prefix}{unit}"
    return f"{v:g} {unit}"


# --------------------------------------------------------------------------
# altium library discovery
# --------------------------------------------------------------------------

LIB_KINDS = {
    "symbol": (".schlib", "library_ref", "library_path"),
    "footprint": (".pcblib", "footprint_ref", "footprint_path"),
}

REF_KIND = {ref: kind for kind, (_, ref, _) in LIB_KINDS.items()}
PATH_KIND = {path: kind for kind, (_, _, path) in LIB_KINDS.items()}
LIB_FIELDS = set(REF_KIND) | set(PATH_KIND)

SKIP_DIRS = {"history", "__pycache__", "project outputs"}
RESERVED_STORAGES = {"fileheader", "filerecordheader", "fileversioninfo",
                     "sectionkeys", "storage", "library", "additional",
                     "root entry"}

CFB_SIGNATURE = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"
CFB_MAXREGSECT = 0xFFFFFFFA


class CompoundFile:
    """Reader for the OLE container an Altium library is stored in."""

    def __init__(self, path):
        self.raw = Path(path).read_bytes()
        if self.raw[:8] != CFB_SIGNATURE:
            raise ValueError("not a compound file")
        self.ssize = 1 << struct.unpack_from("<H", self.raw, 30)[0]
        self.msize = 1 << struct.unpack_from("<H", self.raw, 32)[0]
        self.cutoff = struct.unpack_from("<I", self.raw, 56)[0]
        fat_count, dir_start = struct.unpack_from("<II", self.raw, 44)
        mini_start, mini_count = struct.unpack_from("<II", self.raw, 60)
        difat_start, difat_count = struct.unpack_from("<II", self.raw, 68)
        difat = list(struct.unpack_from("<109I", self.raw, 76))
        sector = difat_start
        for _ in range(difat_count):
            block = self._sector(sector)
            if len(block) < self.ssize:
                break
            difat += struct.unpack_from("<%dI" % (self.ssize // 4 - 1), block)
            sector = struct.unpack_from("<I", block, self.ssize - 4)[0]
        self.fat = []
        for sector in difat[:fat_count]:
            block = self._sector(sector)
            if len(block) < self.ssize:
                break
            self.fat += struct.unpack_from("<%dI" % (self.ssize // 4), block)
        self.entries = self._directory(dir_start)
        self.minifat = []
        if mini_count:
            block = self._chain(mini_start)
            self.minifat = list(
                struct.unpack_from("<%dI" % (len(block) // 4), block))
        self.ministream = (self._chain(self.entries[0][5])
                           if self.entries else b"")

    def _sector(self, index):
        if index >= CFB_MAXREGSECT:
            return b""
        start = 512 + index * self.ssize
        return self.raw[start:start + self.ssize]

    def _chain(self, start):
        out, seen, index = [], set(), start
        while (index < CFB_MAXREGSECT and index < len(self.fat)
               and index not in seen):
            seen.add(index)
            out.append(self._sector(index))
            index = self.fat[index]
        return b"".join(out)

    def _mini_chain(self, start, size):
        out, seen, index = [], set(), start
        while (index < CFB_MAXREGSECT and index < len(self.minifat)
               and index not in seen):
            seen.add(index)
            out.append(
                self.ministream[index * self.msize:(index + 1) * self.msize])
            index = self.minifat[index]
        return b"".join(out)[:size]

    def _directory(self, start):
        data = self._chain(start)
        out = []
        for i in range(len(data) // 128):
            at = i * 128
            length = min(struct.unpack_from("<H", data, at + 64)[0], 64)
            name = data[at:at + max(0, length - 2)].decode("utf-16-le",
                                                           "replace")
            left, right, child = struct.unpack_from("<III", data, at + 68)
            sector, size = struct.unpack_from("<IQ", data, at + 116)
            out.append((name, data[at + 66], left, right, child, sector, size))
        return out

    def children(self, index=0):
        if index >= len(self.entries):
            return []
        out, stack = [], [self.entries[index][4]]
        while stack:
            i = stack.pop()
            if i >= len(self.entries):
                continue
            entry = self.entries[i]
            out.append((i, entry))
            stack += [entry[2], entry[3]]
        return out

    def find(self, *names):
        index = 0
        for name in names:
            for i, entry in self.children(index):
                if entry[0].lower() == name.lower():
                    index = i
                    break
            else:
                return None
        return index

    def read(self, *names):
        index = self.find(*names)
        if index is None:
            return b""
        sector, size = self.entries[index][5], self.entries[index][6]
        if size < self.cutoff:
            return self._mini_chain(sector, size)
        return self._chain(sector)[:size]


def _dedupe(names):
    out, seen = [], set()
    for name in names:
        name = (name or "").strip().strip("\x00")
        if name and name.lower() not in seen:
            seen.add(name.lower())
            out.append(name)
    return out


def library_names(path, kind):
    """Every component name in a .SchLib or .PcbLib. [] if unreadable.

    Read from the library index rather than the container's own directory,
    because the container truncates a name at 31 characters and a truncated
    footprint reference would not resolve in Altium.
    """
    try:
        cfb = CompoundFile(path)
        if kind == "symbol":
            text = cfb.read("FileHeader").decode("latin-1")
            names = re.findall(r"\|LibRef\d+=([^|\x00]*)", text)
        else:
            text = cfb.read("Library", "ComponentParamsTOC",
                            "Data").decode("latin-1")
            names = []
            for record in text.split("\r\n"):
                head, found, rest = record.partition("Name=")
                if found and len(head) <= 8:
                    names.append(rest.split("|")[0])
        if not names:
            names = [entry[0] for _, entry in cfb.children()
                     if entry[1] == 1
                     and entry[0].lower() not in RESERVED_STORAGES]
    except Exception:
        return []
    return sorted(_dedupe(names), key=str.lower)


def scan_libraries(base=None):
    """{'symbol': {relative path: [names]}, 'footprint': {...}}"""
    base = Path(base) if base else SCRIPT_DIR
    found = {kind: {} for kind in LIB_KINDS}
    if not base.is_dir():
        return found
    for root, dirs, files in os.walk(str(base)):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".")
                         and d.lower() not in SKIP_DIRS)
        for name in sorted(files):
            suffix = Path(name).suffix.lower()
            for kind, (ext, _, _) in LIB_KINDS.items():
                if suffix == ext:
                    full = Path(root) / name
                    found[kind][str(full.relative_to(base))] = library_names(
                        full, kind)
    return found


def _norm(path):
    return str(path or "").strip().replace("/", "\\").lower()


def match_library(libs, path):
    """The scanned library a stored path points at, or ''.

    Falls back to the file name, so a path written relative to somewhere
    else - the way Altium usually stores it - still resolves.
    """
    want = _norm(path)
    if not want:
        return ""
    for rel in libs:
        if _norm(rel) == want:
            return rel
    tail = want.rsplit("\\", 1)[-1]
    for rel in libs:
        if _norm(rel).rsplit("\\", 1)[-1] == tail:
            return rel
    return ""


def find_library(libs, ref):
    """The scanned library holding a component, or ''."""
    want = (ref or "").strip().lower()
    if not want:
        return ""
    for rel, names in libs.items():
        if any(name.lower() == want for name in names):
            return rel
    return ""


def lib_status(libs, ref, path):
    """('ok' | 'missing' | 'elsewhere' | '', library file name)"""
    ref = (ref or "").strip()
    if not ref or not libs:
        return "", ""
    rel = match_library(libs, path)
    if rel and libs[rel]:
        if any(name.lower() == ref.lower() for name in libs[rel]):
            return "ok", Path(rel).name
        return "missing", Path(rel).name
    if not rel:
        home = find_library(libs, ref)
        if home:
            return "elsewhere", Path(home).name
    return "", Path(rel).name if rel else ""


# --------------------------------------------------------------------------
# part type definitions - the UI and the schema are both built from these
# --------------------------------------------------------------------------

def _d(row, key):
    return (row.get(key) or "").strip()


TYPES = {
    "Resistors": {
        "prefix": "RES",
        "table": "res_ext",
        "designator": "R?",
        # column, label, kind, numeric column
        "primary": ("resistance", "Resistance", "ohms", "resistance_ohms"),
        "fields": [
            ("tolerance", "Tolerance", ["1%", "5%", "0.1%", "0.5%", "2%", "10%"]),
            ("power_rating", "Power", ["0.125W", "0.25W", "0.5W", "1W", "2W", "3W", "5W"]),
            ("composition", "Composition", ["Metal Film", "Carbon Film",
                                            "Metal Oxide", "Wirewound",
                                            "Carbon Composition", "Cement"]),
        ],
        "describe": lambda r: " ".join(x for x in [
            "RES", _d(r, "resistance"), _d(r, "tolerance"),
            _d(r, "power_rating"), _d(r, "composition")] if x),
        "list": [("value", "Value", 90), ("tolerance", "Tol", 55),
                 ("power_rating", "Power", 65), ("mpn", "MPN", 170),
                 ("status", "Status", 70)],
    },
    "Capacitors": {
        "prefix": "CAP",
        "table": "cap_ext",
        "designator": "C?",
        "primary": ("capacitance", "Capacitance", "farads", "capacitance_farads"),
        "fields": [
            ("tolerance", "Tolerance", ["5%", "10%", "20%", "1%", "-20/+80%"]),
            ("voltage_rating", "Voltage", ["16V", "25V", "50V", "63V", "100V",
                                           "200V", "250V", "400V", "630V"]),
            ("dielectric", "Dielectric", ["C0G/NP0", "X7R", "X5R", "Y5V",
                                          "Aluminum Electrolytic", "Tantalum",
                                          "Polypropylene", "Polyester", "Mica"]),
            ("polarized", "Polarized", ["No", "Yes"]),
        ],
        "describe": lambda r: " ".join(x for x in [
            "CAP", _d(r, "capacitance"), _d(r, "tolerance"),
            _d(r, "voltage_rating"), _d(r, "dielectric")] if x),
        "list": [("value", "Value", 90), ("voltage_rating", "V", 55),
                 ("dielectric", "Dielectric", 110), ("mpn", "MPN", 170),
                 ("status", "Status", 70)],
    },
    "Diodes": {
        "prefix": "DIO",
        "table": "dio_ext",
        "designator": "D?",
        "primary": None,          # value falls back to the MPN
        "fields": [
            ("diode_type", "Type", ["Rectifier", "Schottky", "Zener",
                                    "Switching", "TVS", "Bridge", "LED"]),
            ("vrrm", "Reverse voltage", None),
            ("if_max", "Forward current", None),
            ("vf", "Forward voltage", None),
            ("zener_voltage", "Zener voltage", None),
            ("power_dissipation", "Power", None),
        ],
        "describe": lambda r: " ".join(x for x in [
            "DIODE", _d(r, "diode_type"),
            _d(r, "zener_voltage") or _d(r, "vrrm"), _d(r, "if_max")] if x),
        "list": [("diode_type", "Type", 90), ("vrrm", "VR", 60),
                 ("if_max", "IF", 60), ("mpn", "MPN", 170),
                 ("status", "Status", 70)],
    },
    "Inductors": {
        "prefix": "IND",
        "table": "ind_ext",
        "designator": "L?",
        "primary": ("inductance", "Inductance", "henries", "inductance_henries"),
        "fields": [
            ("tolerance", "Tolerance", ["5%", "10%", "20%", "1%", "2%"]),
            ("current_rating", "Current", None),
            ("dcr", "DCR", None),
            ("core_material", "Core", ["Ferrite", "Iron Powder", "Iron Alloy",
                                       "Air Core", "Phenolic"]),
            ("shielding", "Shielding", ["Unshielded", "Shielded"]),
        ],
        "describe": lambda r: " ".join(x for x in [
            "IND", _d(r, "inductance"), _d(r, "tolerance"),
            _d(r, "current_rating"), _d(r, "core_material")] if x),
        "list": [("value", "Value", 90), ("current_rating", "I", 60),
                 ("dcr", "DCR", 70), ("mpn", "MPN", 170),
                 ("status", "Status", 70)],
    },
}

# fields every part has, beyond the auto-managed ones
COMMON_FIELDS = [
    ("library_path", "Symbol library", None),
    ("library_ref", "Symbol", None),
    ("footprint_path", "Footprint library", None),
    ("footprint_ref", "Footprint", None),
    ("mfr", "Manufacturer", None),
    ("mpn", "Manufacturer PN", None),
    ("supplier", "Supplier", ["Digi-Key", "Mouser", "LCSC", "Arrow", "Newark", ""]),
    ("spn", "Supplier PN", None),
    ("datasheet_url", "Datasheet URL", None),
    ("status", "Status", ["Active", "NRND", "Obsolete", "Do Not Use"]),
    ("notes", "Notes", None),
]

PARTS_COLS = ["part_number", "part_type", "library_ref", "library_path",
              "footprint_ref", "footprint_path", "designator", "description",
              "value", "mfr", "mpn", "supplier", "spn", "datasheet_url",
              "status", "date_added", "notes"]

# fields carried over to the next new part of the same type
STICKY = ["library_ref", "library_path", "footprint_ref", "footprint_path",
          "mfr", "supplier", "status", "tolerance", "power_rating",
          "composition", "dielectric", "voltage_rating", "polarized",
          "core_material", "shielding", "diode_type"]


# --------------------------------------------------------------------------
# database
# --------------------------------------------------------------------------

EXT_SCHEMA = {
    "res_ext": """resistance TEXT, resistance_ohms REAL, tolerance TEXT,
                  power_rating TEXT, composition TEXT""",
    "cap_ext": """capacitance TEXT, capacitance_farads REAL, tolerance TEXT,
                  voltage_rating TEXT, dielectric TEXT, polarized TEXT""",
    "dio_ext": """diode_type TEXT, vrrm TEXT, if_max TEXT, vf TEXT,
                  zener_voltage TEXT, power_dissipation TEXT""",
    "ind_ext": """inductance TEXT, inductance_henries REAL, tolerance TEXT,
                  current_rating TEXT, dcr TEXT, core_material TEXT,
                  shielding TEXT""",
}

# Altium parameter name for each extension column
VIEW_LABELS = {
    "resistance": "Resistance", "tolerance": "Tolerance",
    "power_rating": "Power Rating", "composition": "Composition",
    "capacitance": "Capacitance", "voltage_rating": "Voltage Rating",
    "dielectric": "Dielectric", "polarized": "Polarized",
    "diode_type": "Diode Type", "vrrm": "Reverse Voltage",
    "if_max": "Forward Current", "vf": "Forward Voltage",
    "zener_voltage": "Zener Voltage", "power_dissipation": "Power Dissipation",
    "inductance": "Inductance", "current_rating": "Current Rating",
    "dcr": "DCR", "core_material": "Core Material", "shielding": "Shielding",
}


def connect(path):
    con = sqlite3.connect(path)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys = ON")
    build_schema(con)
    return con


def build_schema(con):
    con.executescript("""
        CREATE TABLE IF NOT EXISTS parts (
          part_number    TEXT PRIMARY KEY COLLATE NOCASE,
          part_type      TEXT NOT NULL,
          library_ref    TEXT,
          library_path   TEXT,
          footprint_ref  TEXT,
          footprint_path TEXT,
          designator     TEXT,
          description    TEXT,
          value          TEXT,
          mfr            TEXT,
          mpn            TEXT,
          supplier       TEXT,
          spn            TEXT,
          datasheet_url  TEXT,
          status         TEXT NOT NULL DEFAULT 'Active',
          date_added     TEXT NOT NULL DEFAULT (date('now')),
          notes          TEXT
        );
        CREATE TABLE IF NOT EXISTS counters (
          prefix TEXT PRIMARY KEY,
          last   INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS recent (
          kind    TEXT NOT NULL,
          ref     TEXT NOT NULL COLLATE NOCASE,
          path    TEXT NOT NULL COLLATE NOCASE,
          seq     INTEGER NOT NULL,
          used_at TEXT NOT NULL,
          PRIMARY KEY (kind, ref, path)
        );
    """)
    for table, cols in EXT_SCHEMA.items():
        con.execute(f"""CREATE TABLE IF NOT EXISTS {table} (
            part_number TEXT PRIMARY KEY
              REFERENCES parts(part_number) ON DELETE CASCADE ON UPDATE CASCADE,
            {cols});""")
    rebuild_views(con)
    seed_recent(con)
    con.commit()


def seed_recent(con):
    """Prime an empty recently used list from the parts already on file."""
    if con.execute("SELECT 1 FROM recent LIMIT 1").fetchone():
        return
    for kind, (_, ref_col, path_col) in LIB_KINDS.items():
        for row in con.execute(
                f"SELECT {ref_col} AS ref, {path_col} AS path FROM parts "
                f"WHERE IFNULL({ref_col}, '') <> '' "
                "ORDER BY date_added, rowid").fetchall():
            touch_recent(con, kind, row["ref"], row["path"])


def rebuild_views(con):
    """Dropped and recreated every launch so schema edits propagate."""
    for name, spec in TYPES.items():
        ext_cols = [c.split()[0] for c in
                    EXT_SCHEMA[spec["table"]].replace("\n", " ").split(",")]
        ext_cols = [c.strip() for c in ext_cols if c.strip()
                    and not c.strip().endswith("_ohms")
                    and not c.strip().endswith("_farads")
                    and not c.strip().endswith("_henries")]
        select = [
            'p.part_number    AS "Part Number"',
            'p.library_ref    AS "Library Ref"',
            'p.library_path   AS "Library Path"',
            'p.footprint_ref  AS "Footprint Ref"',
            'p.footprint_path AS "Footprint Path"',
            'p.designator     AS "Designator"',
            'p.description    AS "Description"',
            'p.value          AS "Value"',
            'p.mfr            AS "Manufacturer 1"',
            'p.mpn            AS "Manufacturer Part Number 1"',
            'p.supplier       AS "Supplier 1"',
            'p.spn            AS "Supplier Part Number 1"',
            "'Datasheet'      AS \"ComponentLink1Description\"",
            'p.datasheet_url  AS "ComponentLink1URL"',
            'p.status         AS "Status"',
        ]
        for c in ext_cols:
            select.append(f'x.{c} AS "{VIEW_LABELS.get(c, c)}"')
        con.execute(f'DROP VIEW IF EXISTS "{name}"')
        con.execute(f'''CREATE VIEW "{name}" AS SELECT {", ".join(select)}
                        FROM parts p JOIN {spec["table"]} x
                          ON x.part_number = p.part_number
                        WHERE p.part_type = '{name}'
                          AND p.status <> 'Do Not Use'
                        ORDER BY p.part_number;''')


def next_part_number(con, prefix):
    """Hand out the next number for a prefix and never reuse one.

    A counter row rather than MAX(part_number), because deleting the newest
    part would otherwise hand its number to the next part you create, and
    any schematic still holding the old number would silently re-link to a
    different component.
    """
    row = con.execute("SELECT last FROM counters WHERE prefix = ?",
                      (prefix,)).fetchone()
    if row is None:
        seed = con.execute(
            "SELECT MAX(CAST(substr(part_number, ?) AS INTEGER)) FROM parts "
            "WHERE part_number LIKE ?",
            (len(prefix) + 2, prefix + "-%")).fetchone()[0] or 0
        con.execute("INSERT INTO counters (prefix, last) VALUES (?, ?)",
                    (prefix, seed))
        n = seed
    else:
        n = row[0]
    while True:
        n += 1
        pn = f"{prefix}-{n:05d}"
        if not con.execute("SELECT 1 FROM parts WHERE part_number = ?",
                           (pn,)).fetchone():
            break
    con.execute("UPDATE counters SET last = ? WHERE prefix = ?", (n, prefix))
    return pn


def touch_recent(con, kind, ref, path):
    """Move a symbol or footprint to the head of its recently used list.

    Keyed case insensitively on the pair, so the same library entry never
    appears twice however it was typed.
    """
    ref = (ref or "").strip()
    if not ref:
        return
    seq = con.execute(
        "SELECT IFNULL(MAX(seq), 0) + 1 FROM recent").fetchone()[0]
    con.execute("INSERT INTO recent (kind, ref, path, seq, used_at) "
                "VALUES (?, ?, ?, ?, datetime('now')) "
                "ON CONFLICT(kind, ref, path) DO UPDATE SET "
                "seq = excluded.seq, used_at = excluded.used_at",
                (kind, ref, (path or "").strip(), seq))
    con.execute("DELETE FROM recent WHERE kind = ? AND seq NOT IN "
                "(SELECT seq FROM recent WHERE kind = ? "
                "ORDER BY seq DESC LIMIT ?)", (kind, kind, RECENT_LIMIT))


def recent_libs(con, kind):
    """[(ref, path)] for a kind, most recently used first."""
    return [(r["ref"], r["path"]) for r in con.execute(
        "SELECT ref, path FROM recent WHERE kind = ? ORDER BY seq DESC "
        "LIMIT ?", (kind, RECENT_LIMIT)).fetchall()]


def last_libraries(con, type_name):
    """The libraries the newest part of a type was built from."""
    row = con.execute(
        "SELECT library_ref, library_path, footprint_ref, footprint_path "
        "FROM parts WHERE part_type = ? ORDER BY part_number DESC LIMIT 1",
        (type_name,)).fetchone()
    return {k: (row[k] or "") for k in row.keys()} if row else {}


def save_part(con, type_name, data):
    """data: dict of every form field plus part_number ('' for a new part)."""
    spec = TYPES[type_name]
    ext_cols = [c.strip().split()[0] for c in
                EXT_SCHEMA[spec["table"]].replace("\n", " ").split(",")
                if c.strip()]

    # one transaction, so a failure can't leave a used-up part number or a
    # parts row with no matching extension row
    with con:
        pn = (data.get("part_number") or "").strip()
        if not pn:
            pn = next_part_number(con, spec["prefix"])

        row = {k: (data.get(k) or "").strip() for k in PARTS_COLS if k in data}
        row["part_number"] = pn
        row["part_type"] = type_name
        row["designator"] = spec["designator"]
        row["description"] = spec["describe"](data)

        if spec["primary"]:
            col, _, kind, numcol = spec["primary"]
            raw = (data.get(col) or "").strip()
            row["value"] = raw
            ext_numeric = {numcol: parse_value(raw, kind)}
        else:
            row["value"] = (data.get("mpn") or "").strip()
            ext_numeric = {}

        keep = con.execute("SELECT date_added FROM parts WHERE part_number = ?",
                           (pn,)).fetchone()
        row["date_added"] = keep[0] if keep else date.today().isoformat()

        ext = {c: (data.get(c) or "").strip() for c in ext_cols
               if c != "part_number" and c in data}
        ext.update(ext_numeric)
        ext["part_number"] = pn

        _upsert(con, "parts", row, skip_update=("part_number", "date_added"))
        _upsert(con, spec["table"], ext, skip_update=("part_number",))
        for kind, (_, ref_col, path_col) in LIB_KINDS.items():
            touch_recent(con, kind, row.get(ref_col), row.get(path_col))
    return pn


def _upsert(con, table, row, skip_update=()):
    """INSERT ... ON CONFLICT DO UPDATE, keyed on part_number.

    Deliberately not INSERT OR REPLACE: that deletes the old row first,
    which would fire the ON DELETE CASCADE and take the extension row
    with it.
    """
    cols = list(row)
    sets = [f"{c}=excluded.{c}" for c in cols if c not in skip_update]
    sql = (f"INSERT INTO {table} ({','.join(cols)}) "
           f"VALUES ({','.join('?' * len(cols))}) "
           f"ON CONFLICT(part_number) "
           + (f"DO UPDATE SET {', '.join(sets)}" if sets else "DO NOTHING"))
    con.execute(sql, [row[c] for c in cols])


def delete_part(con, type_name, pn):
    with con:
        con.execute(f"DELETE FROM {TYPES[type_name]['table']} "
                    "WHERE part_number = ?", (pn,))
        con.execute("DELETE FROM parts WHERE part_number = ?", (pn,))


def load_part(con, type_name, pn):
    spec = TYPES[type_name]
    row = con.execute(
        f"SELECT p.*, x.* FROM parts p LEFT JOIN {spec['table']} x "
        "ON x.part_number = p.part_number WHERE p.part_number = ?",
        (pn,)).fetchone()
    return dict(row) if row else None


def list_parts(con, type_name, search=""):
    spec = TYPES[type_name]
    cols = ["p.part_number"] + [
        ("p." if c in PARTS_COLS else "x.") + c for c, _, _ in spec["list"]]
    sql = (f"SELECT {', '.join(cols)} FROM parts p "
           f"LEFT JOIN {spec['table']} x ON x.part_number = p.part_number "
           "WHERE p.part_type = ?")
    args = [type_name]
    if search.strip():
        needle = f"%{search.strip()}%"
        sql += (" AND (p.part_number LIKE ? OR p.value LIKE ? OR p.mpn LIKE ? "
                "OR p.description LIKE ? OR p.notes LIKE ?)")
        args += [needle] * 5
    sql += " ORDER BY p.part_number"
    return con.execute(sql, args).fetchall()


def connection_string(db_path):
    p = str(Path(db_path).resolve())
    return ('Provider=MSDASQL.1;Persist Security Info=False;'
            'Extended Properties="Driver={SQLite3 ODBC Driver};'
            f'Database={p};"')


# --------------------------------------------------------------------------
# GUI
# --------------------------------------------------------------------------

def run_gui(db_path):
    import tkinter as tk
    from tkinter import ttk, filedialog, messagebox

    class ScrollFrame(ttk.Frame):
        """A frame whose contents scroll vertically."""

        def __init__(self, master):
            super().__init__(master)
            self.canvas = tk.Canvas(self, highlightthickness=0, width=380)
            bar = ttk.Scrollbar(self, orient="vertical",
                                command=self.canvas.yview)
            self.inner = ttk.Frame(self.canvas)
            self.win = self.canvas.create_window((0, 0), window=self.inner,
                                                 anchor="nw")
            self.canvas.configure(yscrollcommand=bar.set)
            self.canvas.pack(side="left", fill="both", expand=True)
            bar.pack(side="right", fill="y")
            self.inner.bind("<Configure>", lambda e: self.canvas.configure(
                scrollregion=self.canvas.bbox("all")))
            self.canvas.bind("<Configure>", lambda e: self.canvas.itemconfig(
                self.win, width=e.width))
            for seq in ("<MouseWheel>", "<Button-4>", "<Button-5>"):
                self.canvas.bind_all(seq, self._wheel, add="+")

        def _wheel(self, event):
            if not self._over_canvas(event):
                return
            if event.num == 4:
                self.canvas.yview_scroll(-1, "units")
            elif event.num == 5:
                self.canvas.yview_scroll(1, "units")
            else:
                self.canvas.yview_scroll(
                    -1 if event.delta > 0 else 1, "units")

        def _over_canvas(self, event):
            """Is the pointer over this frame, rather than an open list?

            Asks Tcl for the window path instead of going through
            winfo_containing, which raises on a combobox popdown: that
            window belongs to Tk alone and has no Python widget to hand
            back. A popdown is its own toplevel and is nested under the
            combobox that owns it, so the toplevel is what tells the two
            apart - and while one is open it scrolls itself.
            """
            under = self.canvas.tk.call(
                "winfo", "containing", event.x_root, event.y_root)
            if not under:
                return False
            if self.canvas.tk.call("winfo", "toplevel", under) != str(
                    self.winfo_toplevel()):
                return False
            mine = str(self.canvas)
            return under == mine or under.startswith(mine + ".")

    class PartPanel(ttk.Frame):
        def __init__(self, master, app, type_name):
            super().__init__(master, padding=8)
            self.app = app
            self.type_name = type_name
            self.spec = TYPES[type_name]
            self.vars = {}
            self.widgets = {}
            self.notes = {}
            self.current = None
            self.last_saved = {}

            self.columnconfigure(0, weight=1)
            self.columnconfigure(1, weight=0)
            self.rowconfigure(1, weight=1)

            # search
            bar = ttk.Frame(self)
            bar.grid(row=0, column=0, sticky="ew", pady=(0, 6))
            ttk.Label(bar, text="Search").pack(side="left")
            self.search = tk.StringVar()
            self.search.trace_add("write", lambda *_: self.refresh())
            e = ttk.Entry(bar, textvariable=self.search)
            e.pack(side="left", fill="x", expand=True, padx=6)
            self.count = ttk.Label(bar, text="")
            self.count.pack(side="left")

            # list
            listbox = ttk.Frame(self)
            listbox.grid(row=1, column=0, sticky="nsew")
            listbox.rowconfigure(0, weight=1)
            listbox.columnconfigure(0, weight=1)
            cols = [c for c, _, _ in self.spec["list"]]
            self.tree = ttk.Treeview(listbox, columns=cols,
                                     show="tree headings", selectmode="browse")
            self.tree.heading("#0", text="Part number")
            self.tree.column("#0", width=110, stretch=False)
            for col, head, width in self.spec["list"]:
                self.tree.heading(col, text=head)
                self.tree.column(col, width=width, stretch=(col == "mpn"))
            vs = ttk.Scrollbar(listbox, orient="vertical",
                               command=self.tree.yview)
            self.tree.configure(yscrollcommand=vs.set)
            self.tree.grid(row=0, column=0, sticky="nsew")
            vs.grid(row=0, column=1, sticky="ns")
            self.tree.bind("<<TreeviewSelect>>", self.on_select)

            # form
            form = ScrollFrame(self)
            form.grid(row=0, column=1, rowspan=3, sticky="ns", padx=(10, 0))
            f = form.inner
            f.columnconfigure(1, weight=1)
            r = 0

            self.pn_label = ttk.Label(f, text="New part",
                                      font=("TkDefaultFont", 11, "bold"))
            self.pn_label.grid(row=r, column=0, columnspan=2,
                               sticky="w", pady=(0, 8))
            r += 1

            if self.spec["primary"]:
                col, label, kind, _ = self.spec["primary"]
                r = self._add_field(f, r, col, label, None)
                self.readout = ttk.Label(f, text="", foreground=MUTED)
                self.readout.grid(row=r, column=1, sticky="w", pady=(0, 4))
                r += 1
                self.vars[col].trace_add("write", self._update_readout)
                self.value_kind = kind
            else:
                self.readout = None

            for col, label, choices in self.spec["fields"]:
                r = self._add_field(f, r, col, label, choices)

            ttk.Separator(f).grid(row=r, column=0, columnspan=2,
                                  sticky="ew", pady=8)
            r += 1

            for col, label, choices in COMMON_FIELDS:
                r = self._add_field(f, r, col, label, choices)
                if col in REF_KIND:
                    note = ttk.Label(f, text="", foreground=MUTED)
                    note.grid(row=r, column=1, sticky="w", pady=(0, 4))
                    self.notes[REF_KIND[col]] = note
                    r += 1

            btns = ttk.Frame(f)
            btns.grid(row=r, column=0, columnspan=2, sticky="ew", pady=(12, 0))
            ttk.Button(btns, text="Save part",
                       command=self.save).pack(side="left")
            ttk.Button(btns, text="New",
                       command=self.new).pack(side="left", padx=4)
            ttk.Button(btns, text="Duplicate",
                       command=self.duplicate).pack(side="left")
            ttk.Button(btns, text="Delete",
                       command=self.delete).pack(side="right")

            for col in LIB_FIELDS:
                self.vars[col].trace_add(
                    "write", lambda *_, c=col: self._lib_changed(c))
            self.refresh_libraries()
            self.new()
            self.refresh()

        def _add_field(self, parent, row, col, label, choices):
            ttk.Label(parent, text=label).grid(row=row, column=0, sticky="w",
                                               padx=(0, 8), pady=2)
            var = tk.StringVar()
            self.vars[col] = var
            if col in LIB_FIELDS:
                w = ttk.Combobox(parent, textvariable=var, values=())
                w.bind("<<ComboboxSelected>>",
                       lambda e, c=col: self._lib_picked(c))
            elif choices:
                w = ttk.Combobox(parent, textvariable=var, values=choices)
            else:
                w = ttk.Entry(parent, textvariable=var)
            w.grid(row=row, column=1, sticky="ew", pady=2)
            w.bind("<Return>", lambda e: self.save())
            self.widgets[col] = w
            return row + 1

        def _update_readout(self, *_):
            col = self.spec["primary"][0]
            v = parse_value(self.vars[col].get(), self.value_kind)
            raw = self.vars[col].get().strip()
            if not raw:
                self.readout.config(text="", foreground=MUTED)
            elif v is None:
                self.readout.config(text="cannot read that value",
                                    foreground=WARN)
            else:
                self.readout.config(text="= " + format_value(v, self.value_kind),
                                    foreground=MUTED)

        # -- libraries -------------------------------------------------
        def refresh_libraries(self):
            for kind, (_, ref_col, path_col) in LIB_KINDS.items():
                libs = self.app.libraries[kind]
                paths = list(libs)
                for _, path in recent_libs(self.app.con, kind):
                    if path and not match_library(libs, path):
                        paths.append(path)
                self.widgets[path_col].configure(values=_dedupe(paths))
                self._refresh_refs(kind)
                self._update_note(kind)

        def _refresh_refs(self, kind):
            _, ref_col, path_col = LIB_KINDS[kind]
            libs = self.app.libraries[kind]
            chosen = match_library(libs, self.vars[path_col].get())
            names = [ref for ref, path in recent_libs(self.app.con, kind)
                     if not chosen or match_library(libs, path) == chosen]
            if chosen:
                names += libs[chosen]
            else:
                for pool in libs.values():
                    names += pool
            self.widgets[ref_col].configure(values=_dedupe(names))

        def _home_for(self, kind, ref):
            ref = (ref or "").strip()
            if not ref:
                return ""
            for known, path in recent_libs(self.app.con, kind):
                if path and known.lower() == ref.lower():
                    return path
            return find_library(self.app.libraries[kind], ref)

        def _lib_picked(self, col):
            kind = REF_KIND.get(col) or PATH_KIND[col]
            _, ref_col, path_col = LIB_KINDS[kind]
            if col == ref_col:
                if lib_status(self.app.libraries[kind],
                              self.vars[ref_col].get(),
                              self.vars[path_col].get())[0] != "ok":
                    home = self._home_for(kind, self.vars[ref_col].get())
                    if home:
                        self.vars[path_col].set(home)
            self._refresh_refs(kind)
            self._update_note(kind)

        def _lib_changed(self, col):
            kind = REF_KIND.get(col) or PATH_KIND[col]
            if col in PATH_KIND:
                self._refresh_refs(kind)
            self._update_note(kind)

        def _update_note(self, kind):
            note = self.notes.get(kind)
            if note is None:
                return
            _, ref_col, path_col = LIB_KINDS[kind]
            state, name = lib_status(self.app.libraries[kind],
                                     self.vars[ref_col].get(),
                                     self.vars[path_col].get())
            note.config(text={"ok": "in " + name,
                              "missing": "not in " + name,
                              "elsewhere": "found in " + name}.get(state, ""),
                        foreground=WARN if state == "missing" else MUTED)

        def _apply_lib_defaults(self):
            prior = last_libraries(self.app.con, self.type_name)
            for kind, (_, ref_col, path_col) in LIB_KINDS.items():
                if not self.vars[ref_col].get().strip():
                    self.vars[ref_col].set(prior.get(ref_col) or "")
                if not self.vars[path_col].get().strip():
                    libs = self.app.libraries[kind]
                    path = (prior.get(path_col)
                            or self._home_for(kind, self.vars[ref_col].get()))
                    if not path and len(libs) == 1:
                        path = next(iter(libs))
                    self.vars[path_col].set(path)
                self._refresh_refs(kind)
                self._update_note(kind)

        # -- data ------------------------------------------------------
        def refresh(self):
            self.tree.delete(*self.tree.get_children())
            rows = list_parts(self.app.con, self.type_name, self.search.get())
            for row in rows:
                self.tree.insert(
                    "", "end", iid=row["part_number"], text=row["part_number"],
                    values=[row[c] or "" for c, _, _ in self.spec["list"]])
            n = len(rows)
            self.count.config(text=f"{n} part{'' if n == 1 else 's'}")

        def on_select(self, _event=None):
            sel = self.tree.selection()
            if not sel:
                return
            data = load_part(self.app.con, self.type_name, sel[0])
            if not data:
                return
            self.current = sel[0]
            for k, var in self.vars.items():
                var.set(data.get(k) or "")
            self.pn_label.config(text=self.current)

        def new(self):
            self.current = None
            self.tree.selection_remove(self.tree.selection())
            for k, var in self.vars.items():
                var.set(self.last_saved.get(k, "") if k in STICKY else "")
            self._apply_lib_defaults()
            if not self.vars["status"].get():
                self.vars["status"].set("Active")
            self.pn_label.config(text="New part")

        def duplicate(self):
            self.current = None
            self.tree.selection_remove(self.tree.selection())
            self.pn_label.config(text="New part (copy)")

        def save(self):
            data = {k: v.get() for k, v in self.vars.items()}
            data["part_number"] = self.current or ""

            if self.spec["primary"]:
                col, label, kind, _ = self.spec["primary"]
                if not data.get(col, "").strip():
                    messagebox.showwarning(
                        APP_NAME, f"{label} is needed to save this part.")
                    return
                if parse_value(data[col], kind) is None:
                    if not messagebox.askyesno(
                            APP_NAME,
                            f"{label} '{data[col]}' can't be read as a number, "
                            "so this part won't sort correctly in Altium.\n\n"
                            "Save it anyway?"):
                        return
            elif not data.get("mpn", "").strip():
                messagebox.showwarning(
                    APP_NAME, "Manufacturer PN is needed to save this part.")
                return

            for kind, (_, ref_col, path_col) in LIB_KINDS.items():
                state, name = lib_status(self.app.libraries[kind],
                                         data.get(ref_col), data.get(path_col))
                if state == "missing" and not messagebox.askyesno(
                        APP_NAME,
                        f"'{data[ref_col].strip()}' is not in {name}, so "
                        "Altium will not be able to place this part.\n\n"
                        "Save it anyway?"):
                    return

            pn = save_part(self.app.con, self.type_name, data)
            self.last_saved = dict(data)
            self.app.refresh_recents()
            self.refresh()
            self.current = pn
            self.pn_label.config(text=pn)
            if self.tree.exists(pn):
                self.tree.selection_set(pn)
                self.tree.see(pn)
            self.app.status(f"Saved {pn}")

        def delete(self):
            if not self.current:
                return
            if not messagebox.askyesno(
                    APP_NAME,
                    f"Delete {self.current}?\n\nAny schematic already using "
                    "it will lose its database link."):
                return
            gone = self.current
            delete_part(self.app.con, self.type_name, gone)
            self.new()
            self.refresh()
            self.app.status(f"Deleted {gone}")

    class App(tk.Tk):
        def __init__(self, path):
            super().__init__()
            self.title(f"{APP_NAME} - {path}")
            self.geometry("1080x640")
            self.minsize(900, 500)
            self.db_path = path
            self.con = connect(path)
            self.libraries = scan_libraries()

            style = ttk.Style(self)
            if sys.platform.startswith("linux") and "clam" in style.theme_names():
                style.theme_use("clam")
            style.configure("Treeview", rowheight=22)

            menu = tk.Menu(self)
            filemenu = tk.Menu(menu, tearoff=0)
            filemenu.add_command(label="Open database...", command=self.open_db)
            filemenu.add_command(label="Rescan libraries", accelerator="F5",
                                 command=self.rescan)
            filemenu.add_command(label="Copy Altium connection string",
                                 command=self.copy_conn)
            filemenu.add_separator()
            filemenu.add_command(label="Quit", command=self.destroy)
            menu.add_cascade(label="File", menu=filemenu)
            self.config(menu=menu)

            self.nb = ttk.Notebook(self)
            self.nb.pack(fill="both", expand=True)
            self.panels = {}
            for name in TYPES:
                p = PartPanel(self.nb, self, name)
                self.nb.add(p, text=name)
                self.panels[name] = p

            self.statusbar = ttk.Label(self, anchor="w", padding=(8, 3),
                                       relief="sunken")
            self.statusbar.pack(fill="x")
            self.bind("<F5>", lambda e: self.rescan())
            self.status(f"{Path(path).name} ready - {self.library_summary()}")

        def status(self, text):
            self.statusbar.config(text=text)

        def library_summary(self):
            files = sum(len(libs) for libs in self.libraries.values())
            items = sum(len(names) for libs in self.libraries.values()
                        for names in libs.values())
            if not files:
                return f"no libraries found in {SCRIPT_DIR.name}"
            return (f"{files} librar{'y' if files == 1 else 'ies'}, "
                    f"{items} entr{'y' if items == 1 else 'ies'}")

        def rescan(self):
            self.libraries = scan_libraries()
            self.refresh_recents()
            self.status(f"Rescanned - {self.library_summary()}")

        def refresh_recents(self):
            for panel in self.panels.values():
                panel.refresh_libraries()

        def copy_conn(self):
            self.clipboard_clear()
            self.clipboard_append(connection_string(self.db_path))
            self.status("Connection string copied to the clipboard")

        def open_db(self):
            path = filedialog.asksaveasfilename(
                title="Open or create a parts database",
                defaultextension=".db",
                filetypes=[("SQLite database", "*.db"), ("All files", "*.*")],
                confirmoverwrite=False)
            if not path:
                return
            CONFIG.write_text(path)
            messagebox.showinfo(
                APP_NAME, "Restart the app to use this database.")

    App(db_path).mainloop()


# --------------------------------------------------------------------------

def selftest():
    cases = [
        ("10k", "ohms", 10_000), ("4k7", "ohms", 4700), ("220", "ohms", 220),
        ("1M", "ohms", 1e6), ("1R2", "ohms", 1.2), ("4.7k", "ohms", 4700),
        ("10 kohm", "ohms", 10_000),
        ("100nF", "farads", 1e-7), ("4u7", "farads", 4.7e-6),
        ("0.1uF", "farads", 1e-7), ("2n2", "farads", 2.2e-9),
        ("10uH", "henries", 1e-5), ("1mH", "henries", 1e-3),
        ("banana", "ohms", None), ("", "ohms", None),
    ]
    for text, kind, want in cases:
        got = parse_value(text, kind)
        ok = (got is None and want is None) or (
            got is not None and want is not None and abs(got - want) < want * 1e-9)
        assert ok, f"parse_value({text!r}, {kind}) = {got}, expected {want}"
    assert format_value(1e-7, "farads") == "100 nF", format_value(1e-7, "farads")
    assert format_value(10000, "ohms") == "10 k\u03a9"

    con = connect(":memory:")
    pn = save_part(con, "Resistors", {
        "part_number": "", "resistance": "10k", "tolerance": "1%",
        "power_rating": "0.25W", "composition": "Metal Film",
        "library_ref": "RES", "library_path": "Symbols\\Passives.SchLib",
        "footprint_ref": "AXIAL-0.4", "footprint_path": "Footprints\\THT.PcbLib",
        "mfr": "Vishay", "mpn": "CCF0710K0FKE36", "supplier": "Digi-Key",
        "spn": "CCF0710K0FKE36-ND", "datasheet_url": "", "status": "Active",
        "notes": ""})
    assert pn == "RES-00001", pn
    assert save_part(con, "Resistors", {"resistance": "1k"}) == "RES-00002"
    assert save_part(con, "Capacitors", {"capacitance": "100n"}) == "CAP-00001"

    row = load_part(con, "Resistors", "RES-00001")
    assert row["resistance_ohms"] == 10000
    assert row["description"] == "RES 10k 1% 0.25W Metal Film", row["description"]
    assert row["designator"] == "R?"

    save_part(con, "Resistors", {"part_number": "RES-00001", "resistance": "22k",
                                 "tolerance": "5%", "mpn": "X"})
    assert load_part(con, "Resistors", "RES-00001")["value"] == "22k"
    assert len(list_parts(con, "Resistors")) == 2
    assert len(list_parts(con, "Resistors", "22k")) == 1

    v = {r["Part Number"]: r for r in
         con.execute('SELECT * FROM "Resistors"').fetchall()}
    assert len(v) == 2 and "Part Number" in list(v.values())[0].keys()
    assert v["RES-00001"]["Resistance"] == "22k"
    assert v["RES-00001"]["Tolerance"] == "5%"
    assert v["RES-00001"]["ComponentLink1Description"] == "Datasheet"

    # editing must not wipe date_added or cascade the extension row away
    con.execute("UPDATE parts SET date_added='2020-01-01' "
                "WHERE part_number='RES-00001'")
    save_part(con, "Resistors", {"part_number": "RES-00001",
                                 "resistance": "47k", "mpn": "X"})
    again = load_part(con, "Resistors", "RES-00001")
    assert again["date_added"] == "2020-01-01", again["date_added"]
    assert again["resistance_ohms"] == 47000

    # a part marked Do Not Use drops out of the view but stays in the table
    save_part(con, "Resistors", {"part_number": "RES-00001",
                                 "resistance": "47k", "mpn": "X",
                                 "status": "Do Not Use"})
    assert len(con.execute('SELECT * FROM "Resistors"').fetchall()) == 1
    assert load_part(con, "Resistors", "RES-00001") is not None
    save_part(con, "Resistors", {"part_number": "RES-00001",
                                 "resistance": "22k", "mpn": "X",
                                 "status": "Active"})

    delete_part(con, "Resistors", "RES-00002")
    assert len(list_parts(con, "Resistors")) == 1
    assert save_part(con, "Resistors", {"resistance": "3k3"}) == "RES-00003"

    d = save_part(con, "Diodes", {"diode_type": "Schottky", "mpn": "1N5819",
                                  "vrrm": "40V", "if_max": "1A"})
    assert load_part(con, "Diodes", d)["value"] == "1N5819"

    assert recent_libs(con, "symbol") == [("RES", "Symbols\\Passives.SchLib")]
    assert recent_libs(con, "footprint") == [("AXIAL-0.4",
                                              "Footprints\\THT.PcbLib")]
    for i in range(RECENT_LIMIT + 2):
        save_part(con, "Capacitors", {
            "capacitance": "100n", "library_ref": "CAP",
            "library_path": "Symbols\\Passives.SchLib",
            "footprint_ref": f"C-{i:02d}",
            "footprint_path": "Footprints\\SMT.PcbLib"})
    seen = recent_libs(con, "footprint")
    assert len(seen) == RECENT_LIMIT, len(seen)
    assert seen[0] == (f"C-{RECENT_LIMIT + 1:02d}", "Footprints\\SMT.PcbLib")
    assert len(set(seen)) == len(seen)
    assert [ref for ref, _ in recent_libs(con, "symbol")] == ["CAP", "RES"]

    save_part(con, "Capacitors", {"capacitance": "1n", "library_ref": "cap",
                                  "library_path": "symbols\\passives.schlib"})
    assert [ref for ref, _ in recent_libs(con, "symbol")] == ["CAP", "RES"]
    assert last_libraries(con, "Resistors")["library_ref"] == ""
    assert last_libraries(con, "Capacitors")["library_ref"] == "cap"

    libs = {"m68k.SchLib": ["CAP", "MC68230P10", "RES"]}
    assert lib_status(libs, "RES", "m68k.SchLib") == ("ok", "m68k.SchLib")
    assert lib_status(libs, "res", "Symbols\\m68k.SchLib")[0] == "ok"
    assert lib_status(libs, "NOPE", "m68k.SchLib") == ("missing",
                                                       "m68k.SchLib")
    assert lib_status(libs, "CAP", "") == ("elsewhere", "m68k.SchLib")
    assert lib_status(libs, "", "m68k.SchLib") == ("", "")
    assert lib_status({}, "RES", "m68k.SchLib") == ("", "")
    assert find_library(libs, "mc68230p10") == "m68k.SchLib"
    assert find_library(libs, "nope") == ""
    assert _dedupe(["RES", "res", "", None, "CAP"]) == ["RES", "CAP"]

    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "symbols").mkdir()
        (root / "History").mkdir()
        (root / "symbols" / "Broken.SchLib").write_bytes(b"not a library")
        (root / "Board.PcbLib").write_bytes(b"")
        (root / "History" / "Old.SchLib").write_bytes(b"")
        found = scan_libraries(root)
        broken = str(Path("symbols") / "Broken.SchLib")
        assert list(found["symbol"]) == [broken]
        assert list(found["footprint"]) == ["Board.PcbLib"]
        assert not any(found["symbol"].values())
    for kind, found in scan_libraries().items():
        for rel, names in found.items():
            assert isinstance(names, list), rel

    fresh = connect(":memory:")
    save_part(fresh, "Resistors", {"resistance": "1k", "library_ref": "RES",
                                   "library_path": "m68k.SchLib"})
    save_part(fresh, "Diodes", {"mpn": "1N4148", "library_ref": "DIODE",
                                "library_path": "m68k.SchLib"})
    fresh.execute("DELETE FROM recent")
    seed_recent(fresh)
    assert [r for r, _ in recent_libs(fresh, "symbol")] == ["DIODE", "RES"]
    seed_recent(fresh)
    assert len(recent_libs(fresh, "symbol")) == 2
    print("selftest ok")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if "--selftest" in sys.argv:
        selftest()
        return
    if "--libs" in sys.argv:
        for kind, found in scan_libraries().items():
            for rel, names in found.items():
                print(f"{rel} - {len(names)} {kind}"
                      f"{'' if len(names) == 1 else 's'}")
                for name in names:
                    print(f"    {name}")
        return
    if args:
        path = args[0]
    elif CONFIG.exists() and CONFIG.read_text().strip():
        path = CONFIG.read_text().strip()
    else:
        path = str(Path(__file__).resolve().parent / "parts.db")
        CONFIG.write_text(path)
    os.makedirs(Path(path).parent, exist_ok=True)
    run_gui(path)


if __name__ == "__main__":
    main()
