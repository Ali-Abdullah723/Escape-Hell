
from PIL import Image
import os
import math

folder = "64x64_faces"
tile_size = 64
columns = 10

files = sorted(f for f in os.listdir(folder) if f.lower().endswith(".png"))
rows = math.ceil(len(files) / columns)

sheet = Image.new("RGBA", (columns * tile_size, rows * tile_size))

for i, file in enumerate(files):
    img = Image.open(os.path.join(folder, file)).convert("RGBA")

    if img.size != (64, 64):
        print("Skipping:", file)
        continue

    x = (i % columns) * tile_size
    y = (i // columns) * tile_size
    sheet.paste(img, (x, y))

sheet.save("tilesheet_64.png")
print("Created tilesheet_64.png")
