import argparse
import os
from PIL import Image

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Path to input PNG")
    parser.add_argument("--name", required=True, help="Target card ID (no extension)")
    parser.add_argument("--side", default="player", help="player or enemy")
    args = parser.parse_args()

    target_dir = f"c:/Users/Jerry/Desktop/Cardgame/battle_scene/assets/images/cards/{args.side}/"
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    target_path = os.path.join(target_dir, f"{args.name}.jpg")

    try:
        img = Image.open(args.input).convert("RGB")
        img.save(target_path, "JPEG", quality=90)
        print(f"Successfully converted and moved: {target_path}")
        # Clean up input if it's already in the target folder or temporary
        if os.path.exists(args.input) and args.input != target_path:
            # os.remove(args.input) # Optional: remove input png
            pass
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
