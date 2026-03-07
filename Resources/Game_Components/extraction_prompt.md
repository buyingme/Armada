# Card Data Extraction Prompt

Use this prompt with a **vision-capable LLM** (Claude with images, GPT-4V, etc.) to extract structured data from Star Wars: Armada card images.

---

## How to Use

1. Copy the prompt below
2. Attach the card image(s) as PNG files
3. Paste the **verified example** (CR90 Corvette A) so the LLM knows the exact output format
4. The LLM returns JSON for each card

---

## Prompt

```
You are extracting structured game data from Star Wars: Armada card images.

For each card image I provide, output a JSON object following the exact schema and conventions shown in the verified example below.

### CRITICAL RULES:

1. **Dice pools**: Express as {"RED": n, "BLUE": n, "BLACK": n}. Only include colors with count > 0.
2. **Defense tokens**: List each token individually. If a ship has 2 Redirect tokens, list ["REDIRECT", "REDIRECT"].
3. **Navigation chart**: One array per speed level. Index 0 = speed 1. Each inner array has one entry per joint at that speed.
   - Speed 1 has 1 joint, speed 2 has 2 joints, speed 3 has 3 joints, speed 4 has 4 joints.
   - Values: 0 = no yaw allowed (dash on card), 1 = one click (I on card), 2 = two clicks (II on card).
4. **Upgrade slots**: Read left-to-right from the upgrade bar at the bottom of the ship card. Use these exact names:
   COMMANDER, TITLE, OFFICER, WEAPONS_TEAM, SUPPORT_TEAM, OFFENSIVE_RETROFIT,
   DEFENSIVE_RETROFIT, ORDNANCE, ION_CANNONS, TURBOLASERS, FLEET_COMMAND,
   FLEET_SUPPORT, EXPERIMENTAL_RETROFIT, SUPER_WEAPON
5. **Shields**: The blue numbers positioned around the ship silhouette in each hull zone (front/left/right/rear).
6. **Battery armament**: The colored dice icons in each firing arc on the card.
7. **Anti-squadron armament**: The dice shown in the anti-squadron section (usually has a small squadron icon indicator).
8. **Hull**: The large number typically shown center-bottom area of the card.
9. **Command/Squadron/Engineering values**: The three numbers on the left stat column.
10. **Point cost**: The number in the lower-right corner.
11. **Ship size**: CR90 and Nebulon-B = SMALL. Victory-class = MEDIUM.
12. **Squadron keywords**: Read the keyword text on the card (e.g., "Bomber", "Escort", "Swarm").
13. **Faction**: Rebel ships have the Rebel Alliance icon. Imperial ships have the Imperial crest.

### VERIFIED EXAMPLE (use this as your reference format):

[PASTE THE VERIFIED CR90A EXAMPLE JSON HERE]

### Now extract data from the attached card image(s).

Output one JSON object per card. If multiple cards are attached, output a JSON array.
For ship cards, use the "ship_card" schema. For squadron cards, use the "squadron_card" schema.
```

---

## After Extraction

1. **Verify** each card's numbers against the physical card or a trusted database
2. Save verified data to `Resources/Game_Components/card_data/ships/` or `squadrons/`
3. I will convert the verified JSON into Godot `.tres` Resource files
