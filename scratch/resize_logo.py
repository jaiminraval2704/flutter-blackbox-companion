from PIL import Image
import sys

input_image = sys.argv[1]
output_dir = sys.argv[2]

try:
    img = Image.open(input_image)
    img_192 = img.resize((192, 192), Image.Resampling.LANCZOS)
    img_192.save(f"{output_dir}/Icon-192.png")
    
    img_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
    img_512.save(f"{output_dir}/Icon-512.png")
    
    img_16 = img.resize((32, 32), Image.Resampling.LANCZOS)
    img_16.save(f"{output_dir}/../favicon.png")
    print("Resized successfully.")
except Exception as e:
    print(f"Error: {e}")
