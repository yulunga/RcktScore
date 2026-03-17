import os
import glob
from datetime import datetime, timedelta
from playwright.sync_api import sync_playwright

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
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium', args=['--diable-gpu'], ignore_default_args=['--mute-audio'], headless=True)
        page = browser.new_page()
        page.goto(url)
        
        # Generate output file name with current date
        date_string = datetime.now().strftime("%Y-%m-%d")
        output_file = os.path.join(output_folder, f"squashlevel_{date_string}.png")
        
        # Capture screenshot and save
        page.screenshot(path=output_file)
        print(f"Screenshot saved as {output_file}")
        
        browser.close()

# Example usage
if __name__ == "__main__":
    url = "https://squashlevels.com/boxes?clubid=398"  # URL of the webpage to capture
    output_folder = "/images/SquashLevels/"  # Output folder name
    
    # Delete old screenshots
    delete_old_screenshots(output_folder)
    
    # Capture new screenshot
    capture_webpage_screenshot(url, output_folder)