import os
import glob
import time
from datetime import datetime, timedelta
from PIL import Image


def crop_and_save(input_image_path, output_directory, height):
    image = Image.open(input_image_path)
    img_width, img_height = image.size
    current_height = 0
    index = 1

    if not os.path.exists(input_image_path):
        print(f"Error: Input image file '{input_image_path}' does not exist.")
        return
    
    print(f"Screenshot saved as {input_image_path}")
    print(f"Screenshot saved to folder: {output_directory}") 

    while current_height < img_height:
        

        # Define the cropping box
        box = (0, current_height, img_width, min(current_height + height, img_height))
        cropped_img = image.crop(box)

        # Save the cropped image
        cropped_img.save(os.path.join(output_directory, f"squashlevel_{date_string}_{index}.png"))

        # Move to the next crop position
        current_height += height
        index += 1

if __name__ == "__main__":

    date_string = datetime.now().strftime("%Y-%m-%d")
    #input_image_path = "mysite/static/images/SquashLevels/"  # Change this to your input image path
    output_directory = "mysite/static/images/SquashLevels/"  # Change this to your output directory

    input_image_path = os.path.join(output_directory, f"squashlevel_{date_string}.png")
    height = 200  # Change this to your desired height for each cropped image

    # Create the output directory if it doesn't exist
    os.makedirs(output_directory, exist_ok=True)

    crop_and_save(input_image_path, output_directory, height)
