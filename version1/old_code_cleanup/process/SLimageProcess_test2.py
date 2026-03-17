from playwright.sync_api import sync_playwright
 
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto("https://squashlevels.com/boxes?clubid=398")
    print(page.title())
    date_string = datetime.now().strftime("%Y-%m-%d")
    page.screenshot(path="mysite/images/SquashLevels/screenshot{date_string}.png")
    browser.close()
