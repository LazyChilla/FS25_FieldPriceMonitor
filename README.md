<p align="center"><img src="images/preview.png" width="480" alt="FS25 Field Price Monitor"></p>

# FS25 Field Price Monitor 🌾💰

**A Farming Simulator 25 mod by [LazyChilla](https://github.com/lazychilla)**

Displays all purchasable farmlands in a dedicated ESC menu tab — sorted by net price, with BetterContracts discount integration, field condition, crop type, and warp-to-field.

---

## Features

- 📋 **ESC menu tab** — accessible at any time via the in-game menu
- 💶 **Buy price** for every purchasable farmland
- 🏷️ **BetterContracts discount** — amount + percentage per field (reads directly from savegame)
- 💚 **Net price** after discount
- 🌱 **Crop type** — what's currently growing on the field
- 🌍 **Field condition** — growth stage, plowed, cultivated, stubble, harvest ready, etc.
- 👤 **Owner** — which NPC owns the field
- 🔃 **Sortable columns** — click any column header to sort
- 🚜 **Warp to field** — teleport directly to the selected field
- 💰 **Account balance** displayed top-right

---

## Compatibility

- ✅ Farming Simulator 25
- ✅ https://github.com/Mmtrx/FS25_BetterContracts — discounts shown when installed and enabled
- ✅ Multiplayer — clients see `Host only` for discounts
- ✅ All maps

---

## Languages

🇩🇪 German · 🇬🇧 English · 🇫🇷 French · 🇵🇹 Portuguese · 🇪🇸 Spanish · 🇮🇹 Italian

---

## Installation

1. Download `FS25_FieldPriceMonitor.zip` from [Releases](../../releases)
2. Place the ZIP into your FS25 mods folder — **do not extract**
3. Activate in the mod manager and start your game

---

## Screenshots

<!-- Add screenshots here -->

---

## Changelog

### v1.0.0.2
- `g_farmCore` export (`getFieldDiscounts()`) now recalculates itself independently — no longer depends on the FieldPriceMonitor tab having been opened first
- GIANTS Testrunner compliance: `descVersion` 110, mod icon converted to 512×512 DXT1 (0 mipmaps)

### v1.0.0.1
- Bugfix: `onFrameClose()` was clearing `fieldData` when switching away from the tab, causing the `g_farmCore` export to report `not_ready`

### v1.0.0.0
- Initial release
- Field list with price, discount, net price, crop, condition, owner
- BetterContracts integration via savegame XML
- Warp to field
- Multiplayer support
- 6 languages: DE, EN, FR, PT, ES, IT

---

## Fehler melden / Reporting bugs

Bitte **über GitHub**, nicht über Kommentare auf Downloadseiten — dort geht es
unter und ich sehe es meist gar nicht.

👉 **[Fehler oder Wunsch melden / Report a bug or idea](../../issues/new/choose)**

Es gibt ein Formular, das dich durch die nötigen Angaben führt. **Das Wichtigste
ist die `log.txt`** — ohne sie kann dir niemand helfen. Sie liegt unter:

```
Dokumente\My Games\FarmingSimulator2025\log.txt
```

Bitte die **ganze Datei**, nicht nur die Zeile mit dem Fehler. Bilder kannst du
einfach ins Textfeld ziehen, GitHub lädt sie automatisch hoch.

*Please report via GitHub, not in comments on download sites. There is a form
that walks you through what is needed. The `log.txt` is the important part —
the whole file, not just the error line.*

---

## Credits

- **LazyChilla** — Idee, Code, Umsetzung / idea, code, implementation
- **Mmtrx** — BetterContracts-Integration mit freundlicher Genehmigung von Mmtrx
  ([FS25_BetterContracts](https://github.com/Mmtrx/FS25_BetterContracts)) /
  BetterContracts integration used with kind permission from Mmtrx

## Lizenz / License

Siehe [`LICENSE.md`](LICENSE.md). Kurzfassung: Code und Lösungen dürfen mit
Nennung von LazyChilla weiterverwendet werden, nicht gegen Geld, Weitergabe
unter denselben Bedingungen. Den Mod als Ganzes neu hochladen bitte vorher
kurz anfragen.

*Short version: reuse code and solutions with credit to LazyChilla, never for
money, pass it on under the same terms. Ask before re-uploading the mod as a
whole.*
