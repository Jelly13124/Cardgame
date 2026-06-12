#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate browsable, CATEGORIZED HTML catalogs (cards / relics / equipment /
enemies) + a keyword glossary, from the project's JSON data + content/UI
translation CSVs. One-off reference tooling — output lands in docs/catalog_html/.
Re-run any time data changes:  python scripts/gen_catalog_html.py"""
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
combat_tr = load_tr("ui_combat.csv")
battle_tr = load_tr("ui_battle.csv")
uiequip_tr = load_tr("ui_equipment.csv")


def esc(s):
    return html.escape(str(s))


def cap(s):
    return str(s).replace("_", " ").title()


RARITY = {"common": "#9aa3ad", "uncommon": "#4fb0ff", "rare": "#ffcf45", "boss": "#ff6b6b"}
POLARITY = {"yin": "#6fa8dc", "yang": "#ff9e4a", "neutral": "#9c917c"}

STYLE = """
:root{--bg:#13100c;--panel:#1d1812;--panel2:#262019;--line:#3a3026;--gold:#ffcf45;--txt:#e7ddc8;--dim:#9c917c;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--txt);font-family:"Segoe UI",system-ui,sans-serif;}
header{position:sticky;top:0;background:linear-gradient(180deg,#1d1812,#171309);border-bottom:2px solid var(--line);padding:16px 28px;z-index:10;}
h1{margin:0;font-size:23px;color:var(--gold);letter-spacing:.5px}
.sub{color:var(--dim);font-size:13px;margin-top:4px}
.bar{margin-top:12px;display:flex;gap:10px;flex-wrap:wrap;align-items:center}
input[type=search]{background:#0e0b07;border:1px solid var(--line);color:var(--txt);padding:8px 12px;border-radius:8px;min-width:220px;font-size:14px}
.tag{font-size:12px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:3px 10px;cursor:pointer;user-select:none}
.tag.active{color:#13100c;background:var(--gold);border-color:var(--gold)}
.nav{display:flex;gap:8px;margin-top:10px;flex-wrap:wrap}
.nav a{color:var(--dim);text-decoration:none;font-size:13px;border:1px solid var(--line);padding:4px 12px;border-radius:6px}
.nav a:hover,.nav a.cur{color:var(--gold);border-color:var(--gold)}
.section{padding:18px 28px 2px;}
.section h2{color:var(--gold);font-size:17px;margin:0 0 2px;border-bottom:1px solid var(--line);padding-bottom:6px}
.section .cnt{color:var(--dim);font-size:12px;font-weight:400}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(290px,1fr));gap:14px;padding:14px 28px 4px;}
.card{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--line);border-radius:10px;padding:14px 16px;transition:.12s}
.card:hover{background:var(--panel2);transform:translateY(-2px)}
.card h3{margin:0 0 2px;font-size:17px}
.zh{color:var(--gold);font-size:15px;font-weight:600}
.meta{display:flex;gap:6px;flex-wrap:wrap;margin:8px 0;font-size:11px}
.pill{border-radius:5px;padding:2px 8px;background:#0e0b07;border:1px solid var(--line);color:var(--dim)}
.desc{color:#c9bfa8;font-size:13px;font-style:italic;margin:6px 0}
.eff{list-style:none;padding:0;margin:8px 0 0}
.eff li{font-size:13px;color:var(--txt);padding:3px 0 3px 16px;position:relative}
.eff li:before{content:"▸";position:absolute;left:0;color:var(--gold)}
.eff li.bonus:before{content:"☯";color:#ffcf45}
.hp{color:#ff8b6b;font-weight:700}
.kw{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:12px;padding:14px 28px}
.kwc{background:var(--panel);border:1px solid var(--line);border-left:5px solid var(--line);border-radius:9px;padding:12px 15px}
.kwc h3{margin:0 0 4px;font-size:16px}
.kwc .en{color:var(--dim);font-size:12px;font-weight:400}
.kwc p{margin:6px 0 0;font-size:13px;color:#d7cdb6;line-height:1.5}
.kwc .zhd{color:#c9bfa8;font-size:12.5px;margin-top:3px}
"""

SEARCH_JS = """
const q=document.getElementById('q');
function applyFilter(){
  const t=(q?q.value:'').toLowerCase();
  const af=document.querySelector('.tag.active');
  const f=af?af.dataset.f:''; const fk=af?af.dataset.k:'';
  document.querySelectorAll('.card,.kwc').forEach(c=>{
    const okt=!t||(c.dataset.search||'').includes(t);
    const okf=!f||(c.dataset[fk]===f);
    c.style.display=(okt&&okf)?'':'none';
  });
  document.querySelectorAll('.section').forEach(s=>{
    const any=[...s.parentElement.querySelectorAll('.card,.kwc')];
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


def nav(cur):
    items = [("cards.html", "Cards 卡牌"), ("relics.html", "Relics 遗物"),
             ("equipment.html", "Equipment 装备"), ("enemies.html", "Enemies 敌人"),
             ("gems.html", "Gems 宝石"),
             ("affixes.html", "Affixes 词条"), ("keywords.html", "Keywords 关键词")]
    return '<div class="nav">' + "".join(
        '<a class="%s" href="%s">%s</a>' % ("cur" if f == cur else "", f, esc(t))
        for f, t in items
    ) + "</div>"


def page(fname, title, subtitle, controls, body, count):
    h = f"""<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title><style>{STYLE}</style></head><body>
<header><h1>{esc(title)}</h1><div class="sub">{esc(subtitle)} · <span>{count} entries</span></div>
{nav(fname)}
<div class="bar"><input id="q" type="search" placeholder="Search / 搜索…">{controls}</div>
</header>
{body}
<script>{SEARCH_JS}</script></body></html>"""
    with open(os.path.join(OUT, fname), "w", encoding="utf-8") as f:
        f.write(h)
    print("wrote", fname, f"({count})")


def rar_pill(r):
    c = RARITY.get(r, "#9aa3ad")
    return f'<span class="pill" style="color:{c};border-color:{c}">{esc(r)}</span>'


def pol_pill(p):
    if p == "neutral" or p == "":
        return ""
    c = POLARITY.get(p, "#9c917c")
    label = {"yin": "☯ Yin 阴", "yang": "☯ Yang 阳"}.get(p, p)
    return f'<span class="pill" style="color:{c};border-color:{c}">{esc(label)}</span>'


def section(title, count, cards_html):
    if not cards_html:
        return ""
    return (f'<div class="section"><h2>{esc(title)} <span class="cnt">({count})</span></h2></div>'
            f'<div class="grid">{cards_html}</div>')


# ── Effect formatting ──────────────────────────────────────────────────────
def fmt_effect(e):
    t = e.get("type", "")
    amt = e.get("amount")
    stacks = e.get("stacks")
    status = e.get("status", "")
    mult = e.get("mult", e.get("multiplier"))
    m = {
        "deal_damage": f"Deal {amt} damage (+STR)",
        "deal_damage_all": f"Deal {amt} to ALL enemies (+STR)",
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
        "flip_polarity": "Flip polarity (Yin↔Yang)",
        "gain_gold": f"Gain {amt} gold",
        "heal": f"Heal {amt} HP",
        "deal_damage_block_mult": f"Deal damage = Block×{mult}",
        "double_strength": "Double your Strength",
        "lose_hp": f"Lose {amt} HP",
    }
    if t in m:
        return m[t]
    if t.startswith("gain_"):
        return f"Gain {amt} {cap(t[5:])}"
    return cap(t)


# ── Cards (grouped by type) ─────────────────────────────────────────────────
def card_block(cid, d):
    tr = cards_tr.get(f"CARD_{cid}_TITLE", {})
    zh = tr.get("zh", "")
    en = tr.get("en", d.get("title", cid))
    rar = str(d.get("rarity", "common")).lower()
    ctype = str(d.get("type", "skill"))
    cost = d.get("cost", 0)
    pol = str(d.get("polarity", "neutral")).lower()
    effs = "".join(f"<li>{esc(fmt_effect(e))}</li>" for e in d.get("effects", []))
    for be in d.get("matched_bonus", []) or []:
        effs += f'<li class="bonus">If matched: {esc(fmt_effect(be))}</li>'
    dtr = cards_tr.get(f"CARD_{cid}_DESC", {})
    desc = dtr.get("zh") or d.get("description", "")
    c = POLARITY.get(pol) if pol in ("yin", "yang") else RARITY.get(rar, "#9aa3ad")
    search = f"{cid} {en} {zh} {ctype} {rar} {pol}".lower()
    return (
        f'<div class="card" data-search="{esc(search)}" data-rarity="{rar}" data-polarity="{pol}" style="border-left-color:{c}">'
        f'<h3>{esc(en)} <span class="zh">{esc(zh)}</span></h3>'
        f'<div class="meta"><span class="pill">⚡ {esc(cost)}</span><span class="pill">{esc(cap(ctype))}</span>'
        f'{rar_pill(rar)}{pol_pill(pol)}<span class="pill" style="color:#6b6256">{esc(cid)}</span></div>'
        f'<div class="desc">{esc(desc)}</div><ul class="eff">{effs}</ul></div>'
    )


def build_cards():
    items = load_json_dir("battle_scene/card_info/player")
    items.sort(key=lambda kv: (kv[0].replace("_plus", ""), kv[0].endswith("_plus")))
    groups = {"attack": [], "skill": [], "ability": []}
    for cid, d in items:
        groups.setdefault(str(d.get("type", "skill")), []).append(card_block(cid, d))
    body = ""
    for key, label in [("attack", "Attacks 攻击"), ("skill", "Skills 技能"), ("ability", "Abilities 能力")]:
        body += section(label, len(groups.get(key, [])), "".join(groups.get(key, [])))
    controls = (
        "".join(f'<span class="tag" data-k="rarity" data-f="{r}">{r}</span>'
                for r in ("common", "uncommon", "rare"))
        + '<span class="tag" data-k="polarity" data-f="yin">yin 阴</span>'
        + '<span class="tag" data-k="polarity" data-f="yang">yang 阳</span>'
    )
    page("cards.html", "Cards · 卡牌", "All player cards (incl. + upgrades), grouped by type",
         controls, body, len(items))


# ── Relics (grouped by rarity) ──────────────────────────────────────────────
def fmt_relic_eff(e):
    # Clearer labels for the typed relic effects; everything else auto-humanizes.
    ty = e.get("type", "")
    if ty == "apply_status":
        label = "Apply " + cap(e.get("status", ""))
    elif ty == "grant_card_keyword":
        label = "Grant Card Keyword (" + cap(e.get("keyword", "")) + ")"
    elif ty == "add_bleed":
        label = "Add %d Bleed" % int(e.get("amount", 1))
    else:
        label = cap(ty)
    return "%s → %s" % (cap(e.get("trigger", "")), label)


def relic_block(rid, d):
    en = relics_tr.get(f"RELIC_{rid}_TITLE", {}).get("en", d.get("title", rid))
    zh = relics_tr.get(f"RELIC_{rid}_TITLE", {}).get("zh", "")
    desc = relics_tr.get(f"RELIC_{rid}_DESC", {}).get("zh") or d.get("description", "")
    rar = str(d.get("rarity", "common")).lower()
    c = RARITY.get(rar, "#9aa3ad")
    trg = "".join(f"<li>{esc(fmt_relic_eff(e))}</li>" for e in d.get("effects", []))
    search = f"{rid} {en} {zh} {rar}".lower()
    return (f'<div class="card" data-search="{esc(search)}" data-rarity="{rar}" style="border-left-color:{c}">'
            f'<h3>{esc(en)} <span class="zh">{esc(zh)}</span></h3>'
            f'<div class="meta">{rar_pill(rar)}<span class="pill" style="color:#6b6256">{esc(rid)}</span></div>'
            f'<div class="desc">{esc(desc)}</div><ul class="eff">{trg}</ul></div>')


def build_relics():
    items = load_json_dir("run_system/data/relics")
    by = {"common": [], "uncommon": [], "rare": []}
    for rid, d in items:
        by.setdefault(str(d.get("rarity", "common")).lower(), []).append(relic_block(rid, d))
    body = ""
    for r in ("common", "uncommon", "rare"):
        body += section(f"{r.title()} 遗物", len(by.get(r, [])), "".join(by.get(r, [])))
    controls = "".join(f'<span class="tag" data-k="rarity" data-f="{r}">{r}</span>'
                       for r in ("common", "uncommon", "rare"))
    page("relics.html", "Relics · 遗物", "Passive run relics, grouped by rarity", controls, body, len(items))


# ── Gems (run-scoped socketables) ───────────────────────────────────────────
def build_gems():
    items = load_json_dir("run_system/data/gems")
    cards = []
    for gid, d in items:
        en = cards_tr.get(f"GEM_{gid}_TITLE", {}).get("en", d.get("title", gid))
        zh = cards_tr.get(f"GEM_{gid}_TITLE", {}).get("zh", "")
        desc = cards_tr.get(f"GEM_{gid}_DESC", {}).get("zh", "")
        eff = "".join(f"<li>{esc(fmt_effect(e))}</li>" for e in d.get("effects", []))
        search = f"{gid} {en} {zh}".lower()
        cards.append(
            f'<div class="card" data-search="{esc(search)}" style="border-left-color:#6fd3ff">'
            f'<h3>{esc(en)} <span class="zh">{esc(zh)}</span></h3>'
            f'<div class="meta"><span class="pill" style="color:#6fd3ff">{esc(gid)}</span>'
            f'<span class="pill" style="color:#6b6256">on play</span></div>'
            f'<div class="desc">{esc(desc)}</div><ul class="eff">{eff}</ul></div>')
    body = section("Gems 宝石", len(cards), "".join(cards))
    page("gems.html", "Gems · 宝石",
         "Run-scoped socketable gems — slot 1 into a card; effects fire when the card is played",
         "", body, len(items))


# ── Equipment (grouped by slot) + sets ──────────────────────────────────────
def build_equipment():
    items = load_json_dir("run_system/data/equipment")
    by = {}
    for eid, d in items:
        en = equip_tr.get(f"EQUIP_{eid}_NAME", {}).get("en", d.get("name", eid))
        zh = equip_tr.get(f"EQUIP_{eid}_NAME", {}).get("zh", "")
        desc = equip_tr.get(f"EQUIP_{eid}_DESC", {}).get("zh") or d.get("description", "")
        rar = str(d.get("rarity", "common")).lower()
        slot = str(d.get("slot", "?"))
        c = RARITY.get(rar, "#9aa3ad")
        bl = "".join(f"<li>+{v} {cap(k)}</li>" for k, v in d.get("bonuses", {}).items())
        setname = d.get("set_id", d.get("set", ""))
        setline = (f'<div class="meta"><span class="pill" style="color:{RARITY["rare"]}">Set: {esc(cap(setname))}</span></div>'
                   if setname else "")
        search = f"{eid} {en} {zh} {slot} {rar} {setname}".lower()
        by.setdefault(slot, []).append(
            f'<div class="card" data-search="{esc(search)}" data-rarity="{rar}" style="border-left-color:{c}">'
            f'<h3>{esc(en)} <span class="zh">{esc(zh)}</span></h3>'
            f'<div class="meta"><span class="pill">{esc(cap(slot))}</span>{rar_pill(rar)}'
            f'<span class="pill" style="color:#6b6256">{esc(eid)}</span></div>{setline}'
            f'<div class="desc">{esc(desc)}</div><ul class="eff">{bl}</ul></div>')
    body = ""
    for slot in ["head", "chest", "weapon", "hands", "accessory"]:
        if slot in by:
            body += section(f"{cap(slot)} 装备", len(by[slot]), "".join(by[slot]))
    for slot in by:
        if slot not in ["head", "chest", "weapon", "hands", "accessory"]:
            body += section(f"{cap(slot)} 装备", len(by[slot]), "".join(by[slot]))
    # set bonuses
    sets = load_json_dir("run_system/data/equipment_sets")
    set_cards = []
    for sid, d in sets:
        tiers = "".join(f"<li><b>{t.get('count')}-piece:</b> {esc(t.get('label',''))}</li>"
                        for t in d.get("tiers", []))
        set_cards.append(
            f'<div class="card" data-search="{esc((sid+" "+d.get("name","")).lower())}" style="border-left-color:{RARITY["rare"]}">'
            f'<h3>{esc(d.get("name",sid))}</h3><div class="desc">{esc(d.get("description",""))}</div>'
            f'<ul class="eff">{tiers}</ul></div>')
    body += section("Set Bonuses 套装效果", len(set_cards), "".join(set_cards))
    controls = "".join(f'<span class="tag" data-k="rarity" data-f="{r}">{r}</span>'
                       for r in ("common", "uncommon", "rare"))
    page("equipment.html", "Equipment · 装备", "Gear by slot + set bonuses", controls, body, len(items))


# ── Enemies (grouped Normal / Elite / Boss) ─────────────────────────────────
def fmt_move(a):
    t = a.get("type", "")
    amt = a.get("amount")
    lbl = a.get("label", "")
    parts = {
        "attack": f"Attack {amt}", "attack_all": f"Attack ALL {amt}",
        "attack_status": f"Attack {amt} + {cap(a.get('status',''))} {a.get('stacks',1)}",
        "block": f"Block {amt}", "heal": f"Heal {amt}",
        "buff_self": f"Buff self: {cap(a.get('status',''))} {a.get('stacks',1)}",
        "telegraph": "Telegraph (wind-up)",
        "summon": f"Summon: {', '.join(a.get('enemy_ids',[]))}",
    }
    base = parts.get(t, cap(t))
    flags = " ⚡interruptible" if a.get("interruptible") else ""
    return f"{esc(lbl)}  —  {esc(base)}{flags}"


def enemy_block(eid, d, is_boss):
    en = enemy_tr.get(f"ENEMY_{eid}_NAME", {}).get("en", d.get("name", eid))
    zh = enemy_tr.get(f"ENEMY_{eid}_NAME", {}).get("zh", "")
    hp = d.get("max_health", "?")
    c = RARITY["boss"] if is_boss else "#9aa3ad"
    moves = "".join(f"<li>{fmt_move(a)}</li>" for a in d.get("action_pattern", []))
    ph = ""
    for p in d.get("phases", []):
        below = int(float(p.get("hp_below", 0)) * 100)
        oe = "".join(f"<li>⤷ on enter: {fmt_move(a)}</li>" for a in p.get("on_enter", []))
        pm = "".join(f"<li>{fmt_move(a)}</li>" for a in p.get("action_pattern", []))
        ph += f'<li style="color:{RARITY["boss"]}"><b>Phase @ HP &lt; {below}%</b></li>{oe}{pm}'
    bp = f'<span class="pill" style="color:{RARITY["boss"]};border-color:{RARITY["boss"]}">BOSS</span>' if is_boss else ""
    search = f"{eid} {en} {zh}".lower()
    return (f'<div class="card" data-search="{esc(search)}" style="border-left-color:{c}">'
            f'<h3>{esc(en)} <span class="zh">{esc(zh)}</span></h3>'
            f'<div class="meta"><span class="pill hp">❤ {esc(hp)} HP</span>{bp}'
            f'<span class="pill" style="color:#6b6256">{esc(eid)}</span></div>'
            f'<ul class="eff">{moves}{ph}</ul></div>')


def build_enemies():
    items = load_json_dir("battle_scene/card_info/enemy")
    bosses = {"rust_titan", "ash_warden", "junkyard_tyrant"}
    # heuristic: summon-only adds vs normal — keep simple: bosses vs rest
    normal, boss = [], []
    for eid, d in items:
        (boss if eid in bosses else normal).append((eid, d))
    normal.sort(key=lambda kv: kv[1].get("max_health", 0))
    boss.sort(key=lambda kv: kv[1].get("max_health", 0))
    body = section("Normal & Adds 普通/召唤", len(normal),
                   "".join(enemy_block(e, d, False) for e, d in normal))
    body += section("Bosses 首领", len(boss), "".join(enemy_block(e, d, True) for e, d in boss))
    page("enemies.html", "Enemies · 敌人", "All enemies + boss phases, grouped by tier", "", body, len(items))


# ── Keyword glossary ────────────────────────────────────────────────────────
STATUS_COLORS = {
    "bleed": "#ff4d5e", "burn": "#ff6619", "weak": "#b380e6", "vulnerable": "#f27333",
    "double_damage": "#33ccff", "stun": "#f2f24d",
    "regen": "#4dffa6", "thorns": "#b3bfcc", "frail": "#9980b3", "dodge": "#99f2ff",
    "metallicize": "#b8ccdb", "feel_no_pain": "#8cccf2", "dark_embrace": "#b86bdb",
}
STATUSES = ["bleed", "burn", "weak", "vulnerable", "double_damage", "stun",
            "regen", "thorns", "frail", "dodge",
            "metallicize", "feel_no_pain", "dark_embrace"]


def kw_card(name_en, name_zh, desc_en, desc_zh, color, ident=""):
    search = f"{name_en} {name_zh} {ident}".lower()
    return (f'<div class="kwc" data-search="{esc(search)}" style="border-left-color:{color}">'
            f'<h3 style="color:{color}">{esc(name_zh) or esc(name_en)} '
            f'<span class="en">{esc(name_en)}</span></h3>'
            f'<p>{esc(desc_en)}</p><p class="zhd">{esc(desc_zh)}</p></div>')


def build_keywords():
    body = []
    # Statuses
    cards = []
    for s in STATUSES:
        up = s.upper()
        nm = combat_tr.get(f"UI_COMBAT_STATUS_{up}", {})
        ds = combat_tr.get(f"UI_COMBAT_STATUS_{up}_DESC", {})
        cards.append(kw_card(nm.get("en", cap(s)), nm.get("zh", ""),
                             ds.get("en", ""), ds.get("zh", ""),
                             STATUS_COLORS.get(s, "#9c917c"), s))
    body.append(f'<div class="section"><h2>Status Effects 状态效果 <span class="cnt">({len(cards)})</span></h2></div>'
                f'<div class="kw">{"".join(cards)}</div>')
    # Yin/Yang mechanic
    pol = []
    yin = battle_tr.get("UI_BATTLE_POLARITY_YIN", {})
    yang = battle_tr.get("UI_BATTLE_POLARITY_YANG", {})
    harm = battle_tr.get("UI_BATTLE_POLARITY_HARMONY", {})
    pol.append(kw_card(yin.get("en", "Yin"), yin.get("zh", "阴"),
                       "Active on odd turns (Feng Shui Master). While Yin, your Yin cards trigger their matched bonus.",
                       "奇数回合激活(风水大师)。阴态下,打出阴卡会触发其匹配加成。", POLARITY["yin"], "yin polarity"))
    pol.append(kw_card(yang.get("en", "Yang"), yang.get("zh", "阳"),
                       "Active on even turns. While Yang, your Yang cards trigger their matched bonus.",
                       "偶数回合激活。阳态下,打出阳卡会触发其匹配加成。", POLARITY["yang"], "yang polarity"))
    pol.append(kw_card(harm.get("en", "Harmony"), harm.get("zh", "阴阳调和"),
                       "Reached by experiencing BOTH Yin and Yang in one turn (via flip cards). Grants +1 Energy and draws 1 card, and for the rest of the turn BOTH Yin and Yang cards count as matched.",
                       "一回合内同时经历阴与阳(靠翻转卡)即进入。立即 +1 能量并抽 1 张,且该回合内阴卡阳卡都视为匹配。", POLARITY["yang"], "harmony"))
    pol.append(kw_card("Flip Polarity", "翻转极性",
                       "Card effect that switches your current polarity (Yin↔Yang) — the tool for reaching Harmony.",
                       "翻转当前阴阳极性的卡牌效果 —— 触发调和的关键。", "#ffcf45", "flip polarity taiji"))
    body.append('<div class="section"><h2>Yin-Yang Mechanic 阴阳机制 <span class="cnt">(4)</span></h2></div>'
                f'<div class="kw">{"".join(pol)}</div>')
    # Card keywords
    kw = []
    ex = battle_tr.get("UI_BATTLE_KEYWORD_EXHAUST", {})
    re = battle_tr.get("UI_BATTLE_KEYWORD_RETAIN", {})
    kw.append(kw_card("Exhaust", "消耗", "The card is removed from the deck for the rest of the combat after it's played.",
                      "打出后,该卡在本场战斗中被移除(不再回到牌库)。", "#cfa9ff", "exhaust"))
    kw.append(kw_card("Retain", "保留", "The card is NOT discarded at end of turn — it stays in your hand.",
                      "回合结束时不弃掉,保留在手牌中。", "#9ec1ff", "retain"))
    body.append('<div class="section"><h2>Card Keywords 卡牌关键词 <span class="cnt">(2)</span></h2></div>'
                f'<div class="kw">{"".join(kw)}</div>')
    # Attributes
    attrs = [
        ("Strength", "力量", "Each point adds +1 to attack-card damage.", "每点 +1 攻击牌伤害。", "#ff8033"),
        ("Constitution", "体质", "Each point adds +1 to Block gained.", "每点 +1 获得的格挡。", "#4da6ff"),
        ("Intelligence", "智力", "Each point: +5% XP gained from combat (level up faster).", "每点：战斗获得的经验 +5%（升级更快）。", "#b366ff"),
        ("Luck", "幸运", "Each point: +3% crit chance, +3% gold, +1.5% loot rarity.", "每点:+3% 暴击、+3% 金币、+1.5% 战利品稀有度。", "#ffe14d"),
        ("Charm", "魅力", "Each point: -2% shop prices (down to -40%); gates some event options.", "每点:-2% 商店价格(最低 -40%);并解锁部分事件选项。", "#ff80c4"),
    ]
    ac = [kw_card(e, z, de, dz, c, e.lower()) for e, z, de, dz, c in attrs]
    body.append('<div class="section"><h2>Attributes 属性 <span class="cnt">(5)</span></h2></div>'
                f'<div class="kw">{"".join(ac)}</div>')
    total = len(STATUSES) + 4 + 2 + 5  # statuses + yin/yang(4) + card keywords(2) + attributes(5)
    page("keywords.html", "Keywords · 关键词", "Statuses, Yin-Yang, card keywords & attributes",
         "", "".join(body), total)


# ── Affixes (parsed from affix_pool.gd) ─────────────────────────────────────
def _affix_text(affix_type, value):
    key = "UI_AFFIX_" + affix_type.upper()
    tr = uiequip_tr.get(key, {})
    en = tr.get("en", "") or ("%+d %s" % (value, cap(affix_type)))
    zh = tr.get("zh", "")
    fmt = lambda s: s.replace("{value}", str(value)).replace("{abs}", str(abs(value)))
    return fmt(en), fmt(zh)


def build_affixes():
    import re
    src = open(os.path.join(ROOT, "run_system", "core", "affix_pool.gd"), encoding="utf-8").read()

    def parse_block(name):
        m = re.search(name + r"\s*:=\s*\[(.*?)\]", src, re.S)
        if not m:
            return []
        return [(t, int(v)) for t, v in
                re.findall(r'\{"type":\s*"([^"]+)",\s*"value":\s*(-?\d+)\}', m.group(1))]

    positive = parse_block("POSITIVE")
    curse = parse_block("CURSE")
    cm = re.search(r'AFFIX_COUNT\s*:=\s*\{([^}]*)\}', src)
    count_rule = cm.group(1).strip() if cm else "common:1, uncommon:2, rare:2"

    def affix_card(t, v, curse_flag):
        en, zh = _affix_text(t, v)
        color = "#e0584c" if curse_flag else "#5fd06a"
        search = ("%s %s %s" % (t, en, zh)).lower()
        return (f'<div class="kwc" data-search="{esc(search)}" style="border-left-color:{color}">'
                f'<h3 style="color:{color}">{esc(zh) or esc(en)} <span class="en">{esc(en)}</span></h3>'
                f'<div class="meta"><span class="pill" style="color:#6b6256">{esc(t)}</span>'
                f'<span class="pill">value {esc(v)}</span></div></div>')

    body = []
    note = (f'<div class="section"><h2>Positive Affixes 正向词条 '
            f'<span class="cnt">({len(positive)}) · roll count by rarity: {esc(count_rule)} '
            f'(cursed = +1 positive + 1 curse)</span></h2></div>')
    body.append(note)
    body.append('<div class="kw">' + "".join(affix_card(t, v, False) for t, v in positive) + "</div>")
    body.append(f'<div class="section"><h2>Curse Affixes 诅咒词条 <span class="cnt">({len(curse)}) · '
                f'high-ascension cursed gear: 1 curse + up to 3 positives</span></h2></div>')
    body.append('<div class="kw">' + "".join(affix_card(t, v, True) for t, v in curse) + "</div>")
    page("affixes.html", "Affixes · 词条",
         "Equipment affixes — rolled per item by rarity (common 1 / uncommon 2 / rare 2 + set)",
         "", "".join(body), len(positive) + len(curse))


build_cards()
build_relics()
build_gems()
build_equipment()
build_enemies()
build_affixes()
build_keywords()
print("Done ->", OUT)
