import struct

OP_LOADK = 1
OP_LOADBOOL = 2
OP_LOADNIL = 3
OP_NEWTABLE = 10
OP_SETTABLE = 9
OP_SETLIST = 34

K_GAMEMODES = b"GameModes"
P11_FIRST = b"Shine"
P12_FIRST = b"RelaxShine"
NEW_CONSTS = [b"alphabeth"]
P11_APPEND = [b"alphabeth"]
P12_APPEND = [b"alphabeth"]
P95_APPEND = [b"alphabeth"]

P95_FINGERPRINT = [
    ["Normal"],
    ["Relax", "pro"],
    None,
    ["minesweeper", "lvl", 15.0],
    ["progresscommander", "lvl", 20.0],
    ["progresstein", "lvl", 25.0],
]

P96_FINGERPRINT = [
    ["Relax"],
    ["Normal"],
    None,
    ["minesweeper"],
    ["defender", "lvl", 5.0],
    ["xl", "lvl", 15.0],
    ["progresscommander", "pro"],
    ["klondike", "lvl", 25.0],
    ["progresstein", "demotimer"],
]

PDS_FP = [
    ["Relax"],
    ["Normal"],
    ["Hardcore"],
    ["Progresstrix"],
    ["progresscommander"],
]
P_1_FP = [
    ["Relax"],
    ["Normal"],
    ["Hardcore"],
    ["minesweeper"],
    ["defender"],
]
P31_FP = [
    ["Relax"],
    ["Normal"],
    ["Hardcore"],
    ["minesweeper"],
    ["defender"],
    ["progresstein", "demotimer"],
]
P98_FP = [
    ["Relax"],
    ["Normal"],
    ["Hardcore", "lvl", 1.0],
    ["minesweeper"],
    ["defender"],
    ["progresstein", "demotimer"],
    ["xl", "pro"],
    ["progresscommander", "pro"],
    ["klondike", "pro"],
]
PME10_FP = [
    ["Relax"],
    ["Normal"],
    ["Hardcore"],
    ["minesweeper"],
    ["defender"],
    ["progresstein", "demotimer"],
    ["xl", "pro"],
    ["pinball", "pro"],
    ["klondike", "pro"],
    ["Progresstrix", "pro"],
]
PNP9_FP = [
    ["Relax"],
    ["Normal"],
    ["Hardcore"],
    ["minesweeper"],
    ["defender"],
    ["progresstein", "demotimer"],
    ["pinball", "pro"],
    ["klondike", "pro"],
    ["Progresstrix", "pro"],
]

PC_JOBS = [
    ("PDS", PDS_FP, 1),
    ("P_1", P_1_FP, 2),
    ("P31", P31_FP, 1),
    ("P95", P95_FINGERPRINT, 1),
    ("P96", P96_FINGERPRINT, 1),
    ("P98", P98_FP, 1),
    ("PME10", PME10_FP, 9),
    ("PNP9", PNP9_FP, 3),
]
PC_SITES_TOTAL = sum(n for _, _, n in PC_JOBS)


def _A(ins): return (ins >> 6) & 0xFF
def _B(ins): return (ins >> 23) & 0x1FF
def _C(ins): return (ins >> 14) & 0x1FF
def _Bx(ins): return (ins >> 14) & 0x3FFFF


def mk_NEWTABLE(a, b, c=0):
    return (OP_NEWTABLE | (a << 6) | (c << 14) | (b << 23)) & 0xFFFFFFFF


def mk_LOADK(a, bx):
    return (OP_LOADK | (a << 6) | (bx << 14)) & 0xFFFFFFFF


def mk_SETLIST(a, b, c=1):
    return (OP_SETLIST | (a << 6) | (c << 14) | (b << 23)) & 0xFFFFFFFF


def set_B(ins, b):
    return ((ins & ~(0x1FF << 23)) | ((b & 0x1FF) << 23)) & 0xFFFFFFFF


class Proto(object):
    def __init__(self):
        self.src = None
        self.linedef = 0
        self.lastlinedef = 0
        self.nups = 0
        self.numparams = 0
        self.isvararg = 0
        self.maxstack = 0
        self.code = []
        self.consts = []
        self.subs = []
        self.lineinfo = []
        self.locvars = []
        self.upvals = []


class Reader(object):
    def __init__(self, data):
        self.d = data
        self.p = 0

    def raw(self, n):
        b = self.d[self.p:self.p + n]
        self.p += n
        return b

    def i32(self):
        v = struct.unpack_from("<i", self.d, self.p)[0]
        self.p += 4
        return v

    def u32(self):
        v = struct.unpack_from("<I", self.d, self.p)[0]
        self.p += 4
        return v

    def string(self):
        sz = self.u32()
        if sz == 0:
            return None
        s = self.d[self.p:self.p + sz - 1]
        self.p += sz
        return s

    def proto(self):
        q = Proto()
        q.src = self.string()
        q.linedef = self.i32()
        q.lastlinedef = self.i32()
        q.nups = self.d[self.p]; self.p += 1
        q.numparams = self.d[self.p]; self.p += 1
        q.isvararg = self.d[self.p]; self.p += 1
        q.maxstack = self.d[self.p]; self.p += 1
        ncode = self.i32()
        q.code = [self.u32() for _ in range(ncode)]
        nk = self.i32()
        for _ in range(nk):
            t = self.d[self.p]; self.p += 1
            if t == 0:
                q.consts.append(("nil", None))
            elif t == 1:
                q.consts.append(("bool", bool(self.d[self.p])))
                self.p += 1
            elif t == 3:
                v = struct.unpack_from("<d", self.d, self.p)[0]
                self.p += 8
                q.consts.append(("num", v))
            elif t == 4:
                q.consts.append(("str", self.string()))
            else:
                raise ValueError("const type %r" % t)
        np = self.i32()
        q.subs = [self.proto() for _ in range(np)]
        nl = self.i32()
        q.lineinfo = [self.i32() for _ in range(nl)]
        nv = self.i32()
        for _ in range(nv):
            nm = self.string()
            a = self.i32(); b = self.i32()
            q.locvars.append((nm, a, b))
        nu = self.i32()
        q.upvals = [self.string() for _ in range(nu)]
        return q


def parse(data):
    if data[:4] != b"\x1bLua":
        raise ValueError("missing Lua magic")
    r = Reader(data)
    header = r.raw(12)
    protos = [r.proto()]
    if r.p != len(data):
        raise ValueError("%d bytes left after parse" % (len(data) - r.p))
    return header, protos


class Writer(object):
    def __init__(self):
        self.b = bytearray()

    def raw(self, x):
        self.b += x

    def i32(self, v):
        self.b += struct.pack("<i", v)

    def u32(self, v):
        self.b += struct.pack("<I", v)

    def string(self, s):
        if s is None:
            self.u32(0)
        else:
            self.u32(len(s) + 1)
            self.b += s + b"\x00"

    def proto(self, q):
        self.string(q.src)
        self.i32(q.linedef)
        self.i32(q.lastlinedef)
        self.raw(bytes((q.nups, q.numparams, q.isvararg, q.maxstack)))
        self.i32(len(q.code))
        for ins in q.code:
            self.u32(ins)
        self.i32(len(q.consts))
        for t, v in q.consts:
            if t == "nil":
                self.raw(b"\x00")
            elif t == "bool":
                self.raw(b"\x01" + (b"\x01" if v else b"\x00"))
            elif t == "num":
                self.raw(b"\x03" + struct.pack("<d", v))
            elif t == "str":
                self.raw(b"\x04")
                self.string(v)
            else:
                raise ValueError("const type %r" % t)
        self.i32(len(q.subs))
        for s in q.subs:
            self.proto(s)
        self.i32(len(q.lineinfo))
        for ln in q.lineinfo:
            self.i32(ln)
        self.i32(len(q.locvars))
        for nm, a, b in q.locvars:
            self.string(nm)
            self.i32(a); self.i32(b)
        self.i32(len(q.upvals))
        for nm in q.upvals:
            self.string(nm)


def serialize(header, protos):
    w = Writer()
    w.raw(header)
    for q in protos:
        w.proto(q)
    return bytes(w.b)


JUMP_OPS = set()


def find_gamemodes_site(p, first_name):
    str_idx = None
    for i, (t, v) in enumerate(p.consts):
        if t == "str" and v == K_GAMEMODES:
            str_idx = i
            break
    if str_idx is None:
        raise ValueError("missing GameModes const")
    first_idx = None
    for i, (t, v) in enumerate(p.consts):
        if t == "str" and v == first_name:
            first_idx = i
            break
    if first_idx is None:
        raise ValueError("missing const %r" % first_name)
    sites = []
    code = p.code
    for i, ins in enumerate(code):
        if (ins & 0x3F) == OP_LOADK and _Bx(ins) == str_idx and _A(ins) == 5:
            if (code[i + 1] & 0x3F) != OP_NEWTABLE or _A(code[i + 1]) != 6:
                continue
            if _B(code[i + 1]) != 10:
                continue
            e0 = code[i + 2:i + 5]
            if not ((e0[0] & 0x3F) == OP_NEWTABLE and _A(e0[0]) == 7 and
                    (e0[1] & 0x3F) == OP_LOADK and _A(e0[1]) == 8 and
                    _Bx(e0[1]) == first_idx and
                    (e0[2] & 0x3F) == OP_SETLIST and _A(e0[2]) == 7 and
                    _B(e0[2]) == 1):
                continue
            regs = []
            j = i + 2
            ok = True
            for k in range(10):
                ins2 = code[j]
                if (ins2 & 0x3F) != OP_NEWTABLE or _A(ins2) != 7 + k:
                    ok = False
                    break
                m = j + 1
                while True:
                    if m >= len(code):
                        ok = False
                        break
                    ins3 = code[m]
                    if (ins3 & 0x3F) == OP_SETLIST and _A(ins3) == 7 + k:
                        break
                    if (ins3 & 0x3F) == OP_NEWTABLE and _A(ins3) not in (7 + k,):
                        ok = False
                        break
                    m += 1
                    if m - j > 8:
                        ok = False
                        break
                if not ok:
                    break
                regs.append(7 + k)
                j = m + 1
            if not ok or len(regs) != 10 or regs != list(range(7, 17)):
                continue
            fin = code[j]
            if not ((fin & 0x3F) == OP_SETLIST and _A(fin) == 6 and _B(fin) == 10):
                continue
            st = code[j + 1]
            if not ((st & 0x3F) == OP_SETTABLE and _A(st) == 4 and _B(st) == 5 and _C(st) == 6):
                continue
            sites.append({"loadk": i, "newtable": i + 1, "entries": regs,
                          "setlist": j, "settable": j + 1, "hint": i + 1})
    return sites


def _const_py(p, idx):
    t, v = p.consts[idx]
    if t == "str":
        return v.decode()
    if t == "num":
        return v
    if t == "bool":
        return bool(v)
    if t == "nil":
        return None
    return repr(v)


def walk_gamemodes_entries(p, i):
    code = p.code
    entries = []
    expect_reg = 7
    j = i + 2
    while True:
        guard_s = 0
        while j < len(code):
            o = code[j] & 0x3F
            if o in (OP_LOADK, OP_LOADBOOL) or (o == OP_SETTABLE and _A(code[j]) == 6):
                j += 1
            else:
                break
            guard_s += 1
            if guard_s > 10:
                raise ValueError("scratch longo demais em %d" % j)
        if j >= len(code):
            break
        ins2 = code[j]
        op2 = ins2 & 0x3F
        if op2 == OP_NEWTABLE:
            if _A(ins2) != expect_reg:
                raise ValueError("NEWTABLE out of order at %d (R%d, expected R%d)"
                                 % (j, _A(ins2), expect_reg))
            reg = expect_reg
            vals = []
            m = j + 1
            guard = 0
            while True:
                ins3 = code[m]
                o3 = ins3 & 0x3F
                if o3 == OP_LOADK:
                    vals.append(_const_py(p, _Bx(ins3)))
                    m += 1
                elif o3 == OP_SETLIST and _A(ins3) == reg:
                    if _B(ins3) != len(vals):
                        raise ValueError("SETLIST B!=nvals at %d" % m)
                    m += 1
                    break
                else:
                    raise ValueError("unexpected pattern in entry (instr %d op %d)"
                                     % (m, o3))
                guard += 1
                if guard > 12:
                    raise ValueError("entry too long at %d" % j)
            entries.append(vals)
            expect_reg += 1
            j = m
        elif op2 == OP_LOADNIL:
            if _A(ins2) != expect_reg or _B(ins2) != expect_reg:
                raise ValueError("unexpected LOADNIL at %d" % j)
            entries.append(None)
            expect_reg += 1
            j += 1
        else:
            break
    return entries, j


def find_gamemodes_exact(p, fingerprint):
    str_idx = None
    for i, (t, v) in enumerate(p.consts):
        if t == "str" and v == K_GAMEMODES:
            str_idx = i
            break
    if str_idx is None:
        raise ValueError("missing GameModes const")
    code = p.code
    sites = []
    for i, ins in enumerate(code):
        if not ((ins & 0x3F) == OP_LOADK and _Bx(ins) == str_idx and _A(ins) == 5):
            continue
        if (code[i + 1] & 0x3F) != OP_NEWTABLE or _A(code[i + 1]) != 6:
            continue
        try:
            entries, j = walk_gamemodes_entries(p, i)
        except ValueError:
            continue
        if entries != fingerprint:
            continue
        n = len(entries)
        if _B(code[i + 1]) != n:
            continue
        fin = code[j]
        if not ((fin & 0x3F) == OP_SETLIST and _A(fin) == 6 and _B(fin) == n):
            continue
        st = code[j + 1]
        if not ((st & 0x3F) == OP_SETTABLE and _A(st) == 4 and _B(st) == 5
                and _C(st) == 6):
            continue
        last_reg = 6 + n
        sites.append({"loadk": i, "hint": i + 1, "entries": entries,
                      "n": n, "last_reg": last_reg,
                      "setlist": j, "settable": j + 1})
    return sites


def find_gamemodes_flex(p, fingerprint):
    str_idx = None
    for i, (t, v) in enumerate(p.consts):
        if t == "str" and v == K_GAMEMODES:
            str_idx = i
            break
    if str_idx is None:
        raise ValueError("missing GameModes const")
    code = p.code
    sites = []
    for i, ins in enumerate(code):
        if not ((ins & 0x3F) == OP_LOADK and _Bx(ins) == str_idx and _A(ins) == 5):
            continue
        if (code[i + 1] & 0x3F) != OP_NEWTABLE or _A(code[i + 1]) != 6:
            continue
        try:
            entries, j = walk_gamemodes_entries(p, i)
        except ValueError:
            continue
        if entries != fingerprint:
            continue
        n = len(entries)
        if _B(code[i + 1]) != n:
            continue
        k = j
        ok = True
        guard = 0
        while True:
            if k >= len(code):
                ok = False
                break
            o = code[k] & 0x3F
            if o == OP_SETLIST and _A(code[k]) == 6:
                break
            if o in (OP_LOADK, OP_LOADBOOL) or (o == OP_SETTABLE and _A(code[k]) == 6):
                k += 1
            else:
                ok = False
                break
            guard += 1
            if guard > 10:
                ok = False
                break
        if not ok:
            continue
        if _B(code[k]) != n:
            continue
        st = code[k + 1]
        if not ((st & 0x3F) == OP_SETTABLE and _A(st) == 4 and _B(st) == 5
                and _C(st) == 6):
            continue
        last_reg = 6 + n
        sites.append({"loadk": i, "hint": i + 1, "entries": entries,
                      "n": n, "last_reg": last_reg,
                      "setlist": k, "settable": k + 1})
    return sites


def apply_unused4(protos):
    p24 = protos[0].subs[0].subs[24]
    p24_lines = [p24.linedef, p24.lastlinedef]
    
    for ins in p24.code:
        if (ins & 0x3F) in (22, 31, 32):
            raise ValueError("unexpected jump in target prototype")
    have = {}
    for i, (t, v) in enumerate(p24.consts):
        if t == "str":
            have.setdefault(v, i)
    new_idx = {}
    for name in NEW_CONSTS:
        if name in have:
            new_idx[name] = have[name]
        else:
            new_idx[name] = len(p24.consts)
            p24.consts.append(("str", name))
    report = {"new_consts": {k.decode(): v for k, v in new_idx.items()
                             if k in NEW_CONSTS and k not in have},
              "sites": [], "p24_lines": p24_lines}
    
    plan = []
    for key, append, newB in ((b"RelaxShine", P12_APPEND, 11),
                              (b"Shine", P11_APPEND, 11)):
        found = find_gamemodes_site(p24, key)
        if len(found) != 1:
            raise ValueError("%r: %d sites (expected 1)" % (key, len(found)))
        s = found[0]
        plan.append((s["loadk"], key.decode(),
                     dict(s, start_reg=17), append, newB))
    for label, fp, exp in PC_JOBS:
        found = find_gamemodes_flex(p24, fp)
        if len(found) != exp:
            raise ValueError("%s: %d sites (expected %d)" % (label, len(found), exp))
        newB = len(fp) + 1
        for s in found:
            plan.append((s["loadk"], label, dict(s, start_reg=s["last_reg"] + 1),
                         [b"alphabeth"], newB))
    plan.sort(key=lambda t: -t[0])
    for _, label, s, append, newB in plan:
        start_reg = s["start_reg"]
        n_new = len(append)
        block = []
        for k, mode in enumerate(append):
            re_ = start_reg + k
            rt = start_reg + k + 1
            block.append(mk_NEWTABLE(re_, 1, 0))
            block.append(mk_LOADK(rt, new_idx[mode]))
            block.append(mk_SETLIST(re_, 1, 1))
        at = s["setlist"]
        
        if p24.maxstack < start_reg + n_new + 1:
            raise ValueError("maxstack too small for %s" % label)
        p24.code[at:at] = block
        if p24.lineinfo:
            p24.lineinfo[at:at] = [p24.lineinfo[at]] * n_new * 3
        p24.code[s["hint"]] = set_B(p24.code[s["hint"]], newB)
        
        p24.code[at + 3 * n_new] = set_B(p24.code[at + 3 * n_new], newB)
        fin = p24.code[at + 3 * n_new]
        if not ((fin & 0x3F) == OP_SETLIST and _A(fin) == 6 and _B(fin) == newB):
            raise ValueError("SETLIST post-check failed (%r)" % label)
        report["sites"].append(
            {"first": label, "loadk": s["loadk"],
             "insert_at": at, "added": n_new, "final_B": newB,
             "modes": [m.decode() for m in append]})
    return report


def _walk(p, out):
    out.append(p)
    for s in p.subs:
        _walk(s, out)


def audit_gamemodes(p, first_name):
    str_idx = next(i for i, (t, v) in enumerate(p.consts)
                   if t == "str" and v == K_GAMEMODES)
    first_idx = next(i for i, (t, v) in enumerate(p.consts)
                     if t == "str" and v == first_name)
    code = p.code
    for i, ins in enumerate(code):
        if (ins & 0x3F) == OP_LOADK and _Bx(ins) == str_idx and _A(ins) == 5:
            e0 = code[i + 2:i + 5]
            if not ((e0[0] & 0x3F) == OP_NEWTABLE and _A(e0[0]) == 7 and
                    (e0[1] & 0x3F) == OP_LOADK and _Bx(e0[1]) == first_idx):
                continue
            hint = _B(code[i + 1])
            entries, j = walk_gamemodes_entries(p, i)
            fin = code[j]
            if not ((fin & 0x3F) == OP_SETLIST and _A(fin) == 6):
                raise ValueError("SETLIST final missing")
            return {"hint_B": hint, "final_B": _B(fin), "entries": entries,
                    "loadk": i, "setlist": j}
    raise ValueError("site %r nao achado" % first_name)


def audit_gamemodes_prefix(p, prefix):
    str_idx = next(i for i, (t, v) in enumerate(p.consts)
                   if t == "str" and v == K_GAMEMODES)
    code = p.code
    hits = []
    for i, ins in enumerate(code):
        if not ((ins & 0x3F) == OP_LOADK and _Bx(ins) == str_idx and _A(ins) == 5):
            continue
        if (code[i + 1] & 0x3F) != OP_NEWTABLE or _A(code[i + 1]) != 6:
            continue
        try:
            entries, j = walk_gamemodes_entries(p, i)
        except ValueError:
            continue
        if entries[:len(prefix)] != prefix:
            continue
        fin = code[j]
        if not ((fin & 0x3F) == OP_SETLIST and _A(fin) == 6):
            continue
        hits.append({"hint_B": _B(code[i + 1]), "final_B": _B(fin),
                     "entries": entries, "loadk": i, "setlist": j})
    if len(hits) != 1:
        raise ValueError("prefixo: %d sites (esperava 1)" % len(hits))
    return hits[0]


def audit_sites(p, fingerprint):
    str_idx = next(i for i, (t, v) in enumerate(p.consts)
                   if t == "str" and v == K_GAMEMODES)
    code = p.code
    hits = []
    for i, ins in enumerate(code):
        if not ((ins & 0x3F) == OP_LOADK and _Bx(ins) == str_idx and _A(ins) == 5):
            continue
        if (code[i + 1] & 0x3F) != OP_NEWTABLE or _A(code[i + 1]) != 6:
            continue
        try:
            entries, j = walk_gamemodes_entries(p, i)
        except ValueError:
            continue
        if entries[:len(fingerprint)] != fingerprint:
            continue
        k = j
        ok = True
        guard = 0
        while True:
            if k >= len(code):
                ok = False
                break
            o = code[k] & 0x3F
            if o == OP_SETLIST and _A(code[k]) == 6:
                break
            if o in (OP_LOADK, OP_LOADBOOL) or (o == OP_SETTABLE and _A(code[k]) == 6):
                k += 1
            else:
                ok = False
                break
            guard += 1
            if guard > 10:
                ok = False
                break
        if not ok:
            continue
        fin = code[k]
        hits.append({"hint_B": _B(code[i + 1]), "final_B": _B(fin),
                     "entries": entries, "loadk": i, "setlist": k})
    return hits


WINICON_LINES = (66335, 89974)
WINICON_OLD = b"ico_warning"
WINICON_NEW = b"ico_progressmap"


def apply_winicon(protos):
    cands = []
    for si, s in enumerate(protos[0].subs[0].subs):
        has_c = any(t == "str" and v == b"CharacterMap" for t, v in s.consts)
        has_w = any(t == "str" and v == WINICON_OLD for t, v in s.consts)
        if has_c and has_w:
            cands.append((si, s))
    if not cands:
        raise ValueError("no prototype with CharacterMap/ico_warning consts")
    hits = []
    for si, p216 in cands:
        idx_warn, idx_charmap = None, None
        for i, (t, v) in enumerate(p216.consts):
            if t == "str" and v == WINICON_OLD and idx_warn is None:
                idx_warn = i
            if t == "str" and v == b"CharacterMap" and idx_charmap is None:
                idx_charmap = i
        code = p216.code
        for i, ins in enumerate(code):
            if not ((ins & 0x3F) == OP_LOADK and _A(ins) == 31 and _Bx(ins) == idx_charmap):
                continue
            if i + 2 >= len(code):
                continue
            if (code[i + 1] & 0x3F) != 28:
                continue
            ins2 = code[i + 2]
            if not ((ins2 & 0x3F) == OP_LOADK and _A(ins2) == 31 and _Bx(ins2) == idx_warn):
                continue
            hits.append((si, i + 2))
    if len(hits) != 1:
        raise ValueError("winicon site: %d matches (expected 1)" % len(hits))
    si, at = hits[0]
    p216 = protos[0].subs[0].subs[si]
    code = p216.code
    new_idx = None
    for i, (t, v) in enumerate(p216.consts):
        if t == "str" and v == WINICON_NEW:
            new_idx = i
            break
    if new_idx is None:
        new_idx = len(p216.consts)
        p216.consts.append(("str", WINICON_NEW))
    old = code[at]
    code[at] = (old & ~(0x3FFFF << 14)) | ((new_idx & 0x3FFFF) << 14)
    check = code[at]
    if (check & 0x3F) != OP_LOADK or _A(check) != 31 or _Bx(check) != new_idx:
        raise ValueError("LOADK post-check failed (winicon)")
    return {"proto_lines": [p216.linedef, p216.lastlinedef], "instr": at,
            "const_idx": new_idx, "icon": WINICON_NEW.decode()}


def verify_patch(orig_bytes, patched_bytes, d_code=63, p24_lines=(2987, 24018)):
    ho, po = parse(orig_bytes)
    hn, pn = parse(patched_bytes)
    lo, ln = [], []
    _walk(po[0], lo)
    _walk(pn[0], ln)
    if len(lo) != len(ln):
        raise ValueError("prototype count changed")
    changed = []
    for a, b in zip(lo, ln):
        diffs = []
        if ((a.linedef, a.lastlinedef) != (b.linedef, b.lastlinedef) or
                a.nups != b.nups or a.numparams != b.numparams):
            diffs.append("header")
        if [(t, v) for t, v in a.consts] != [(t, v) for t, v in b.consts]:
            diffs.append("consts %d->%d" % (len(a.consts), len(b.consts)))
        if a.code != b.code:
            diffs.append("code %d->%d" % (len(a.code), len(b.code)))
        if a.lineinfo != b.lineinfo:
            diffs.append("lineinfo")
        if diffs:
            changed.append(((a.linedef, a.lastlinedef), diffs))
    if len(changed) != 2:
        raise ValueError("changed prototype count = %d (expected 2)" % len(changed))
    if tuple(p24_lines) not in [c[0] for c in changed]:
        raise ValueError("gamemodes prototype not among changed: %r" % (changed,))
    a = [p for p in lo if (p.linedef, p.lastlinedef) == tuple(p24_lines)][0]
    b = [p for p in ln if (p.linedef, p.lastlinedef) == tuple(p24_lines)][0]
    
    if len(b.consts) - len(a.consts) != 1:
        raise ValueError("delta consts != 1")
    tail = [v for t, v in b.consts[-1:]]
    if tail != [b"alphabeth"]:
        raise ValueError("unexpected new consts: %r" % tail)
    if [(t, v) for t, v in a.consts] != [(t, v) for t, v in b.consts[:-1]]:
        raise ValueError("pre-existing consts changed")
    if len(b.code) - len(a.code) != d_code:
        raise ValueError("delta code != %d" % d_code)
    others = [c[0] for c in changed if c[0] != tuple(p24_lines)]
    if len(others) != 1:
        raise ValueError("winicon prototype not unique: %r" % (changed,))
    a2 = [p for p in lo if (p.linedef, p.lastlinedef) == others[0]][0]
    b2 = [p for p in ln if (p.linedef, p.lastlinedef) == others[0]][0]
    if len(b2.consts) - len(a2.consts) != 1:
        raise ValueError("p216: delta consts != 1")
    if [v for t, v in b2.consts[-1:]] != [WINICON_NEW]:
        raise ValueError("p216: unexpected new const")
    if [(t, v) for t, v in a2.consts] != [(t, v) for t, v in b2.consts[:-1]]:
        raise ValueError("p216: pre-existing consts changed")
    if len(a2.code) != len(b2.code):
        raise ValueError("p216: code size changed")
    dw = [i for i, (x, y) in enumerate(zip(a2.code, b2.code)) if x != y]
    if len(dw) != 1:
        raise ValueError("p216: %d words changed (expected 1)" % len(dw))
    ins = b2.code[dw[0]]
    if (ins & 0x3F) != OP_LOADK or _A(ins) != 31 or _Bx(ins) != len(b2.consts) - 1:
        raise ValueError("p216: changed word is not the expected LOADK")
    return {"protos_alterados": 2, "dConsts": 2, "dCode": d_code,
            "checks": "re-parse + diff estrutural OK"}