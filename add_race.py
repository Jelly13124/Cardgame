import os
import json

base_path = r"c:\Users\Jerry\Desktop\Cardgame\battle_scene\card_info"
folders = ["player/units", "enemy"]

for folder in folders:
    folder_path = os.path.join(base_path, folder)
    if not os.path.exists(folder_path): continue
    for f in os.listdir(folder_path):
        if f.endswith(".json"):
            fp = os.path.join(folder_path, f)
            with open(fp, "r", encoding="utf-8") as file:
                try:
                    data = json.load(file)
                except Exception as e:
                    print(f"Error loading {fp}: {e}")
                    continue
            
            # Add race attribute
            if data.get("type", "unit") in ["unit", "hero", "building"]:
                if "race" not in data:
                    data["race"] = "robot"
                    with open(fp, "w", encoding="utf-8") as file:
                        json.dump(data, file, indent=4)
                    print(f"Updated {f}")
