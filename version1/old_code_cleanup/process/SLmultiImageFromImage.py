import os
import cv2
import pytesseract
from datetime import datetime

try:
    # Get current date string
    date_string = datetime.now().strftime("%Y-%m-%d")
    print(f"Current date string: {date_string}")

    # Define input folder
    input_folder = "mysite/static/images/SquashLevels/"
    print(f"Input folder: {input_folder}")

    # Construct the path to the image file
    image_path = os.path.join(input_folder, f"squashlevel_{date_string}.png")
    print(f"Image path: {image_path}")

    # Check if the image file exists
    if os.path.exists(image_path):
        print(f"Processing image: {image_path}")

        # Load image
        image = cv2.imread(image_path)
        print("Image loaded successfully.")

        # Preprocess the image if necessary (e.g., convert to grayscale)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        print("Image preprocessed.")

        # Perform OCR using Tesseract
        custom_config = r'--oem 3 --psm 6'  # Adjust OCR configuration if needed
        text = pytesseract.image_to_string(gray, config=custom_config)
        print("OCR performed.")

        # Split the text into lines
        lines = text.split('\n')
        print("Text split into lines.")

        # Initialize variables
        headings = []
        current_heading = None
        heading_start = None

        # Find the bounding boxes of each heading
        for i, line in enumerate(lines):
            # Assuming headings are named "Box 1", "Box 2", etc.
            if line.startswith("Box") and line.split()[1].isdigit():
                if current_heading is not None:
                    headings.append((current_heading, heading_start, i))
                current_heading = line
                heading_start = i
        print("Headings found.")

        # Define output folder
        output_folder = os.path.join(input_folder, "multi")
        print(f"Output folder: {output_folder}")

        # Create the directory to save cropped images if it doesn't exist
        os.makedirs(output_folder, exist_ok=True)
        print("Output folder created.")

        # Crop the image based on the bounding boxes
        for idx, (heading, start, end) in enumerate(headings):
            if idx < len(headings) - 1:
                next_start = end
                next_end = headings[idx + 1][1]
            else:
                next_start = end
                next_end = len(lines)
            
            # Crop the image
            cropped_image = image[start:end, :]
            
            # Save the cropped image with current date in filename
            output_path = os.path.join(output_folder, f'squashlevel_{date_string}_{idx}.png')
            cv2.imwrite(output_path, cropped_image)
            print(f"Cropped image saved: {output_path}")

        print("Script execution completed.")

    else:
        print("Error: Image file not found.")

except Exception as e:
    print(f"Error: {e}")
