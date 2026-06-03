#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate browsable HTML catalogs (cards / relics / equipment / enemies)
from the project's JSON data + content translation CSVs. One-off reference
tooling — output lands in docs/catalog_html/. Re-run any time data changes."""
import csv
import glob
import html
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "catalog_html")
os.makedirs(OUT, exist_ok=True)


def load_tr(rel):
    d = {}
    p = os.path.join(ROOT, "assets", "translations", rel)
    if not os.path.exists(p):
        return d
    with open(p, encoding="utf-8-sig") as f:
        r = csv.reader(f)
        next(r, None)
        for row in r:
            if len(row) >= 3:
                d[row[0]] = {"en": row[1], "zh": row[2]}
    return d


def load_json_dir(rel):
    items = []
    for path in sorted(glob.glob(os.path.join(ROOT, rel, "*.json"))):
        try:
            with open(path, encoding="utf-8") as f:
                items.append((os.path.basename(path)[:-5], json.load(f)))
        except Exception as e:
            print("skip", path, e)
    return items


cards_tr = load_tr("content_cards.csv")
relics_tr = load_tr("content_relics.csv")
equip_tr = load_tr("content_equipment.csv")
enemy_tr = load_tr("content_enemies.csv")


def esc(s):
    return html.escape(str(s))


def cap(s):
    return str(s).replace("_", " ").title()


RARITY = {
    "common": "#9aa3ad",
    "uncommon": "#4fb0ff",
    "rare": "#ffcf45",
    "boss": "#ff6b6b",
}

STYLE = """
:root{--bg:#13100c;--panel:#1d1812;--panel2:#262019;--line:#3a3026;--gold:#ffcf45;--txt:#e7ddc8;--dim:#9c917c;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--txt);font-family:"Segoe UI",system-ui,sans-serif;}
header{position:sticky;top:0;background:linear-gradient(180deg,#1d1812,#171309);border-bottom:2px solid var(--line);padding:18px 28px;z-index:10;}
h1{margin:0;font-size:24px;color:var(--gold);letter-spacing:.5px}
.sub{color:var(--dim);font-size:13px;margin-top:4px}
.bar{margin-top:12px;display:flex;gap:10px;flex-wrap:wrap;align-items:center}
input[type=search]{background:#0e0b07;border:1px solid var(--line);color:var(--txt);padding:8px 12px;border-radius:8px;min-width:240px;font-size:14px}
.tag{font-size:12px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:3px 10px;cursor:pointer;user-select:none}
.tag.active{color:#13100c;background:var(--gold);border-color:var(--gold)}
.nav{display:flex;gap:8px;margin-top:10px}
.nav a{color:var(--dim);text-decoration:none;font-size:13px;border:1px solid var(--line);padding:4px 12px;border-radius:6px}
.nav a:hover{color:var(--gold);border-color:var(--gold)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:14px;padding:22px 28px;}
.card{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--line);border-radius:10px;padding:14px 16px;transition:.12s}
.card:hover{background:var(--panel2);transform:translateY(-2px)}
.card h3{margin:0 0 2px;font-size:17px}
.zh{color:var(--gold);font-size:15px;font-weight:600}
.meta{display:flex;gap:8px;flex-wrap:wrap;margin:8px 0;font-size:11px}
.pill{border-radius:5px;padding:2px 8px;background:#0e0b07;border:1px solid var(--line);color:var(--dim)}
.desc{color:#c9bfa8;font-size:13px;font-style:italic;margin:6px 0}
.eff{list-style:none;padding:0;margin:8px 0 0}
.eff li{font-size:13px;color:var(--txt);padding:3px 0 3px 16px;position:relative}
.eff li:before{content:"▸";position:absolute;left:0;color:var(--gold)}
.section-title{grid-column:1/-1;color:var(--gold);font-size:16px;border-bottom:1px solid var(--line);padding-bottom:6px;margin:10px 0 0}
.hp{color:#ff8b6b;font-weight:700}
.count{color:var(--dim);font-size:13px}
"""

SEARCH_JS = """
const q=document.getElementById('q');
function applyFilter(){
  const t=(q?q.value:'').toLowerCase();
  const af=document.querySelector('.tag.active');
  const rf=af?af.dataset.f:'';
  document.querySelectorAll('.card').forEach(c=>{
    const okt=!t||c.dataset.search.includes(t);
    const okr=!rf||c.dataset.rarity===rf;
    c.style.display=(okt&&okr)?'':'none';
  });
}
if(q)q.addEventListener('input',applyFilter);
document.querySelectorAll('.tag').forEach(tag=>tag.addEventListener('click',()=>{
  const was=tag.classList.contains('active');
  document.querySelectorAll('.tag').forEach(t=>t.classList.remove('active'));
  if(!was)tag.classList.add('active');
  applyFilter();
}));
"""

NAV = (
    '<div class="nav">'
    '<a href="cards.html">Cards 卡牌</a>'
    '<a href="relics.html">Relics 遗物</a>'
    '<a href="equipment.html">Equipment 装备</a>'
    '<a href="enemies.html">Enemies 敌人</a>'
    "</div>"
)


def page(fname, title, subtitle, controls, body, count):
    h = f"""<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title><style>{STYLE}</style></head><body>
<header><h1>{esc(title)}</h1><div class="sub">{esc(subtitle)} · <span class="count">{count} entries</span></div>
{NAV}
<div class="bar"><input id="q" type="search" placeholder="Search / 搜索…">{controls}</div>
</header>
<div class="grid">{body}</div>
<script>{SEARCH_JS}</script></body></html>"""
    with open(os.path.join(OUT, fname), "w", encoding="utf-8") as f:
        f.write(h)
    print("wrote", fname, f"({count})")


def rar_pill(r):
    c = RARITY.get(r, "#9aa3ad")
    return f'<span class="pill" style="color:{c};border-color:{c}">{esc(r)}</span>'


# ── Effect formatting (cards) ──────────────────────────────────────────────
def fmt_effect(e):
    t = e.get("type", "")
    amt = e.get("amount")
    stacks = e.get("stacks")
    status = e.get("status", "")
    mult = e.get("mult", e.get("multiplier"))
    m = {
        "deal_damage": f"Deal {amt} damage (+STR)",
        "deal_damage_all": f"Deal {amt} damage to ALL enemies (+STR)",
        "deal_damage_str_mult": f"Deal STR×{mult} damage",
        "gain_block": f"Gain {amt} Block (+CON)",
        "gain_energy": f"Gain {amt} Energy",
        "draw_cards": f"Draw {amt} card(s)",
        "apply_status": f"Apply {stacks} {cap(status)} to target",
        "apply_status_self": f"Gain {stacks} {cap(status)}",
        "apply_status_all": f"Apply {stacks} {cap(status)} to ALL",
        "apply_stun": f"Apply {stacks or amt} Stun",
        "apply_stun_all": f"Apply {stacks or amt} Stun to ALL",
        "scale_damage_by_attacks": f"Deal {e.get('base',0)}+{e.get('per',0)}×attacks this turn",
        "exhaust_self": "Exhaust (removed for combat)",
    }
    if t in m:
        return m[t]
    if t.startswith("gain_"):
        return f"Gain {amt} {cap(t[5:])}"
    extra = []
    for k in ("amount", "stacks", "status", "mult", "multiplier"):
        if e.get(k) not in (None, ""):
            extra.append(f"{k}={e[k]}")
    return cap(t) + (f" ({', '.join(extra)})" if extra else "")


# ── Cards ──────────────────────────────────────────────────────────────────
def build_cards():
    items = load_json_dir("battle_scene/card_info/player")
    # base first, then _plus grouped right after via stable sort by base id
    items.sort(key=lambda kv: (kv[0].replace("_plus", ""), kv[0].endswith("_plus")))
    body = []
    for cid, d in items:
        tr = cards_tr.get(f"CARD_{cid}_TITLE", {})
        zh = tr.get("zh", "")
        en = tr.get("en", d.get("title", cid))
        rar = str(d.get("rarity", "common")).lower()
        ctype = d.get("type", "skill")
        cost = d.get("cost", 0)
        effs = "".join(f"<li>{esc(fmt_effect(e))}</li>" for e in d.get("effects", []))
        dtr = cards_tr.get(f"CARD_{cid}_DESC", {})
        desc = dtr.get("zh") or d.get("description", "")
        c = RARITY.get(rar, "#9aa3ad")
        search = f"{cid} {en} {zh} {ctype} {rar}".lower()
        body.append(
            f'<div class="card" data-search="{esc(search)}" data-rarity="{rar}" style="border-left-color:{c}">'
            f'<h3>{esc(en)} <span class="zh">{esc(zh)}</span></h3>'
            f'<div class="meta"><span class="pill">⚡ {esc(cost)}</span>'
            f'<span class="pill">{esc(cap(ctype))}</span>{rar_pill(rar)}'
            f'<span class="pill" style="color:#6b6256">{esc(cid)}</span></div>'
            f'<div class="desc">{esc(desc)}</div>'
            f'<ul class="eff">{effs}</ul></div>'
        )
    controls = "".join(
        f'<span class="tag" data-f="{r}">{r}</span>' for r in ("common", "uncommon", "rare")
    )
    page("cards.html", "Cards · 卡牌", "All player cards (incl. + upgrades)", controls,
         "".join(body), len(items))


# ── Relics ───────────────────────────────────────────────────────────────────
def build_relics():
    items = load_json_dir("run_system/data/relics")
    items.sort(key=lambda kv: (str(kv[1].get("rarity", "")), kv[0]))
    body = []
    for rid, d in items:
        en = relics_tr.get(f"RELIC_{rid}_TITLE", {}).get("en", d.get("title", rid))
        zh = relics_tr.get(f"RELIC_{rid}_TITLE", {}).get("zh", "")
        desc = relics_tr.get(f"RELIC_{rid}_DESC", {}).get("zh") or d.get("description", "")
        rar = str(d.get("rarity", "common")).lower()
        c = RARITY.get(rar, "#9aa3ad")
        trg = "".join(
            f"<li>{esc(cap(e.get('trigger','')))} → {esc(cap(e.get('type','')))}</li>"
            for e in d.get("effects", [])
        )
        search = f"{rid} {en} {zh} {rar}".lower()
        body.append(
            f'<div class="card" data-search="{esc(search)}" data-rarity="{rar}" style="border-left-color:{c}">'
            f'<h3>{esc(en)} <span class="zh">{esc(zh)}</span></h3>'
            f'<div class="meta">{rar_pill(rar)}<span class="pill" style="color:#6b6256">{esc(rid)}</span></div>'
            f'<div class="desc">{esc(desc)}</div>'
            f'<ul class="eff">{trg}</ul></div>'
        )
    controls = "".join(
        f'<span class="tag" data-f="{r}">{r}</span>' for r in ("common", "uncommon", "rare")
    )
    page("relics.html", "Relics · 遗物", "Passive run relics", controls, "".join(body), len(items))


# ── Equipment (+ set bonuses) ─────────────────────────────────────────────────
def build_equipment():
    items = load_json_dir("run_system/data/equipment")
    items.sort(key=lambda kv: (str(kv[1].get("slot", "")), str(kv[1].get("rarity", "")), kv[0]))
    body = []
    for eid, d in items:
        en = equip_tr.get(f"EQUIP_{eid}_NAME", {}).get("en", d.get("name", eid))
        zh = equip_tr.get(f"EQUIP_{eid}_NAME", {}).get("zh", "")
        desc = equip_tr.get(f"EQUIP_{eid}_DESC", {}).get("zh") or d.get("description", "")
        rar = str(d.get("rarity", "common")).lower()
        slot = d.get("slot", "")
        c = RARITY.get(rar, "#9aa3ad")
        bonuses = d.get("bonuses", {})
        bl = "".join(f"<li>+{v} {cap(k)}</li>" for k, v in bonuses.items())
        setname = d.get("set", "")
        setline = f'<div class="meta"><span class="pill" style="color:{RARITY["rare"]}">Set: {esc(cap(setname))}</span></div>' if setname else ""
        search = f"{eid} {en} {zh} {slot} {rar} {setname}".lower()
        body.append(
            f'<div class="card" data-search="{esc(search)}" data-rarity="{rar}" style="border-left-color:{c}">'
            f'<h3>{esc(en)} <span class="zh">{esc(zh)}</span></h3>'
            f'<div class="meta"><span class="pill">{esc(cap(slot))}</span>{rar_pill(rar)}'
            f'<span class="pill" style="color:#6b6256">{esc(eid)}</span></div>'
            f"{setline}"
            f'<div class="desc">{esc(desc)}</div>'
            f'<ul class="eff">{bl}</ul></div>'
        )
    # Equipment sets section
    sets = load_json_dir("run_system/data/equipment_sets")
    set_body = ['<div class="section-title">Set Bonuses · 套装效果</div>']
    for sid, d in sets:
        tiers = "".join(
            f"<li><b>{t.get('count')}-piece:</b> {esc(t.get('label',''))}</li>"
            for t in d.get("tiers", [])
        )
        set_body.append(
            f'<div class="card" data-search="{esc((sid+" "+d.get("name","")).lower())}" data-rarity="" style="border-left-color:{RARITY["rare"]}">'
            f'<h3>{esc(d.get("name",sid))}</h3>'
            f'<div class="desc">{esc(d.get("description",""))}</div>'
            f'<ul class="eff">{tiers}</ul></div>'
        )
    controls = "".join(
        f'<span class="tag" data-f="{r}">{r}</span>' for r in ("common", "uncommon", "rare")
    )
    page("equipment.html", "Equipment · 装备", "Gear items + set bonuses", controls,
         "".join(body) + "".join(set_body), len(items))


# ── Enemies ──────────────────────────────────────────────────────────────────
def fmt_move(a):
    t = a.get("type", "")
    amt = a.get("amount")
    lbl = a.get("label", "")
    parts = {
        "attack": f"Attack {amt}",
        "attack_all": f"Attack ALL {amt}",
        "attack_status": f"Attack {amt} + {cap(a.get('status',''))} {a.get('stacks',1)}",
        "block": f"Block {amt}",
        "heal": f"Heal {amt}",
        "buff_self": f"Buff self: {cap(a.get('status',''))} {a.get('stacks',1)}",
        "telegraph": "Telegraph (wind-up)",
        "summon": f"Summon: {', '.join(a.get('enemy_ids',[]))}",
    }
    base = parts.get(t, cap(t))
    flags = " ⚡interruptible" if a.get("interruptible") else ""
    return f"{esc(lbl)}  —  {esc(base)}{flags}"


def build_enemies():
    items = load_json_dir("battle_scene/card_info/enemy")
    bosses = {"rust_titan", "ash_warden", "junkyard_tyrant"}
    items.sort(key=lambda kv: (kv[0] in bosses, kv[1].get("max_health", 0)))
    body = []
    for eid, d in items:
        en = enemy_tr.get(f"ENEMY_{eid}_NAME", {}).get("en", d.get("name", eid))
        zh = enemy_tr.get(f"ENEMY_{eid}_NAME", {}).get("zh", "")
        hp = d.get("max_health", "?")
        is_boss = eid in bosses
        rar = "boss" if is_boss else "common"
        c = RARITY["boss"] if is_boss else "#9aa3ad"
        moves = "".join(f"<li>{fmt_move(a)}</li>" for a in d.get("action_pattern", []))
        phases_html = ""
        for ph in d.get("phases", []):
            below = int(float(ph.get("hp_below", 0)) * 100)
            on_enter = "".join(f"<li>⤷ on enter: {fmt_move(a)}</li>" for a in ph.get("on_enter", []))
            pm = "".join(f"<li>{fmt_move(a)}</li>" for a in ph.get("action_pattern", []))
            phases_html += (
                f'<li style="color:{RARITY["boss"]}"><b>Phase @ HP &lt; {below}%</b></li>{on_enter}{pm}'
            )
        bp = f'<span class="pill" style="color:{RARITY["boss"]};border-color:{RARITY["boss"]}">BOSS</span>' if is_boss else ""
        search = f"{eid} {en} {zh}".lower()
        body.append(
            f'<div class="card" data-search="{esc(search)}" data-rarity="{rar}" style="border-left-color:{c}">'
            f'<h3>{esc(en)} <span class="zh">{esc(zh)}</span></h3>'
            f'<div class="meta"><span class="pill hp">❤ {esc(hp)} HP</span>{bp}'
            f'<span class="pill" style="color:#6b6256">{esc(eid)}</span></div>'
            f'<ul class="eff">{moves}{phases_html}</ul></div>'
        )
    controls = '<span class="tag" data-f="boss">boss</span><span class="tag" data-f="common">normal</span>'
    page("enemies.html", "Enemies · 敌人", "All enemies + boss phases", controls,
         "".join(body), len(items))


build_cards()
build_relics()
build_equipment()
build_enemies()
print("Done ->", OUT)
