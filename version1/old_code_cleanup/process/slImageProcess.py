import os
import glob
import time
from datetime import datetime, timedelta
from selenium import webdriver
from PIL import Image

def delete_old_screenshots(output_folder):
    # Calculate the cutoff date (two days ago)
    cutoff_date = datetime.now() - timedelta(days=2)
    
    # List all screenshot files in the output folder
    screenshot_files = glob.glob(os.path.join(output_folder, "squashlevel_*.png"))
    
    # Iterate over the screenshot files and delete those older than the cutoff date
    for file in screenshot_files:
        creation_time = datetime.fromtimestamp(os.path.getctime(file))
        if creation_time < cutoff_date:
            os.remove(file)
            print(f"Deleted old screenshot: {file}")

def capture_webpage_screenshot(url, output_folder):
    # Ensure that the output folder exists
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        print(f"Created output folder: {output_folder}")

    # Configure the browser options
    options = webdriver.ChromeOptions()
    options.add_argument("--no-sandbox")
    options.add_argument("--headless")
    options.add_argument("--disable-gpu")
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument("--window-size=1920,1080")
    options.add_argument('--hide-scrollbars')

    # Initialize the Chrome WebDriver
    driver = webdriver.Chrome(options=options)
    
    try:
        # Open the web page
        driver.get(url)

        # Use JavaScript to get the full width and height of the webpage
        width = driver.execute_script("return Math.max( document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth );")
        height = driver.execute_script("return Math.max( document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight );")

        print("Height: " + str(height))
        print("Width: " + str(width))

        # Set the window size to match the entire webpage
        driver.set_window_size(width, height)
        
        #driver.add_cookie(cookie)
        cookies = driver.get_cookies()
        print("All cookies:", cookies)
        
        # Generate output file name with current date
        date_string = datetime.now().strftime("%Y-%m-%d")
        output_file = os.path.join(output_folder, f"squashlevel_{date_string}.png")
        
        # Check if a screenshot with the same date already exists
        if os.path.exists(output_file):
            print(f"Deleting existing screenshot: {output_file}")
            os.remove(output_file)

        # Capture screenshot of the webpage
        driver.save_screenshot(output_file)
        print(f"Screenshot saved as {output_file}")
        print(f"Screenshot saved to folder: {output_folder}")  # Print path of the output folder

        # Debugging: Print information about the file
        print(f"Screenshot should be saved as: {output_file}")
        print(f"File exists after saving: {os.path.exists(output_file)}")
        
        print(f"Screenshot saved as {output_file}")
        print(f"Screenshot saved to folder: {output_folder}")  # Print path of the output folder

        # Wait for 2 seconds
        time.sleep(2)

        # Open the saved image with Pillow
        image = Image.open(output_file)

        # Calculate the new dimensions after cropping
        # new_width equals image width subtract left and then subtract right 
        # new_height qauls image image height subtract top and then subtract bottom 
        new_width = image.width - 240 * 2
        new_height = image.height - 340 - 600

        # Crop the image
        # what it does crop(left, top, right, bottom)
        cropped_image = image.crop((480, 340, new_width, new_height))

        # Crop the image to remove 570 pixels from the top
        #######cropped_image = image.crop((0, 300, image.width, image.height))

        # Save the cropped image
        cropped_image.save(output_file)
        print(f"Cropped image saved as {output_file}")

    finally:
        # Close the WebDriver session
        driver.quit()

# Example usage
if __name__ == "__main__":
    url = "https://squashlevels.com/boxes?clubid=398"  # URL of the webpage to capture
    ###output_folder = "images/SquashLevels/"  # Output folder name
    output_folder = "mysite/static/images/SquashLevels/"  
    # Delete old screenshots
    delete_old_screenshots(output_folder)

    # Capture new screenshot
    capture_webpage_screenshot(url, output_folder)