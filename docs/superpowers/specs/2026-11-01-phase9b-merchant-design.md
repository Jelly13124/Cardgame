# Phase 9b: Merchant as Inventory and Entries

The second half of phase 9 (9a, events, is done). The merchant follows the STS2 structure:
an inventory of entries, each entry owning its stock, its price and its purchase. Content
stays ours: our card, tool and relic pools, our base prices, Charm and the A4 surcharge.
The user asked for 9b on 2026-11-01 and left the decisions to follow STS2.

## Goal

A merchant visit builds one `MerchantInventory`. Every slot is an entry that knows what it
holds, what it costs right now and how to sell itself. A price runs through one pipeline
(base, variance and sale, then Charm, ascension and relic hooks). Buying an entry clears it,
or refills it when a hook asks, and tells every other entry so their prices can change.
Card removal costs more each time it is used in a run. A reload inside the shop shows the
same stock, the same prices and the same sold slots.

## STS2 mapping

| STS2 | Here |
|---|---|
| `Entities.Merchant.MerchantInventory` | `core/run/merchant/merchant_inventory.gd` |
| `MerchantEntry` | `core/run/merchant/merchant_entry.gd` (base) |
| `MerchantCardEntry` | `core/run/merchant/merchant_card_entry.gd` |
| `MerchantPotionEntry` | `core/run/merchant/merchant_tool_entry.gd` (tools are our potions) |
| `MerchantRelicEntry` | `core/run/merchant/merchant_relic_entry.gd` |
| `MerchantCardRemovalEntry` | `core/run/merchant/merchant_card_removal_entry.gd` |
| `PurchaseStatus` | `MerchantEntry.Status` |
| `Hook.ModifyMerchantPrice` | run listener `modify_merchant_price(entry, price) -> float` |
| `Hook.ShouldRefillMerchantEntry` | run listener `should_refill_merchant_entry(entry) -> bool` |
| `Hook.AfterItemPurchased` | run event `after_item_purchased({entry, gold_spent})` |
| `ExtraFields.CardShopRemovalsUsed` | `RunState.merchant_removals_used` |
| `NMerchantRoom` | `ui/shop/merchant_room.gd` (+ `.tscn`, renamed from `shop_scene`) |
| `NMerchantSlot` / `NMerchantCard` / `NMerchantRelic` / `NMerchantPotion` | `ui/shop/merchant_slot.gd` |
| `NMerchantCardRemoval` | `ui/shop/merchant_card_removal.gd` |

`core/run/shop_stock.gd` is removed; so are the dead legacy and "stall" builders in the shop
scene.

## Stock

`content/economy/merchant_economy.json` (numbers ours):

```json
{
  "id": "merchant_economy",
  "card_slots": [
    {"type": "attack"}, {"type": "attack"}, {"type": "skill"}, {"type": "skill"},
    {"type": "ability"}, {"rarity": "rare"}
  ],
  "card_rarity_weights": {"common": 55, "uncommon": 38, "rare": 7},
  "card_price": {"common": 65, "uncommon": 110, "rare": 175},
  "card_price_variance": [0.95, 1.05],
  "relic_count": 3,
  "relic_rarity_weights": {"common": 55, "uncommon": 33, "rare": 12},
  "relic_price": {"common": 135, "uncommon": 165, "rare": 200},
  "relic_price_variance": [0.85, 1.15],
  "tool_count": 3,
  "tool_price": 50,
  "tool_price_variance": [0.95, 1.05],
  "remove_card_price": 75,
  "remove_card_price_step": 25
}
```

- Cards: STS2 stocks five character cards by type (attack, attack, skill, skill, power) and
  two colorless cards by rarity. We have no colorless pool, so the sixth slot is a rare from
  the hero's pool. A typed slot rolls a rarity by weight among the rarities that still have
  cards of that type; if the type has none left, any type. A slot never repeats a card
  already in the inventory. One random typed slot is on sale at half price.
- Relics: three slots; each rolls a rarity by weight among the rarities with unowned shop
  relics (unique relics never appear), and never repeats a relic already stocked.
- Tools: three distinct tools from the run's tool pool.
- Base cost: `round(price × variance)`, rolled once when the slot fills; a card on sale
  halves it (integer division). Rolls use the run's `shops` stream, so a seed gives the same
  stock.
- Card removal: `remove_card_price + remove_card_price_step × merchant_removals_used`. It can
  be used once per visit.

## Entries

`MerchantEntry` (RefCounted):

- `owner` (the run facade), `inventory`, `base_cost: int`.
- `cost() -> int`: `MerchantInventory.modify_price(self, base_cost)`.
- `enough_gold() -> bool`, `is_stocked() -> bool` (virtual).
- `try_purchase() -> Status`: out of stock → `FAILURE_OUT_OF_STOCK`; not enough gold →
  `FAILURE_GOLD`; `_on_purchase()` returns false → `FAILURE_SPACE`. On success it spends the
  cost, refills (`_restock_after_purchase`) if any run listener's
  `should_refill_merchant_entry` says yes, otherwise clears (`_clear_after_purchase`), emits
  the run event `after_item_purchased`, then `purchase_completed`. A failure emits
  `purchase_failed(status)`.
- Signals `purchase_completed(entry)`, `purchase_failed(status)`, `entry_updated`.
- `to_dict()` / `from_dict(d)`.

Subclasses: the card entry (`slot`, `card_id`, `rarity`, `on_sale`), the tool entry
(`tool_id`; `FAILURE_SPACE` when the backpack is full), the relic entry (`relic_id`;
`FAILURE_SPACE` if already owned) and the removal entry (`used`;
`try_remove(uid) -> Status` replaces `try_purchase`, removes the card, counts the removal).

## Inventory and prices

`MerchantInventory.create(owner) -> MerchantInventory` fills every entry and wires each
`purchase_completed` to `_update_entries()`, which emits `entry_updated` on all of them (a
price hook may now answer differently). `all_entries()`, `to_dict()`, `from_dict(owner, d)`.

`modify_price(entry, base) -> int`, the one price owner:

1. `× RunManager.charm_shop_mult()` (Charm, floored as today);
2. `× price_mult` while A4 `merchant_surcharge` is active;
3. each run listener's `modify_merchant_price(entry, price)`;
4. `ceil`, never below 0.

## Save

`RunState.shop_stock[node_id]` holds `inventory.to_dict()`. The new
`RunState.merchant_removals_used: int` is saved. Run save v6 converts a v5 stock
(`{cards, tools, relics, remove_price}` with `price` and `sold`) to entry dictionaries: the
old price becomes the base cost, `sold` becomes out of stock, and cards get `slot: -1`, no
sale. `merchant_removals_used` starts at 0.

## UI

- `merchant_room.gd` builds or restores the inventory, mounts the top bar, art, shelves, the
  removal service and the leave button, and saves the inventory after every purchase.
  The layout stays as it is today; the layered shop art from the Codex list replaces it later.
- `merchant_slot.gd` is one slot for a card, tool or relic entry. It shows the item and the
  price: red when the player cannot afford it, a "SALE" tag on a sale card and SOLD once it
  is out of stock. It listens to `entry_updated`, `purchase_completed` and gold changes.
- `merchant_card_removal.gd` is the service button with the current price, plus the deck
  picker modal.

## Testing

`tests/merchant_inventory_test.gd`:

- composition: six cards (two attacks, two skills, one ability, one rare), all distinct;
  three distinct unowned non-unique relics; three distinct tools;
- exactly one typed card on sale, at half its pre-sale cost;
- base costs inside their variance;
- the price pipeline: Charm, A4 and a test listener's `modify_merchant_price`;
- purchase statuses: not enough gold, out of stock, backpack full, relic already owned;
- a refill listener restocks a bought slot with a different card and no sale;
  `after_item_purchased` reaches run listeners;
- removal: the price rises by the step after a use, also in the next merchant, and the entry
  is used for this visit;
- round trip: `to_dict` → `from_dict` gives the same entries and costs;
- v5 → v6 stock migration;
- the same seed gives the same inventory.

Existing tests move with the code: the state round-trip test (sold offers stay sold), the
shop UI contracts, and the golden stock sequence, whose shop and market part is re-recorded
because the shop now draws different numbers from the shared `shops` stream.

## Out of scope

- New relics that use the hooks (no current content discounts or refills).
- A colorless card pool.
- The merchant dialogue and character animation.
- The layered shop art.
