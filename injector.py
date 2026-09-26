import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys

RES_LINKS = (
    "art",
    "crt.landscape",
    "fonts",
    "international",
    "license",
    "privacypolicy",
    "sound",
    "wallpapers.desktop",
)


def is_junction(path):
    try:
        st = os.lstat(path)
    except OSError:
        return False
    return bool(getattr(st, "st_file_attributes", 0) & 0x400)


def ensure_res_links(game):
    made, skip = [], []
    res = os.path.join(game, "Resources")
    for d in RES_LINKS:
        link, target = os.path.join(game, d), os.path.join(res, d)
        if not os.path.isdir(target):
            continue
        if is_junction(link):
            continue
        if os.path.lexists(link):
            skip.append(d)
            continue
        try:
            subprocess.check_call(
                ["cmd", "/c", "mklink", "/J", link, target],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            made.append(d)
        except Exception:
            skip.append(d + " (falha mklink)")
    return made, skip


def remove_res_links(game):
    out = []
    for d in RES_LINKS:
        link = os.path.join(game, d)
        if is_junction(link):
            try:
                os.rmdir(link)
                out.append("link removed " + d)
            except OSError as e:
                out.append("link %s NOT removed (%s)" % (d, e))
    return out


CAR_MAGIC = b"rac\x01"
CAR_REL = os.path.join("Resources", "resource.car")
BACKUP_SUFFIX = ".bak"
ORIG_MAIN = "orig_main.lu"
PATCHED_MAIN = "patched_main.lu"
LOADER_FILES = (
    "main.lua",
    "config.lua",
    "alpha_rules.lua",
    "alpha_board.lua",
    "alpha_hud.lua",
    "alpha_end.lua",
    "alpha_flow.lua",
    "pibe_quark.lua",
    "mod_defender_firewall.lua",
)

LEGACY_FILES = (
    "mod_unused4.lua",
    "mod_winreal_min.lua",
    "mod_alpha_bar.lua",
    "mod_alpha_barlogic.lua",
    "mod_alpha_board.lua",
    "mod_alpha_cheat.lua",
    "mod_alpha_defbar.lua",
    "mod_alpha_finish.lua",
    "mod_alpha_flow.lua",
    "mod_alpha_gameplay.lua",
    "mod_alpha_gbridge.lua",
    "mod_alpha_highlight.lua",
    "mod_alpha_hud.lua",
    "mod_alpha_layout.lua",
    "mod_alpha_loss.lua",
    "mod_alpha_outline.lua",
    "mod_alpha_realbar.lua",
    "mod_alpha_redsquare.lua",
    "mod_alpha_rows.lua",
    "mod_alpha_rowsphys.lua",
    "mod_alpha_select.lua",
    "mod_alpha_textcolor.lua",
    "mod_alpha_timer.lua",
    "mod_alpha_touch.lua",
    "mod_alpha_vslide.lua",
    "mod_alpha_win.lua",
)

CAR_LU = (
    "bit8help.lu",
    "inet.lu",
    "leveldata.lu",
    "plugin_apple_iap.lu",
    "plugin_applovinMax.lu",
    "plugin_att.lu",
    "plugin_google_iap_billing_v2.lu",
    "plugin_google_iap_v3.lu",
    "plugin_gpgs_v3.lu",
    "plugin_icloud.lu",
    "plugin_notifications_v2.lu",
)
HUD_LOG = "mod_alpha_hud.log"
ART_SRC = "art"
MANIFEST = "v1_manifest.json"
RUNTIME_LOG = "modloader_v1.log"
MOD_ID = "alpha-pibe-quark-v29"

ICON_MODES = (
    "Relax",
    "Normal",
    "Hardcore",
    "minesweeper",
    "defender",
    "progresstein",
    "pinball",
    "alphabeth",
)
NAV_MODES = ("Pibe", "Quark", "Back")
PAYLOAD_DONOR_MODES = ("alphabeth",) + NAV_MODES
ICON_PREFIX = "ico32_gamemode_"
ICON_SUFFIX = ".png"
ICON_FALLBACK_PRIMARY = {
    "B1": "1",
    "B2": "2",
    "B3": "31",
    "B4": "31",
    "B5": "31",
    "B6": "36",
    "B7": "81",
    "B8": "81",
    "B9": "95",
    "B10": "95",
    "B10II": "95",
    "B10III": "95plus",
    "B11": "95plus",
    "B12": "CH",
    "B13": "WP",
    "B14": "36",
    "B15": "81",
    "BOS": "95",
    "BX": "95plus",
}
ICON_FALLBACK_CHAIN = ("95", "1")
ICON_EXTRA_FILES = (
    "ico_gflag.png",
    "ico_rflag.png",
    "ico_yflag.png",
    "popupwindow_miner.png",
    "ico32_bomb.png",
    "buttonsquare.png",
    "buttonsquare.dots.png",
    "buttonsquare.green.png",
    "block_broken1.png",
    "block_broken2.png",
    "segment.square1.png",
    "segment.square3.png",
    "segment.square4.png",
    "firewall_wall.png",
    "ico32_firewall.png",
    "ico_firewall.png",
    "laser.png",
    "lasergenerator.png",
    "laserv.png",
    "defenderplaceholder.png",
    "ico_bin.happy.png",
    "ico_bin.neutral.png",
    "ico_bin.sad.png",
    "likeicon.png",
    "dog_happy.png",
    "dog_sad.png",
    "dog_like.png",
)
ICON_EXTRA_CHAIN = ("98", "95plus", "BOS", "design1", "95", "1")
ICON_DESIGN_DIRS = (
    "design0",
    "design6",
    "design7",
    "design8",
    "design9",
    "design10",
    "design11",
    "design12",
    "design13",
)
ICON_DESIGN_CHAIN = ("design1", "95", "1")

CLIPPY_DONOR = "95"


def icon_donor_chain(primary):
    seen, out = set(), []
    for d in [primary] + list(ICON_FALLBACK_CHAIN):
        if d and d not in seen:
            seen.add(d)
            out.append(d)
    return out


def _donor_file(artroot, donor, fn):
    if donor.startswith("design"):
        cand = os.path.join(artroot, "assets", donor, fn)
    else:
        cand = os.path.join(artroot, "skins", donor, fn)
    return cand if os.path.isfile(cand) else None


def _payload_donor(payload_art, donor, fn):
    if not payload_art:
        return None
    if donor.startswith("design"):
        cand = os.path.join(payload_art, "assets", donor, fn)
    else:
        cand = os.path.join(payload_art, "skins", donor, fn)
    return cand if os.path.isfile(cand) else None


def plan_icon_fallback(artroot, payload_art=None):
    jobs = []
    for target, primary in sorted(ICON_FALLBACK_PRIMARY.items()):
        tdir = os.path.join(artroot, "skins", target)
        if not os.path.isdir(tdir):
            continue
        chain = icon_donor_chain(primary)
        for mode in list(ICON_MODES) + list(NAV_MODES):
            fn = ICON_PREFIX + mode + ICON_SUFFIX
            dst = os.path.join(tdir, fn)
            if os.path.isfile(dst) and mode not in NAV_MODES:
                continue
            src = None
            if mode in PAYLOAD_DONOR_MODES:
                for d in chain:
                    cand = _payload_donor(payload_art, d, fn)
                    if cand is not None:
                        src = cand
                        break
            if src is None:
                for d in chain:
                    cand = _donor_file(artroot, d, fn)
                    if cand is not None:
                        src = cand
                        break
            if src is None:
                continue
            rel = os.path.join("skins", target, fn)
            jobs.append((rel, src))
        for fn in ICON_EXTRA_FILES:
            dst = os.path.join(tdir, fn)
            if os.path.isfile(dst):
                continue
            src = None
            for d in icon_donor_chain(primary) + [
                c for c in ICON_EXTRA_CHAIN if c not in icon_donor_chain(primary)
            ]:
                cand = _donor_file(artroot, d, fn)
                if cand is not None:
                    src = cand
                    break
            if src is None:
                continue
            rel = os.path.join("skins", target, fn)
            jobs.append((rel, src))
    for des in ICON_DESIGN_DIRS:
        ddir = os.path.join(artroot, "assets", des)
        if not os.path.isdir(ddir):
            continue
        for mode in list(ICON_MODES) + list(NAV_MODES):
            fn = ICON_PREFIX + mode + ICON_SUFFIX
            dst = os.path.join(ddir, fn)
            if os.path.isfile(dst) and mode not in NAV_MODES:
                continue
            src = None
            if mode in PAYLOAD_DONOR_MODES:
                for d in ICON_DESIGN_CHAIN:
                    cand = _payload_donor(payload_art, d, fn)
                    if cand is not None:
                        src = cand
                        break
            if src is None:
                for d in ICON_DESIGN_CHAIN:
                    cand = _donor_file(artroot, d, fn)
                    if cand is not None:
                        src = cand
                        break
            if src is None:
                continue
            rel = os.path.join("assets", des, fn)
            jobs.append((rel, src))
    return jobs


def apply_icon_fallback(artroot, payload_art=None):
    copied, skipped = {}, []
    force_fns = set([ICON_PREFIX + m + ICON_SUFFIX for m in NAV_MODES])
    for rel, src in plan_icon_fallback(artroot, payload_art):
        dst = os.path.join(artroot, rel)
        fn = os.path.basename(rel)
        if os.path.isfile(dst) and fn not in force_fns:
            continue
        try:
            with open(src, "rb") as f:
                data = f.read()
        except OSError:
            skipped.append(rel + " (unreadable donor)")
            continue
        try:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as f:
                f.write(data)
        except OSError as e:
            skipped.append(rel + " (write failed: %s)" % e)
            continue
        donor = os.path.basename(os.path.dirname(src))
        copied[rel] = {"sha256": sha256_file(dst), "donor": donor}
    for target in sorted(ICON_FALLBACK_PRIMARY):
        tdir = os.path.join(artroot, "skins", target)
        if not os.path.isdir(tdir):
            continue
        for fn in [
            ICON_PREFIX + m + ICON_SUFFIX
            for m in list(ICON_MODES) + list(NAV_MODES)
        ] + list(ICON_EXTRA_FILES):
            rel = os.path.join("skins", target, fn)
            if rel in copied:
                continue
            if not os.path.isfile(os.path.join(tdir, fn)):
                skipped.append(rel + " (no donor has it)")
    for des in ICON_DESIGN_DIRS:
        ddir = os.path.join(artroot, "assets", des)
        if not os.path.isdir(ddir):
            continue
        for mode in list(ICON_MODES) + list(NAV_MODES):
            fn = ICON_PREFIX + mode + ICON_SUFFIX
            rel = os.path.join("assets", des, fn)
            if rel in copied:
                continue
            if not os.path.isfile(os.path.join(ddir, fn)):
                skipped.append(rel + " (no donor has it)")
    return copied, skipped


def merge_icon_records(old_records, artroot, fresh_copied):
    merged = dict(fresh_copied)
    for rel, info in (old_records or {}).items():
        if rel in merged:
            continue
        parts = rel.replace("\\", "/").split("/")
        if (
            not parts
            or ".." in parts
            or rel.startswith("/")
            or (len(parts[0]) == 2 and parts[0][1] == ":")
        ):
            continue
        fp = os.path.join(artroot, *parts)
        try:
            same = os.path.isfile(fp) and sha256_file(fp) == (info or {}).get(
                "sha256"
            )
        except OSError:
            same = False
        if same:
            merged[rel] = info
    return merged


def remove_icon_fallback(artroot, records, tag="icon"):
    out = []
    for rel in sorted(records or {}):
        parts = rel.replace("\\", "/").split("/")
        if (
            not parts
            or ".." in parts
            or rel.startswith("/")
            or (len(parts[0]) == 2 and parts[0][1] == ":")
        ):
            out.append(tag + " SKIPPED (suspicious path): " + rel)
            continue
        fp = os.path.join(artroot, *parts)
        if os.path.isfile(fp):
            try:
                os.remove(fp)
                out.append("removed " + tag + "/" + rel)
            except OSError as e:
                out.append(tag + " NOT removed %s (%s)" % (rel, e))
        else:
            out.append(tag + " already gone " + rel)
    return out


def plan_clippy_fallback(artroot):
    jobs, skipped = [], []
    skins_dir = os.path.join(artroot, "skins")
    donor_dir = os.path.join(skins_dir, CLIPPY_DONOR)
    if not os.path.isdir(donor_dir):
        return jobs, ["donor skins/%s missing" % CLIPPY_DONOR]
    try:
        donor_files = sorted(os.listdir(donor_dir))
    except OSError:
        return jobs, ["donor skins/%s unreadable" % CLIPPY_DONOR]
    clippy = [
        f
        for f in donor_files
        if "clippy" in f.lower() and os.path.isfile(os.path.join(donor_dir, f))
    ]
    if not clippy:
        return jobs, ["no clippy files in skins/%s" % CLIPPY_DONOR]
    try:
        targets = sorted(
            d for d in os.listdir(skins_dir) if os.path.isdir(os.path.join(skins_dir, d))
        )
    except OSError:
        return jobs, ["skins dir unreadable"]
    for target in targets:
        if target == CLIPPY_DONOR:
            continue
        tdir = os.path.join(skins_dir, target)
        for fn in clippy:
            dst = os.path.join(tdir, fn)
            if os.path.isfile(dst):
                continue
            rel = os.path.join("skins", target, fn)
            jobs.append((rel, os.path.join(donor_dir, fn)))
    if not jobs:
        skipped.append(
            "all systems already have clippy (%d file(s))" % len(clippy)
        )
    return jobs, skipped


def apply_clippy_fallback(artroot):
    jobs, skipped = plan_clippy_fallback(artroot)
    copied = {}
    skipped = list(skipped)
    for rel, src in jobs:
        dst = os.path.join(artroot, rel)
        if os.path.isfile(dst):
            continue
        try:
            with open(src, "rb") as f:
                data = f.read()
        except OSError:
            skipped.append(rel + " (unreadable donor)")
            continue
        try:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as f:
                f.write(data)
        except OSError as e:
            skipped.append(rel + " (write failed: %s)" % e)
            continue
        donor = os.path.basename(os.path.dirname(src))
        copied[rel] = {"sha256": sha256_file(dst), "donor": donor}
    return copied, skipped


LANGS = ("de", "en", "es", "fr", "it", "ja", "pl", "pt", "ro", "ru", "tr", "ua")
STRINGS_REL = os.path.join("Resources", "international", "%s", "strings.xml")
ANCHOR = b"GameModeHardcoreShine"
NEWKEY = b"GameModealphabeth"
CHARMAP_KEY = b"CharacterMap"

PROGRESS_MAP = "Progress Map"

ALPHABETH_VALUES = {lg: PROGRESS_MAP for lg in LANGS}
CHARMAP_VALUES = {lg: PROGRESS_MAP for lg in LANGS}

NAVKEY_PIBE = b"GameModePibe"
NAVKEY_QUARK = b"GameModeQuark"
NAVKEY_BACK = b"GameModeBack"
NAVKEYS = (NAVKEY_PIBE, NAVKEY_QUARK, NAVKEY_BACK)
PIBE_VALUES = {lg: "Pibe" for lg in LANGS}
QUARK_VALUES = {lg: "Quark" for lg in LANGS}
BACK_VALUES = {lg: "Back" for lg in LANGS}
NAVKEY_VALUES = {
    NAVKEY_PIBE: PIBE_VALUES,
    NAVKEY_QUARK: QUARK_VALUES,
    NAVKEY_BACK: BACK_VALUES,
}

HERE = os.path.dirname(os.path.abspath(__file__))
PAYLOAD = os.path.join(HERE, "payload")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for blk in iter(lambda: f.read(65536), b""):
            h.update(blk)
    return h.hexdigest()


def pad_len(length, kind):
    p = (length + (4 - length % 4)) - length
    if kind == "data" and p >= 4:
        p = 0
    return p


def read_car_index(car_path):
    with open(car_path, "rb") as f:
        if f.read(4) != CAR_MAGIC:
            raise ValueError("invalid magic: not a resource.car")
        rev, _, n = struct.unpack("iii", f.read(12))
        if rev != 1:
            raise ValueError("resource.car revision = %r (expected 1)" % rev)
        entries = []
        for _ in range(n):
            dtype, off, ln = struct.unpack("iii", f.read(12))
            if dtype != 1:
                raise ValueError("unexpected index entry (%r)" % dtype)
            name = f.read(ln).decode("utf-8")
            f.read(pad_len(ln, "index"))
            entries.append((off, name))
    return entries


def extract_car_entry(car_path, want):
    entries = read_car_index(car_path)
    size = os.path.getsize(car_path)
    for off, name in entries:
        if name != want:
            continue
        with open(car_path, "rb") as f:
            f.seek(off)
            dtype, _nxt, ln = struct.unpack("iii", f.read(12))
            if dtype != 2:
                raise ValueError("invalid data entry for %r" % name)
            if off + 12 + ln > size:
                raise ValueError("entry %r exceeds file" % name)
            return f.read(ln)
    raise KeyError("file %r not found in .car" % want)


def verify_car(car_path):
    entries = read_car_index(car_path)
    size = os.path.getsize(car_path)
    names = [n for _, n in entries]
    if "main.lu" not in names:
        raise ValueError("main.lu missing from index")
    with open(car_path, "rb") as f:
        for off, name in entries:
            f.seek(off)
            dtype, _nxt, ln = struct.unpack("iii", f.read(12))
            if dtype != 2 or off + 12 + ln > size:
                raise ValueError("corrupt entry: %r" % name)
            f.read(ln)
    return names


def game_paths(game):
    car = os.path.join(game, CAR_REL)
    strings = {lg: os.path.join(game, STRINGS_REL % lg) for lg in LANGS}
    return {
        "car": car,
        "backup": car + BACKUP_SUFFIX,
        "manifest": os.path.join(game, MANIFEST),
        "orig": os.path.join(game, ORIG_MAIN),
        "patched": os.path.join(game, PATCHED_MAIN),
        "log": os.path.join(game, RUNTIME_LOG),
        "strings": strings,
        "artroot": os.path.join(game, "Resources", "art"),
    }


def build_patched_main(main_bytes):
    from patch_bytecode import (
        P95_FINGERPRINT,
        PC_JOBS,
        apply_unused4,
        apply_winicon,
        audit_gamemodes,
        audit_gamemodes_prefix,
        audit_sites,
        parse,
        serialize,
        verify_patch,
    )

    header, protos = parse(main_bytes)
    if serialize(header, protos) != main_bytes:
        raise ValueError("parser round-trip NOT identical (aborted)")
    report = apply_unused4(protos)
    report["winicon"] = apply_winicon(protos)
    patched = serialize(header, protos)
    verify_patch(main_bytes, patched, p24_lines=tuple(report["p24_lines"]))

    audits = {}
    header2, protos2 = parse(patched)
    p24 = protos2[0].subs[0].subs[24]
    for first, tail in (("Shine", ["alphabeth"]), ("RelaxShine", ["alphabeth"])):
        a = audit_gamemodes(p24, first.encode())
        got = [e[0] if isinstance(e, list) else None for e in a["entries"]]
        if got[-len(tail):] != tail:
            raise ValueError("unexpected tail in %r: %r" % (first, got))
        if [len(e) for e in a["entries"][-len(tail):]] != [1] * len(tail):
            raise ValueError("unexpected shape in %r" % first)
        audits[first] = {
            "n": len(a["entries"]),
            "hint": a["hint_B"],
            "final": a["final_B"],
            "tail": tail,
        }
    a95 = audit_gamemodes_prefix(p24, P95_FINGERPRINT)
    tail95 = ["alphabeth"]
    if len(a95["entries"]) != 7:
        raise ValueError("P95: n=%d (expected 7)" % len(a95["entries"]))
    if a95["entries"][:6] != P95_FINGERPRINT:
        raise ValueError("P95: original prefix changed")
    got95 = [
        e[0] if isinstance(e, list) else None for e in a95["entries"][-1:]
    ]
    if got95 != tail95:
        raise ValueError("P95: unexpected tail: %r" % (got95,))
    if [len(e) for e in a95["entries"][-1:]] != [1] * 1:
        raise ValueError("P95: unexpected tail shape")
    if a95["entries"][2] is not None:
        raise ValueError("P95: nil slot [3] disturbed")
    audits["P95(Normal)"] = {
        "n": len(a95["entries"]),
        "hint": a95["hint_B"],
        "final": a95["final_B"],
        "tail": tail95,
    }

    for label, fp, exp in PC_JOBS:
        if label == "P95":
            continue
        hits = audit_sites(p24, fp)
        hits = [h for h in hits if h["entries"] == fp + [["alphabeth"]]]
        if len(hits) != exp:
            raise ValueError(
                "%s: audit found %d sites (expected %d)"
                % (label, len(hits), exp)
            )
        for h in hits:
            if len(h["entries"]) != len(fp) + 1:
                raise ValueError(
                    "%s: n=%d (expected %d)"
                    % (label, len(h["entries"]), len(fp) + 1)
                )
        audits[label] = {
            "n": len(fp) + 1,
            "sites": len(hits),
            "tail": ["alphabeth"],
        }
    report["audit"] = audits
    return patched, report


def ensure_strings_key(path, lang, key, values, anchor):
    with open(path, "rb") as f:
        raw = f.read()
    marker = b"name='" + key + b"'"
    want = b"<t name='" + key + b"'>" + values[lang].encode("utf-8") + b"</t>"
    if marker in raw:
        if want in raw:
            return ("ok-already-applied", "key already present with expected value")
        lines = raw.split(b"\n")
        hit = [i for i, ln in enumerate(lines) if marker in ln]
        if len(hit) != 1:
            return ("ERROR", "key %r found %dx (expected 1x)" % (key, len(hit)))
        idx = hit[0]
        old_line = lines[idx]
        eol = b"\r" if old_line.endswith(b"\r") else b""
        indent = old_line[: len(old_line) - len(old_line.lstrip())]
        lines[idx] = indent + want + eol
        with open(path, "wb") as f:
            f.write(b"\n".join(lines))
        return ("ok-migrated", "value updated to %r" % values[lang])
    lines = raw.split(b"\n")
    hits = [i for i, ln in enumerate(lines) if anchor in ln and b"<t " in ln]
    if len(hits) != 1:
        return ("ERROR", "anchor %r found %dx (expected 1x)" % (anchor, len(hits)))
    idx = hits[0]
    anchor_line = lines[idx]
    eol = b"\r" if anchor_line.endswith(b"\r") else b""
    indent = anchor_line[: len(anchor_line) - len(anchor_line.lstrip())]
    new_line = indent + want + eol
    before, after = lines[: idx + 1], lines[idx + 1 :]
    out = b"\n".join(before + [new_line] + after)

    if out.count(marker) != 1:
        return ("ERROR", "post-write check failed")
    if len(out.split(b"\n")) != len(lines) + 1:
        return ("ERROR", "unexpected line count after insert")
    with open(path, "wb") as f:
        f.write(out)
    return ("ok-applied", "1 line inserted after %r" % anchor)


def patch_strings_lang(path, lang):
    st, det = ensure_strings_key(path, lang, NEWKEY, ALPHABETH_VALUES, ANCHOR)
    if st.startswith("ERROR"):
        return (st, det)
    details = [det]
    prev = NEWKEY
    for key in NAVKEYS:
        stn, detn = ensure_strings_key(path, lang, key, NAVKEY_VALUES[key], prev)
        if stn.startswith("ERROR"):
            return (stn, detn)
        details.append("%s: %s" % (key.decode("utf-8"), detn))
        prev = key
    st2, det2 = ensure_strings_key(path, lang, CHARMAP_KEY, CHARMAP_VALUES, prev)
    if st2.startswith("ERROR"):
        return (st2, "CharacterMap: %s" % det2)
    if (
        st == "ok-already-applied"
        and st2 == "ok-already-applied"
        and all("already present" in d for d in details)
    ):
        return (
            "ok-already-applied",
            "keys already present (%s; CharacterMap: %s)"
            % ("; ".join(details), det2),
        )
    return ("ok-applied", "%s; CharacterMap: %s" % ("; ".join(details), det2))


def unpatch_strings_lang(path):
    with open(path, "rb") as f:
        raw = f.read()
    markers = (
        b"name='" + NEWKEY + b"'",
        b"name='" + CHARMAP_KEY + b"'",
        b"name='" + NAVKEY_PIBE + b"'",
        b"name='" + NAVKEY_QUARK + b"'",
        b"name='" + NAVKEY_BACK + b"'",
    )
    if not any(m in raw for m in markers):
        return "missing (nothing to do)"
    lines = raw.split(b"\n")
    kept = [ln for ln in lines if not any(m in ln for m in markers)]
    removed = len(lines) - len(kept)
    if removed < 1 or removed > 5:
        return "ERROR: %d lines with keys (expected 1-5; not reverted)" % removed
    with open(path, "wb") as f:
        f.write(b"\n".join(kept))
    return "reverted (%d line(s) removed)" % removed


def cmd_apply(game):
    p = game_paths(game)
    if not os.path.isfile(p["car"]):
        return "ERROR: resource.car not found in %s" % p["car"]
    man_path = p["manifest"]
    foreign = os.path.isfile(os.path.join(game, "main.lua")) and not os.path.isfile(
        man_path
    )
    if foreign and "--force" not in sys.argv:
        return "ERROR: foreign main.lua already exists (no manifest). Pass --force to replace."
    car_hash_before = sha256_file(p["car"])
    names = verify_car(p["car"])

    if not os.path.isfile(p["backup"]):
        shutil.copyfile(p["car"], p["backup"])
    bak_hash = sha256_file(p["backup"])

    main_bytes = extract_car_entry(p["car"], "main.lu")
    if main_bytes[:4] != b"\x1bLua":
        return "ERROR: extracted main.lu without Lua header (magic=%r)" % main_bytes[:4]
    with open(p["orig"], "wb") as f:
        f.write(main_bytes)
    try:
        patched_bytes, surgery = build_patched_main(main_bytes)
    except Exception as e:
        if os.path.isfile(p["patched"]):
            os.remove(p["patched"])
        return "ERROR in bytecode surgery: %s (nothing installed; game intact)" % e
    with open(p["patched"], "wb") as f:
        f.write(patched_bytes)
    installed = {}
    for fn in LOADER_FILES:
        src = os.path.join(PAYLOAD, fn)
        dst = os.path.join(game, fn)
        shutil.copyfile(src, dst)
        installed[fn] = sha256_file(dst)
    for fn in LEGACY_FILES:
        fp = os.path.join(game, fn)
        if os.path.isfile(fp):
            os.remove(fp)
    links_made, links_skip = ensure_res_links(game)

    car_lu = {}
    for fn in CAR_LU:
        try:
            data = extract_car_entry(p["car"], fn)
        except (KeyError, ValueError) as e:
            return "ERROR: %s missing in resource.car (%s; game intact)" % (fn, e)
        dst = os.path.join(game, fn)
        with open(dst, "wb") as f:
            f.write(data)
        car_lu[fn] = sha256_file(dst)
    art_icons = {}
    art_base = os.path.join(PAYLOAD, ART_SRC)
    if os.path.isdir(art_base):
        for dp, _dn, fn in os.walk(art_base):
            for f in sorted(fn):
                src = os.path.join(dp, f)
                rel = os.path.relpath(src, art_base)
                dst = os.path.join(game, "Resources", "art", rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copyfile(src, dst)
                art_icons[rel] = sha256_file(dst)
    try:
        with open(p["manifest"]) as f:
            old_icons = json.load(f).get("icon_fallback") or {}
    except Exception:
        old_icons = {}
    fb_copied, fb_skipped = apply_icon_fallback(
        p["artroot"], os.path.join(PAYLOAD, ART_SRC)
    )
    icon_fallback = merge_icon_records(old_icons, p["artroot"], fb_copied)

    try:
        with open(p["manifest"]) as f:
            old_clippy = json.load(f).get("clippy_fallback") or {}
    except Exception:
        old_clippy = {}
    clippy_copied, clippy_skipped = apply_clippy_fallback(p["artroot"])
    clippy_fallback = merge_icon_records(old_clippy, p["artroot"], clippy_copied)
    try:
        _skins = os.path.join(p["artroot"], "skins")
        for _t in os.listdir(_skins):
            _td = os.path.join(_skins, _t)
            if not os.path.isdir(_td):
                continue
            for _fn in ("pibe_banner.png", "quark_banner.png"):
                _fp = os.path.join(_td, _fn)
                if os.path.isfile(_fp):
                    os.remove(_fp)
    except OSError:
        pass

    strings_res, strings_hash = {}, {}
    for lang in LANGS:
        sp = p["strings"][lang]
        if not os.path.isfile(sp):
            strings_res[lang] = "ERROR: file missing"
            continue
        bak = sp + BACKUP_SUFFIX

        with open(sp, "rb") as f:
            _raw = f.read()
        _want = (
            b"<t name='"
            + NEWKEY
            + b"'>"
            + ALPHABETH_VALUES[lang].encode("utf-8")
            + b"</t>"
        )
        if b"name='" + NEWKEY + b"'" in _raw and _want in _raw:
            st, det = (
                "ok-already-applied",
                "key already present with expected value (no .bak)",
            )
            strings_res[lang] = "%s (%s)" % (st, det)
            strings_hash[lang] = sha256_file(sp)
            continue
        if not os.path.isfile(bak):
            shutil.copyfile(sp, bak)
        st, det = patch_strings_lang(sp, lang)
        strings_res[lang] = "%s (%s)" % (st, det)
        if st.startswith("ERROR"):
            for lg2 in LANGS:
                b2 = p["strings"][lg2] + BACKUP_SUFFIX
                if os.path.isfile(b2):
                    shutil.copyfile(b2, p["strings"][lg2])
            return "ERROR in texts [%s]: %s (texts reverted from .bak)" % (lang, det)
        strings_hash[lang] = sha256_file(sp)
    car_hash_after = sha256_file(p["car"])
    if car_hash_after != car_hash_before:
        return "ERROR: resource.car changed during apply (aborted)"
    verify_car(p["car"])

    manifest = {
        "mod": MOD_ID,
        "vector": "loose-override <exe>/main.lua + patched_main.lu",
        "car_sha256": car_hash_after,
        "backup_sha256": bak_hash,
        "orig_main_sha256": sha256_file(p["orig"]),
        "patched_main_sha256": sha256_file(p["patched"]),
        "files": installed,
        "res_links": links_made,
        "surgery": surgery,
        "strings": strings_hash,
        "strings_detail": strings_res,
        "art_icons": art_icons,
        "icon_fallback": icon_fallback,
        "icon_fallback_detail": {"copied": len(fb_copied), "skipped": fb_skipped},
        "clippy_fallback": clippy_fallback,
        "clippy_fallback_detail": {
            "copied": len(clippy_copied),
            "skipped": clippy_skipped,
        },
        "car_lu": car_lu,
        "car_entries": len(names),
    }
    if os.path.dirname(man_path):
        os.makedirs(os.path.dirname(man_path), exist_ok=True)
    with open(man_path, "w") as f:
        json.dump(manifest, f, indent=2)
    return (
        "OK apply %s: car=%s (%d entries, sha %.12s...) intact; "
        "loader installed (%s); alphabeth texts in 12/12 languages; "
        "wine icons %d fallback (%d skipped); clippy %d fallback (%d skipped)."
        % (
            MOD_ID,
            p["car"],
            len(names),
            car_hash_after,
            ", ".join(LOADER_FILES),
            len(icon_fallback),
            len(fb_skipped),
            len(clippy_fallback),
            len(clippy_skipped),
        )
    )


def cmd_restore(game):
    p = game_paths(game)
    out = []
    for fn in (
        list(LOADER_FILES)
        + list(LEGACY_FILES)
        + list(CAR_LU)
        + [
            ORIG_MAIN,
            PATCHED_MAIN,
            RUNTIME_LOG,
            HUD_LOG,
            "probe_hit.txt",
            "pibe_installed.save",
            "quark_installed.save",
        ]
    ):
        fp = os.path.join(game, fn)
        if os.path.isfile(fp):
            os.remove(fp)
            out.append("removed " + fn)
    out.extend(remove_res_links(game))

    try:
        with open(p["manifest"]) as f:
            _man = json.load(f)
            man_art = _man.get("art_icons", {}) or {}
            man_icons = _man.get("icon_fallback", {}) or {}
            man_clippy = _man.get("clippy_fallback", {}) or {}
    except Exception:
        man_art = {}
        man_icons = {}
        man_clippy = {}
    for rel in sorted(man_art):
        parts = rel.replace("\\", "/").split("/")
        if (
            not parts
            or ".." in parts
            or rel.startswith("/")
            or (len(parts[0]) == 2 and parts[0][1] == ":")
        ):
            out.append("art SKIPPED (suspicious path): " + rel)
            continue
        fp = os.path.join(game, "Resources", "art", *parts)
        if os.path.isfile(fp):
            try:
                os.remove(fp)
                out.append("removed art/" + rel)
            except OSError as e:
                out.append("art NOT removed %s (%s)" % (rel, e))
    out.extend(remove_icon_fallback(p["artroot"], man_icons))
    out.extend(remove_icon_fallback(p["artroot"], man_clippy, "clippy"))
    try:
        skins_dir = os.path.join(p["artroot"], "skins")
        for target in os.listdir(skins_dir):
            tdir = os.path.join(skins_dir, target)
            if not os.path.isdir(tdir):
                continue
            for fn in ("pibe_banner.png", "quark_banner.png"):
                fp = os.path.join(tdir, fn)
                if os.path.isfile(fp):
                    os.remove(fp)
                    out.append("removed skins/%s/%s (stale banner)" % (target, fn))
    except OSError:
        pass
    if os.path.isfile(p["manifest"]):
        os.remove(p["manifest"])
        out.append("removed manifest")
    for lang in LANGS:
        sp = p["strings"][lang]
        bak = sp + BACKUP_SUFFIX
        if os.path.isfile(bak):
            if os.path.isfile(sp):
                with open(sp, "rb") as f:
                    cur = f.read()
                with open(bak, "rb") as f:
                    orig = f.read()
                if cur != orig:
                    shutil.copyfile(bak, sp)
                    out.append("strings[%s] restored from .bak" % lang)
                else:
                    out.append("strings[%s] already identical to .bak" % lang)
            else:
                shutil.copyfile(bak, sp)
                out.append("strings[%s] recreated from .bak" % lang)
            os.remove(bak)
            if os.path.isfile(sp):
                r = unpatch_strings_lang(sp)
                if not r.startswith("missing"):
                    out.append("strings[%s] post-.bak cleanup: %s" % (lang, r))
        elif os.path.isfile(sp):
            r = unpatch_strings_lang(sp)
            out.append("strings[%s] %s" % (lang, r))
    if os.path.isfile(p["backup"]):
        if os.path.isfile(p["car"]):
            if sha256_file(p["car"]) != sha256_file(p["backup"]):
                shutil.copyfile(p["backup"], p["car"])
                out.append("resource.car restored from backup")
            else:
                out.append("resource.car already identical to backup")
        else:
            shutil.copyfile(p["backup"], p["car"])
            out.append("resource.car recreated from backup")
    else:
        out.append("no backup (nothing to restore in .car)")
    return "OK restore: " + ("; ".join(out) if out else "nothing to do")


def cmd_status(game):
    p = game_paths(game)
    lines = ["game: %s" % game]
    if os.path.isfile(p["manifest"]):
        try:
            with open(p["manifest"]) as f:
                man = json.load(f)
            lines.append("manifest: %s (%s)" % (man.get("mod", "?"), "present"))
        except Exception as e:
            lines.append("manifest: unreadable (%s)" % e)
    else:
        lines.append("manifest: missing")
    if os.path.isfile(p["backup"]):
        lines.append("backup car: OK sha %.12s..." % sha256_file(p["backup"]))
    else:
        lines.append("backup car: MISSING")
    if os.path.isfile(p["car"]):
        try:
            names = verify_car(p["car"])
            lines.append(
                "car: OK (%d entries, sha %.12s...)"
                % (len(names), sha256_file(p["car"]))
            )
        except Exception as e:
            lines.append("car: FAIL (%s)" % e)
    else:
        lines.append("car: MISSING")
    for fn in list(LOADER_FILES) + list(CAR_LU) + list(LEGACY_FILES) + [ORIG_MAIN]:
        fp = os.path.join(game, fn)
        lines.append("%s: %s" % (fn, "present" if os.path.isfile(fp) else "missing"))
    links = [d for d in RES_LINKS if is_junction(os.path.join(game, d))]
    lines.append(
        "links: %d/%d (%s)"
        % (len(links), len(RES_LINKS), ",".join(links) or "none")
    )
    n_icon = n_title = 0
    artroot = os.path.join(game, "Resources", "art")
    if os.path.isdir(artroot):
        for dp, _dn, fn in os.walk(artroot):
            for f in fn:
                if f == "ico32_gamemode_alphabeth.png":
                    n_icon += 1
                elif f == "ico_progressmap.png":
                    n_title += 1
    lines.append("icons: mode=%d title=%d" % (n_icon, n_title))
    try:
        with open(p["manifest"]) as f:
            _man2 = json.load(f)
        _fb = _man2.get("icon_fallback", {}) or {}
        _det = _man2.get("icon_fallback_detail", {}) or {}
        lines.append(
            "icons_fallback: %d (skipped %s)"
            % (
                len(_fb),
                _det.get("skipped", "?") if isinstance(_det, dict) else "?",
            )
        )
        _cb = _man2.get("clippy_fallback", {}) or {}
        _cdet = _man2.get("clippy_fallback_detail", {}) or {}
        lines.append(
            "clippy_fallback: %d (skipped %s)"
            % (
                len(_cb),
                _cdet.get("skipped", "?") if isinstance(_cdet, dict) else "?",
            )
        )
    except Exception:
        lines.append("icons_fallback: n/a (no manifest)")
    if os.path.isfile(p["patched"]):
        st = "present sha %.12s..." % sha256_file(p["patched"])
        if os.path.isfile(p["manifest"]):
            try:
                with open(p["manifest"]) as f:
                    man = json.load(f)
                if man.get("patched_main_sha256") == sha256_file(p["patched"]):
                    st += " (matches manifest)"
                else:
                    st += " (DIFFERS from manifest!)"
            except Exception:
                pass
        lines.append("%s: %s" % (PATCHED_MAIN, st))
    else:
        lines.append("%s: missing" % PATCHED_MAIN)
    for lang in LANGS:
        sp = p["strings"][lang]
        st = "missing"
        if os.path.isfile(sp):
            with open(sp, "rb") as f:
                raw = f.read()
            a = (
                "GameModealphabeth=OK"
                if b"name='GameModealphabeth'" in raw
                else "GameModealphabeth=MISSING"
            )
            c = (
                "CharacterMap=OK"
                if b"name='CharacterMap'" in raw
                else "CharacterMap=MISSING"
            )
            n = "".join(
                (k.decode("utf-8") + "=OK ")
                if b"name='" + k + b"'" in raw
                else (k.decode("utf-8") + "=MISSING ")
                for k in NAVKEYS
            )
            st = a + " " + n + c
            if os.path.isfile(sp + BACKUP_SUFFIX):
                st += " (bak OK)"
        lines.append("strings[%s]: %s" % (lang, st))
    return "\n".join(lines)


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    game = HERE
    if "--game" in argv:
        game = argv[argv.index("--game") + 1]
    if game == HERE:
        game = os.path.dirname(HERE)
    game = os.path.abspath(game)
    fn = {"apply": cmd_apply, "restore": cmd_restore, "status": cmd_status}.get(
        cmd
    )
    if not fn:
        return "usage: injector.py apply|restore|status [--game DIR]"
    print(fn(game))


if __name__ == "__main__":
    main(sys.argv)