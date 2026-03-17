import os
import time
from datetime import datetime
import requests
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def capture_webpage_tables(url, output_folder):
    # Ensure that the output folder exists
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        print(f"Created output folder: {output_folder}")

    # Fetch the HTML content
    response = requests.get(url)
    html_content = response.text

    # Parse the HTML content
    soup = BeautifulSoup(html_content, 'html.parser')

    # Find all h2 elements with text "Box 1"
    box_headers = soup.find_all('h2', text='Box 1')

    if box_headers:
        # Configure the browser options
        options = webdriver.ChromeOptions()
        options.add_argument('--headless')  # Run in headless mode (without opening browser window)
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-gpu")
        options.add_argument('--disable-dev-shm-usage')

        # Initialize the Chrome WebDriver
        driver = webdriver.Chrome(options=options)

        try:
            for i, header in enumerate(box_headers):
                # Find the table following the current h2 element
                table = header.find_next('table', class_='box small_box')

                # Generate output file name with current date and table index
                date_string = datetime.now().strftime("%Y-%m-%d")
                output_file = os.path.join(output_folder, f"squashlevel_{date_string}_box{i+1}.png")

                # Check if a screenshot with the same date and index already exists
                if os.path.exists(output_file):
                    print(f"Deleting existing screenshot: {output_file}")
                    os.remove(output_file)

                # Open a new browser window
                driver.get(url)

                # Scroll to the table
                driver.execute_script("arguments[0].scrollIntoView();", table)

                # Wait for the page to load completely
                WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.TAG_NAME, 'body')))

                # Capture screenshot of the table
                driver.save_screenshot(output_file)
                print(f"Screenshot saved as {output_file}")

        finally:
            # Close the WebDriver session
            driver.quit()
    else:
        print("No 'Box 1' headers found in HTML content.")

# Example usage
if __name__ == "__main__":
    url = "https://squashlevels.com/boxes?clubid=398"  # URL of the webpage to capture
    output_folder = "mysite/static/images/SquashLevels/multi/"  # Output folder name

    capture_webpage_tables(url, output_folder)
