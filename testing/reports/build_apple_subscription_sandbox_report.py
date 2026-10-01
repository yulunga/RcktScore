from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_ALIGN_VERTICAL, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path("/Users/glennrowe/Development/Projects/RcktScore")
TMP = Path("/private/tmp/rcktscore-apple-subscription-report-assets")
OUTPUT = ROOT / "testing/reports/RcktScore-Apple-Subscription-Sandbox-Test-Report-2026-09-11.docx"
DOWNLOADS = Path("/Users/glennrowe/Downloads")
CLIPBOARD = Path("/private/var/folders/r8/zw83q2nx6fnd6b1d4v25by6m0000gn/T")
BRAND_LOGO = ROOT / "frontend/public/branding/logo/brand-logo.png"

INK = "102A43"
NAVY = "0B4F88"
BRAND_BLUE = "2F80ED"
BRAND_PINK = "EC5EA8"
PALE_BLUE = "EEF5FC"
PALE_PINK = "FDF0F7"
PALE_GREY = "F7FAFC"
MID_GREY = "486581"
LIGHT_GREY = "D9E2EC"
GREEN = "1FC16B"
AMBER = "9A6700"


def set_cell_shading(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_border(cell, color: str = LIGHT_GREY, size: str = "6") -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = "w:" + edge
        node = borders.find(qn(tag))
        if node is None:
            node = OxmlElement(tag)
            borders.append(node)
        node.set(qn("w:val"), "single")
        node.set(qn("w:sz"), size)
        node.set(qn("w:color"), color)


def set_cell_margins(cell, top=110, start=120, bottom=110, end=120) -> None:
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for margin, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn("w:" + margin))
        if node is None:
            node = OxmlElement("w:" + margin)
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def add_page_number(paragraph) -> None:
    paragraph.add_run("Page ")
    run = paragraph.add_run()
    fld_char1 = OxmlElement("w:fldChar")
    fld_char1.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = " PAGE "
    fld_char2 = OxmlElement("w:fldChar")
    fld_char2.set(qn("w:fldCharType"), "end")
    run._r.extend([fld_char1, instr_text, fld_char2])


def set_paragraph_bottom_border(paragraph, color: str = BRAND_BLUE, size: str = "8") -> None:
    p_pr = paragraph._p.get_or_add_pPr()
    p_bdr = p_pr.find(qn("w:pBdr"))
    if p_bdr is None:
        p_bdr = OxmlElement("w:pBdr")
        p_pr.append(p_bdr)
    bottom = p_bdr.find(qn("w:bottom"))
    if bottom is None:
        bottom = OxmlElement("w:bottom")
        p_bdr.append(bottom)
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), size)
    bottom.set(qn("w:space"), "4")
    bottom.set(qn("w:color"), color)


def add_brand_wordmark(paragraph, size: float = 18, suffix: str = "") -> None:
    for text, color in (("Hit", BRAND_BLUE), ("n", BRAND_PINK), ("Score", BRAND_BLUE)):
        run = paragraph.add_run(text)
        run.bold = True
        run.font.name = "Aptos Display"
        run.font.size = Pt(size)
        run.font.color.rgb = RGBColor.from_string(color)
    if suffix:
        run = paragraph.add_run(suffix)
        run.font.name = "Aptos"
        run.font.size = Pt(max(size - 5, 8))
        run.font.color.rgb = RGBColor.from_string(MID_GREY)


def add_table(doc: Document, headers: list[str], rows: Iterable[Iterable[str]], widths=None):
    rows = [list(row) for row in rows]
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    table.rows[0].alignment = WD_TABLE_ALIGNMENT.CENTER
    set_repeat_table_header(table.rows[0])
    for i, header in enumerate(headers):
        cell = table.rows[0].cells[i]
        cell.text = header
        set_cell_shading(cell, NAVY)
        set_cell_border(cell)
        set_cell_margins(cell)
        cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        for run in cell.paragraphs[0].runs:
            run.font.bold = True
            run.font.color.rgb = RGBColor(255, 255, 255)
            run.font.size = Pt(9.5)
        cell.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
    for row_index, values in enumerate(rows):
        cells = table.add_row().cells
        for i, value in enumerate(values):
            cells[i].text = str(value)
            cells[i].vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            set_cell_border(cells[i])
            set_cell_margins(cells[i])
            set_cell_shading(cells[i], PALE_BLUE if row_index % 2 else "FFFFFF")
            for paragraph in cells[i].paragraphs:
                paragraph.paragraph_format.space_after = Pt(0)
                paragraph.paragraph_format.line_spacing = 1.05
                for run in paragraph.runs:
                    run.font.size = Pt(9.2)
                    if str(value).strip() == "Passed":
                        run.font.bold = True
                        run.font.color.rgb = RGBColor.from_string(GREEN)
                    elif str(value).strip() == "Rectified":
                        run.font.bold = True
                        run.font.color.rgb = RGBColor.from_string(BRAND_PINK)
    if widths:
        for row in table.rows:
            for i, width in enumerate(widths):
                row.cells[i].width = Inches(width)
    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return table


def add_bullets(doc: Document, items: list[str]) -> None:
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        p.add_run(item)


def add_numbered(doc: Document, items: list[str]) -> None:
    for item in items:
        p = doc.add_paragraph(style="List Number")
        p.add_run(item)


def prep_image(path: Path, max_px: int = 1800) -> Path:
    TMP.mkdir(parents=True, exist_ok=True)
    target = TMP / (path.stem.replace(" ", "_") + ".jpg")
    with Image.open(path) as image:
        image = image.convert("RGB")
        if max(image.size) > max_px:
            ratio = max_px / max(image.size)
            image = image.resize((int(image.width * ratio), int(image.height * ratio)), Image.Resampling.LANCZOS)
        image.save(target, "JPEG", quality=91, optimize=True)
    return target


def add_figure(doc: Document, source: Path, caption: str, width: float | None = None) -> None:
    if not source.exists():
        p = doc.add_paragraph()
        run = p.add_run(f"Evidence file unavailable: {source.name}")
        run.italic = True
        run.font.color.rgb = RGBColor(154, 103, 0)
        return
    with Image.open(source) as image:
        landscape = image.width >= image.height
    target = prep_image(source, 2000 if landscape else 1800)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.keep_with_next = True
    use_width = width or (6.75 if landscape else 3.1)
    shape = p.add_run().add_picture(str(target), width=Inches(use_width))
    shape._inline.docPr.set("descr", caption)
    cap = doc.add_paragraph(caption, style="Caption")
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap.paragraph_format.keep_together = True
    cap.paragraph_format.space_after = Pt(10)


def add_evidence_group(doc: Document, heading: str, figures: list[tuple[Path, str, float | None]]) -> None:
    if heading:
        doc.add_heading(heading, level=2)
    for path, caption, width in figures:
        add_figure(doc, path, caption, width)


def configure_styles(doc: Document) -> None:
    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Aptos"
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = RGBColor.from_string(INK)
    normal.paragraph_format.space_after = Pt(7)
    normal.paragraph_format.line_spacing = 1.12

    title = styles["Title"]
    title.font.name = "Aptos Display"
    title.font.size = Pt(26)
    title.font.bold = True
    title.font.color.rgb = RGBColor(0, 0, 0)
    title.paragraph_format.space_after = Pt(14)
    title_ppr = title.element.get_or_add_pPr()
    title_border = title_ppr.find(qn("w:pBdr"))
    if title_border is not None:
        title_ppr.remove(title_border)

    for style_name, size in (("Heading 1", 18), ("Heading 2", 14), ("Heading 3", 11.5)):
        style = styles[style_name]
        style.font.name = "Aptos Display"
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = RGBColor(0, 0, 0)
        style.paragraph_format.keep_with_next = True
        style.paragraph_format.space_before = Pt(13 if style_name == "Heading 1" else 9)
        style.paragraph_format.space_after = Pt(6)

    caption = styles["Caption"]
    caption.font.name = "Aptos"
    caption.font.size = Pt(8.5)
    caption.font.italic = True
    caption.font.color.rgb = RGBColor.from_string(MID_GREY)

    for style_name in ("List Bullet", "List Number"):
        styles[style_name].font.name = "Aptos"
        styles[style_name].font.size = Pt(10.5)
        styles[style_name].paragraph_format.space_after = Pt(4)


def add_headers_and_footers(doc: Document) -> None:
    for section in doc.sections:
        section.different_first_page_header_footer = True
        hp = section.header.paragraphs[0]
        hp.alignment = WD_ALIGN_PARAGRAPH.LEFT
        hp.paragraph_format.space_after = Pt(4)
        add_brand_wordmark(hp, 10.5, "  |  Apple Subscription QA · Sandbox")
        set_paragraph_bottom_border(hp, BRAND_PINK, "6")

        p = section.footer.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(4)
        run = p.add_run("HitnScore  •  Apple Subscription Sandbox Test Report  •  ")
        run.font.size = Pt(8)
        run.font.color.rgb = RGBColor.from_string(MID_GREY)
        add_page_number(p)
        for footer_run in p.runs:
            footer_run.font.size = Pt(8)
            footer_run.font.color.rgb = RGBColor.from_string(MID_GREY)


def main() -> None:
    doc = Document()
    section = doc.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(0.68)
    section.bottom_margin = Inches(0.68)
    section.left_margin = Inches(0.72)
    section.right_margin = Inches(0.72)
    configure_styles(doc)

    brand = doc.add_paragraph()
    brand.alignment = WD_ALIGN_PARAGRAPH.CENTER
    brand.paragraph_format.space_after = Pt(1)
    logo = brand.add_run().add_picture(str(BRAND_LOGO), width=Inches(0.78))
    logo._inline.docPr.set("descr", "HitnScore mascot")
    wordmark = doc.add_paragraph()
    wordmark.alignment = WD_ALIGN_PARAGRAPH.CENTER
    wordmark.paragraph_format.space_after = Pt(13)
    add_brand_wordmark(wordmark, 23)

    title_paragraph = doc.add_paragraph("RcktScore Apple Subscription Sandbox Test Report", style="Title")
    title_paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title_ppr = title_paragraph._p.get_or_add_pPr()
    title_border = title_ppr.find(qn("w:pBdr"))
    if title_border is not None:
        title_ppr.remove(title_border)
    subtitle = doc.add_paragraph()
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = subtitle.add_run("TestFlight purchase verification and subscription lifecycle evidence")
    r.bold = True
    r.font.size = Pt(14)
    r.font.color.rgb = RGBColor.from_string(NAVY)
    meta = doc.add_paragraph()
    meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
    meta.add_run("Test period: ").bold = True
    meta.add_run("10 to 11 September 2026\n")
    meta.add_run("Environment: ").bold = True
    meta.add_run("Apple Sandbox through TestFlight, RcktScore iOS 1.0.2 build 49\n")
    meta.add_run("Report prepared: ").bold = True
    meta.add_run("11 September 2026\n")
    meta.add_run("Purpose: ").bold = True
    meta.add_run("Record the manual purchase and lifecycle tests completed in this test session, the defects found, the corrective actions applied, and the evidence supporting each result.")

    doc.add_heading("Executive outcome", level=1)
    p = doc.add_paragraph()
    lead = p.add_run("Outcome: ")
    lead.bold = True
    lead.font.color.rgb = RGBColor.from_string(GREEN)
    p.add_run(
        "The Test A, Test B, Test C and Test D scenarios executed in this session passed. "
        "They demonstrated initial monthly purchase, voluntary cancellation with access through paid expiry, stable renewal, account-bound purchase protection, failed renewal, grace-period access, grace expiry, billing retry expiry, and successful billing recovery without entitlement churn."
    )
    doc.add_paragraph(
        "The report signs off the manual Sandbox suite performed here. It does not by itself close every item in the broader production-release checklist. "
        "Refund and revocation, refund reversal, cross-device restore, deliberate missed-notification repair, and several negative security cases still require separate end-to-end evidence before production purchasing is declared fully ready."
    )

    add_table(
        doc,
        ["Tester", "Organisation", "Product", "Primary scenario", "Result"],
        [
            ["Test A", "50006", "Personal Plus monthly", "Purchase, voluntary cancellation and paid-expiry downgrade", "Passed"],
            ["Test B", "50007", "Personal Plus yearly", "Continuous renewal and stable refresh", "Passed"],
            ["Test C", "50008", "Personal Plus monthly", "Failed renewal through grace and final expiry", "Passed"],
            ["Test D", "50009", "Personal Plus monthly", "Failed renewal followed by billing recovery in grace", "Passed"],
        ],
        widths=[0.8, 0.9, 1.35, 3.05, 0.75],
    )

    doc.add_heading("Scope and evidence method", level=1)
    doc.add_paragraph(
        "The iOS app was installed through TestFlight and used with dedicated HitnScore personal accounts and Apple Sandbox testers. "
        "Apple lifecycle notifications were verified against Supabase records in app_store_subscriptions and app_store_subscription_events. "
        "Entitlement changes were checked in SkwshOrgSettings and the append-only subscription_entitlement_audit table. Device screenshots, database result screenshots, and implementation evidence were retained together."
    )
    add_bullets(
        doc,
        [
            "The server-side plan was treated as authoritative; the device display was checked after database state was confirmed.",
            "All displayed lifecycle processing_error and reconciliation_error values were NULL.",
            "An audit row was expected only when the effective HitnScore plan changed.",
            "Times in this report are Europe London local time as selected in the SQL evidence.",
        ],
    )

    doc.add_heading("Rectifications made during the test programme", level=1)
    doc.add_heading("Renewal boundary entitlement race", level=2)
    doc.add_paragraph(
        "A renewal-boundary risk was identified in which a locally elapsed transaction could be downgraded before Apple's delayed renewal notification or server reconciliation arrived. "
        "This could produce an incorrect temporary Personal Plus to Personal Free to Personal Plus sequence."
    )
    doc.add_paragraph(
        "The backend was changed so elapsed subscriptions are reconciled with Apple before local expiry is applied. "
        "Verified active Apple status remains entitled even when the previous signed transaction has just elapsed, and a bounded 15-minute fallback now applies only when notifications and reconciliation remain unavailable. "
        "Elapsed active, grace-period, and billing-retry rows are prioritised for reconciliation."
    )
    doc.add_heading("iOS refresh and subscription management handling", level=2)
    doc.add_paragraph(
        "SwiftUI cancellation of an in-flight pull-to-refresh was previously capable of appearing as a user-facing dashboard error. "
        "CancellationError and URLError.cancelled are now treated as non-failures. The dashboard also reloads the server-authoritative plan when Apple's Manage Subscription sheet closes so expiry or revocation can be reflected promptly."
    )
    doc.add_paragraph(
        "This was exercised during Test A. A transient Unable to fetch dashboard data banner and stale subscription presentation were observed around the accelerated Sandbox expiry boundary. "
        "The refresh cancellation handling and post-Manage-Subscription reload were rectified so a cancelled request is not reported as a lifecycle failure and the next completed refresh takes the authoritative plan from the server."
    )
    doc.add_heading("Regression verification", level=2)
    doc.add_paragraph(
        "Regression coverage was added for active entitlement during Apple's transaction-delivery window, the 15-minute fallback, reconciliation-before-expiry ordering, and successful state application. "
        "The backend automated suite completed with 79 passing tests, and Python compilation plus AWS SAM build and validation completed successfully before deployment."
    )
    doc.add_heading("Sandbox account mismatch", level=2)
    doc.add_paragraph(
        "Test C initially invoked the personal Media and Purchases Apple account yulunga@gmail.com even though the Sandbox settings displayed testc@hitnscore.com. "
        "The personal Media and Purchases session was signed out and the dedicated Sandbox tester was reselected under Developer settings. "
        "The subsequent TestFlight purchase sheet correctly displayed testc@hitnscore.com. The backend also rejected the transaction when it belonged to another HitnScore account, confirming account binding protection."
    )
    doc.add_heading("Billing grace and accelerated timing", level=2)
    doc.add_paragraph(
        "Billing Grace Period was confirmed and then restricted to the Sandbox environment with a three-day production-duration setting and eligibility limited to paid-to-paid renewals. "
        "The Sandbox renewal rate was set to five minutes for Test D. Test C's already-created monthly cycle retained its earlier 30-minute timing; later cycles followed the accelerated Sandbox schedule."
    )
    add_evidence_group(
        doc,
        "Programme configuration evidence",
        [
            (CLIPBOARD / "codex-clipboard-8b036553-94e3-4241-9940-4e96846e3194.png", "Configuration evidence 1  Billing Grace Period restricted to paid-to-paid renewals in Sandbox", 6.75),
            (CLIPBOARD / "codex-clipboard-3b048a50-f694-45e7-93e2-e1b448371aa2.png", "Configuration evidence 2  Test D Sandbox tester set to five-minute monthly renewals", 4.7),
        ],
    )

    doc.add_page_break()
    doc.add_heading("Test A monthly purchase and voluntary cancellation", level=1)
    doc.add_paragraph(
        "Test A used HitnScore account testa@hitnscore.com and organisation 50006 with the monthly product com.hitnscore.personalplus.monthly. "
        "The objective was to prove the initial Free to Plus purchase, continuing paid access after auto-renew was disabled, and the final Plus to Free transition when the paid Sandbox period ended. "
        "The cancellation path was repeated once after resubscription to confirm the same terminal behaviour."
    )
    add_table(
        doc,
        ["Checkpoint", "Observed evidence", "Outcome"],
        [
            ["Initial state", "Personal was Current and no subscription row existed", "Passed"],
            ["Monthly purchase", "Apple-signed Sandbox purchase created the subscription and upgraded Free to Plus", "Passed"],
            ["Normal renewal", "Successive five-minute transactions advanced the paid-through time", "Passed"],
            ["Cancellation", "DID_CHANGE_RENEWAL_STATUS set auto-renew false without removing current access", "Passed"],
            ["Paid-through access", "HitnScore continued to display Personal Plus Current before expiry", "Passed"],
            ["Voluntary expiry", "EXPIRED VOLUNTARY changed active to expired and Plus to Free", "Passed"],
            ["Audit integrity", "Each effective Free to Plus and Plus to Free change was recorded once", "Passed"],
            ["Refresh defect", "A transient dashboard fetch error was observed and the cancellation/reload handling was rectified", "Rectified"],
        ],
        widths=[1.35, 4.65, 0.75],
    )

    doc.add_heading("Test A purchase and entitlement activation", level=2)
    add_evidence_group(
        doc,
        "",
        [
            (DOWNLOADS / "Test-A-User.png", "Figure A1  Test A began with Personal current and the monthly and yearly upgrade choices available", 3.0),
            (CLIPBOARD / "codex-clipboard-bbdc70bd-df1f-4029-a352-e8bb05e1b4db.png", "Figure A2  Baseline query returned no Apple subscription row for organisation 50006", 5.6),
            (DOWNLOADS / "Test-A-purchase monthly.png", "Figure A3  The monthly purchase completed and Personal Plus became Current", 3.0),
            (CLIPBOARD / "codex-clipboard-eeb4e5bd-0364-4659-9b8a-1ab00b5510a9.png", "Figure A4  Organisation 50006 was bound to testa and upgraded to Personal Plus", 6.2),
            (CLIPBOARD / "codex-clipboard-4e1ea45b-694d-444e-9bef-a5772c2c6791.png", "Figure A5  Initial monthly purchase and successive renewal transactions were verified in Sandbox", 6.75),
            (CLIPBOARD / "codex-clipboard-8a859529-0048-422e-a661-852160068cfa.png", "Figure A6  Authoritative subscription row was active with the latest transaction and advanced expiry", 6.75),
            (CLIPBOARD / "codex-clipboard-977cb341-4b19-4ade-85ef-4f8f56150b0b.png", "Figure A7  Initial entitlement audit recorded Personal Free to Personal Plus exactly once", 6.75),
        ],
    )

    doc.add_heading("Test A cancellation and paid expiry", level=2)
    add_evidence_group(
        doc,
        "",
        [
            (DOWNLOADS / "Test-A-x3.png", "Figure A8  Apple requested explicit confirmation before cancelling the subscription", 3.0),
            (DOWNLOADS / "Test-A-x4.png", "Figure A9  Apple displayed the Sandbox right-of-withdrawal step in the cancellation flow", 3.0),
            (DOWNLOADS / "Test-A-x2.png", "Figure A10  Apple confirmed auto-renew was cancelled while showing the paid-through end date", 3.0),
            (CLIPBOARD / "codex-clipboard-9475bc7e-482a-4a8e-95df-5d1b50d8d64f.png", "Figure A11  Server state remained active with auto-renew false until the paid expiry", 6.75),
            (DOWNLOADS / "Test-A-x6.png", "Figure A12  HitnScore retained Personal Plus while the cancelled subscription was still paid through", 3.0),
            (DOWNLOADS / "Test-A-x7.png", "Figure A13  Apple displayed the ended state after voluntary expiry", 3.0),
            (DOWNLOADS / "Test-A-x5.png", "Figure A14  Apple retained both monthly and yearly plans as available repurchase choices", 3.0),
        ],
    )

    doc.add_heading("Test A repeat cycle and final audit", level=2)
    add_evidence_group(
        doc,
        "",
        [
            (DOWNLOADS / "Test-A-x1.png", "Figure A15  After resubscription the app again showed Personal Plus Current during the paid period", 3.0),
            (CLIPBOARD / "codex-clipboard-55eb795f-7e2f-4df6-9379-4f42c18a45b8.png", "Figure A16  Event chain captured renewals, voluntary expiry, resubscription, and auto-renew disablement", 6.75),
            (CLIPBOARD / "codex-clipboard-79f0ad47-c218-4da6-b9ba-3e43a12d1ad8.png", "Figure A17  Audit trail recorded both completed Free to Plus to Free cycles without duplicate changes", 6.75),
            (DOWNLOADS / "Test-A-x8.png", "Figure A18  Transient dashboard fetch error observed at the accelerated expiry boundary", 3.0),
        ],
    )
    doc.add_paragraph(
        "Rectification: cancellation itself was processed correctly, but the device could display a cancelled refresh as an error and could retain the last loaded plan until a completed reload. "
        "The iOS refresh path now ignores request cancellation as a non-failure and reloads the dashboard after the Apple subscription-management sheet closes."
    )
    doc.add_paragraph(
        "Test A result: Passed after rectification. The monthly purchase upgraded the correct organisation, cancellation disabled renewal without prematurely removing paid access, voluntary expiry downgraded the server entitlement to Personal Free, and the append-only audit contained one row for each genuine plan change."
    )

    doc.add_page_break()
    doc.add_heading("Test B stable yearly renewal", level=1)
    doc.add_paragraph(
        "Test B used organisation 50007 and the yearly product com.hitnscore.personalplus.yearly. "
        "The objective was to prove that normal renewals advance the Apple transaction and expiry while Personal Plus remains continuously current and the refresh path produces no false error."
    )
    add_table(
        doc,
        ["Checkpoint", "Observed evidence", "Outcome"],
        [
            ["Subscription state", "active; auto-renew true; source notification", "Passed"],
            ["Product", "com.hitnscore.personalplus.yearly", "Passed"],
            ["Latest renewal", "DID_RENEW with active to active and Plus to Plus", "Passed"],
            ["Expiry movement", "Latest transaction and expiry advanced", "Passed"],
            ["Errors", "Reconciliation and latest event processing errors NULL", "Passed"],
            ["Device refresh", "Personal Plus remained Current; no upgrade choices or refresh error", "Passed"],
        ],
        widths=[1.35, 4.65, 0.75],
    )
    add_evidence_group(
        doc,
        "Test B evidence",
        [
            (CLIPBOARD / "codex-clipboard-e81b8a45-f853-4641-a981-fea5113570c5.png", "Figure B1  Active yearly subscription for organisation 50007 with the renewed transaction and expiry", 6.75),
            (CLIPBOARD / "codex-clipboard-d5578bb8-d23f-496a-ae8a-929be751a49b.png", "Figure B2  Latest Test B DID_RENEW events showing active to active and Personal Plus to Personal Plus", 6.75),
            (CLIPBOARD / "codex-clipboard-18b0e203-f928-431d-9477-7bc70b334b7f.png", "Figure B3  Test B entitlement audit row count retained for comparison", 6.35),
            (CLIPBOARD / "codex-clipboard-5d6a0001-c86e-403d-bdce-6e16dd6457c0.png", "Figure B4  Subscription reconciliation error and latest processing error both NULL", 5.5),
        ],
    )
    doc.add_paragraph(
        "Test B result: Passed. The deployed renewal-boundary rectification prevented a temporary downgrade, normal notification processing advanced the subscription, and the app remained on Personal Plus after refresh."
    )

    doc.add_page_break()
    doc.add_heading("Test C failed renewal and non recovery", level=1)
    doc.add_paragraph(
        "Test C used HitnScore account testc@hitnscore.com, Apple Sandbox tester testc@hitnscore.com, and organisation 50008. "
        "The test deliberately disabled purchases and renewals, observed grace-period access, allowed grace to expire, and verified the final downgrade and audit trail."
    )
    add_table(
        doc,
        ["Time", "Lifecycle state", "Plan", "Evidence and result"],
        [
            ["22:43", "SUBSCRIBED INITIAL_BUY", "Free to Plus", "Monthly purchase accepted and app displayed Plus Current"],
            ["23:13:01", "DID_FAIL_TO_RENEW GRACE_PERIOD", "Plus retained", "active to grace_period; no processing error"],
            ["23:18:06", "GRACE_PERIOD_EXPIRED", "Plus to Free", "grace_period to billing_retry; audit downgrade recorded"],
            ["23:22:05", "EXPIRED BILLING_RETRY", "Free retained", "billing_retry to expired; no duplicate plan change"],
        ],
        widths=[0.8, 2.05, 1.05, 2.85],
    )

    doc.add_heading("Test C account preparation and account binding", level=2)
    add_evidence_group(
        doc,
        "",
        [
            (DOWNLOADS / "Test-C-y1.png", "Figure C1  Device Developer settings showing the Test C Sandbox Apple Account", 3.0),
            (DOWNLOADS / "Test-C-y2.png", "Figure C2  HitnScore signed in as Test SandboxC", 3.0),
            (DOWNLOADS / "Test-C-y3.png", "Figure C3  Initial HitnScore state with Personal current and Personal Plus available", 3.0),
            (DOWNLOADS / "Test-C-y6.png", "Figure C4  Apple attempted to verify the personal Media and Purchases account instead of the Sandbox tester", 3.0),
            (DOWNLOADS / "Test-C-y7.png", "Figure C5  Backend account-binding protection rejected a transaction belonging to another HitnScore account", 3.0),
            (DOWNLOADS / "Test-C-y9.png", "Figure C6  Corrected TestFlight purchase sheet displaying testc@hitnscore.com", 3.0),
        ],
    )
    doc.add_paragraph(
        "Rectification: the personal Media and Purchases Apple session was signed out and the Test C Sandbox tester was selected again. "
        "This returned the purchase flow to the correct Apple Sandbox identity without changing backend ownership."
    )

    doc.add_heading("Test C initial purchase", level=2)
    add_evidence_group(
        doc,
        "",
        [
            (DOWNLOADS / "Test-C-y11.png", "Figure C7  Apple confirmed the Test C purchase was successful", 3.0),
            (DOWNLOADS / "Test-C-y12.png", "Figure C8  Personal Plus became Current after server verification", 3.0),
            (DOWNLOADS / "Test-C-y13.png", "Figure C9  Apple Sandbox subscription management confirmed the monthly plan", 3.0),
            (CLIPBOARD / "codex-clipboard-2ddb8bcd-f969-46e4-8ec1-ec2f487b9e80.png", "Figure C10  Test C organisation 50008 and Personal Plus plan", 6.2),
            (CLIPBOARD / "codex-clipboard-2efe9bf9-379e-4913-922e-c70679155b2c.png", "Figure C11  Active monthly subscription purchased at 22:43 with expiry at 23:13", 6.75),
            (CLIPBOARD / "codex-clipboard-43fa9cb3-fa63-4270-bbf1-782306da1276.png", "Figure C12  Initial Test C audit count of one", 5.7),
        ],
    )

    doc.add_heading("Test C grace entry and final expiry", level=2)
    add_evidence_group(
        doc,
        "",
        [
            (DOWNLOADS / "Test-C-y15.png", "Figure C13  Apple Sandbox billing problem after renewal failure", 3.0),
            (DOWNLOADS / "Test-C-y16.png", "Figure C14  Apple subscription screen showing the declined payment state", 3.0),
            (CLIPBOARD / "codex-clipboard-0f2674e2-548b-488b-a919-3bff9b6e419b.png", "Figure C15  DID_FAIL_TO_RENEW with GRACE_PERIOD and Personal Plus retained", 6.75),
            (DOWNLOADS / "Test-C-y18.png", "Figure C16  HitnScore returned to Personal Free after grace expiry", 3.0),
            (CLIPBOARD / "codex-clipboard-f60a8bbc-970c-47b9-9a4b-88f2-dd1cc814713b.png", "Figure C17  Final Test C subscription status expired and organisation plan Personal Free", 6.75),
            (CLIPBOARD / "codex-clipboard-b45c26eb-4e73-4d4b-88f2-dd1cc814713b.png", "Figure C18  Complete Test C event chain through grace expiry and billing retry expiry", 6.75),
            (CLIPBOARD / "codex-clipboard-286e8dbd-b81b-437e-aa48-d73398586db1.png", "Figure C19  Audit contains only the genuine Free to Plus and Plus to Free entitlement changes", 6.75),
        ],
    )
    doc.add_paragraph(
        "The red Unable to restore purchases Request Cancelled message was produced when the restore interaction was cancelled. "
        "It was not a lifecycle-processing failure and was kept separate from the Test C result."
    )
    doc.add_paragraph(
        "Test C result: Passed. Access remained Plus during verified grace, changed to Free exactly when grace expired, remained Free through final billing-retry expiry, and generated no duplicate entitlement audit entry."
    )

    doc.add_page_break()
    doc.add_heading("Test D billing recovery within grace", level=1)
    doc.add_paragraph(
        "Test D used HitnScore and Apple Sandbox account testd@hitnscore.com with organisation 50009. "
        "The objective was to fail the first renewal, prove continued access during grace, re-enable purchases and renewals before grace expired, and verify recovery without any temporary downgrade."
    )
    add_table(
        doc,
        ["Time", "Action or event", "Subscription transition", "Plan result"],
        [
            ["11:14:36", "SUBSCRIBED INITIAL_BUY", "none to active", "Free to Plus"],
            ["11:16", "Allow Purchases and Renewals OFF", "Failure simulation armed", "Plus retained"],
            ["11:19:34", "DID_FAIL_TO_RENEW GRACE_PERIOD", "active to grace_period", "Plus retained"],
            ["11:22", "HitnScore refresh during grace", "grace_period", "Plus still Current"],
            ["11:23", "Allow Purchases and Renewals ON", "Recovery enabled", "Plus retained"],
            ["11:23:10", "DID_RENEW BILLING_RECOVERY", "grace_period to active", "Plus retained"],
            ["11:23:44", "Normal DID_RENEW", "active to active", "Plus retained"],
            ["11:25", "Final HitnScore refresh", "active", "Plus Current; no error"],
        ],
        widths=[0.8, 2.35, 2.05, 1.55],
    )

    doc.add_heading("Test D preparation and initial purchase", level=2)
    add_evidence_group(
        doc,
        "",
        [
            (DOWNLOADS / "Screenshot 2026-09-11 at 11.09.35.png", "Figure D1  Device Developer settings using testd@hitnscore.com", 3.0),
            (DOWNLOADS / "Screenshot 2026-09-11 at 11.10.20.png", "Figure D2  HitnScore signed in as Test SandboxD", 3.0),
            (DOWNLOADS / "Screenshot 2026-09-11 at 11.10.57.png", "Figure D3  Five-minute rate and renewals enabled before purchase", 3.0),
            (CLIPBOARD / "codex-clipboard-9269a485-1cf3-4cbd-acec-472ca95dcf79.png", "Figure D4  Test D organisation 50009 began on Personal Free", 6.2),
            (CLIPBOARD / "codex-clipboard-d38e8468-e87c-4d59-ae0d-d5c798ea701d.png", "Figure D5  Initial active monthly subscription from 11:14:34 to 11:19:34", 6.75),
            (CLIPBOARD / "codex-clipboard-46acebd1-22a4-4c7b-9488-b18414225093.png", "Figure D6  Baseline audit contains one subscribed Free to Plus change", 6.75),
        ],
    )

    doc.add_heading("Test D failure and grace access", level=2)
    add_evidence_group(
        doc,
        "",
        [
            (DOWNLOADS / "Screenshot 2026-09-11 at 11.16.42.png", "Figure D7  Purchases and renewals disabled before the first renewal", 3.0),
            (CLIPBOARD / "codex-clipboard-137abf94-f58f-458e-bb9a-1fc50da00e4b.png", "Figure D8  Failed renewal entered grace while the plan remained Personal Plus", 6.75),
            (CLIPBOARD / "codex-clipboard-80784942-3b95-4710-98b3-db90699af961.png", "Figure D9  Grace period ran from 11:19:34 to 11:24:34 with no reconciliation error", 6.75),
            (DOWNLOADS / "Screenshot 2026-09-11 at 11.21.57.png", "Figure D10  Apple Sandbox billing-problem prompt during the simulated failure", 3.0),
            (DOWNLOADS / "Screenshot 2026-09-11 at 11.22.38.png", "Figure D11  HitnScore still displayed Personal Plus Current during grace", 3.0),
        ],
    )

    doc.add_heading("Test D recovery and final state", level=2)
    add_evidence_group(
        doc,
        "",
        [
            (DOWNLOADS / "Screenshot 2026-09-11 at 11.23.09.png", "Figure D12  Purchases and renewals re-enabled before grace expiry", 3.0),
            (CLIPBOARD / "codex-clipboard-c3a03968-9445-42df-8bfc-bb080ca7aa64.png", "Figure D13  Billing recovery followed by a normal renewal with all processing errors NULL", 6.75),
            (CLIPBOARD / "codex-clipboard-eb11dd53-5e9a-40c8-bce8-fa28e07df3dc.png", "Figure D14  Final active subscription with advanced transaction and expiry and cleared grace fields", 6.75),
            (CLIPBOARD / "codex-clipboard-a00a01f9-85dc-4650-a005-30a20679cde2.png", "Figure D15  Audit remained at one row because recovery never removed entitlement", 6.75),
            (DOWNLOADS / "Screenshot 2026-09-11 at 11.25.48.png", "Figure D16  Final device refresh showed Personal Plus Current with no error", 3.0),
        ],
    )
    doc.add_paragraph(
        "Test D result: Passed. The account remained entitled throughout grace, recovered to active before grace expired, processed the subsequent normal renewal, and produced no Plus to Free to Plus churn in either the app or audit trail."
    )

    doc.add_page_break()
    doc.add_heading("Consolidated results", level=1)
    add_table(
        doc,
        ["Requirement demonstrated", "Evidence", "Status"],
        [
            ["Monthly purchase and voluntary cancellation preserve access through paid expiry", "Test A active with auto-renew false, followed by EXPIRED VOLUNTARY and Plus to Free", "Passed"],
            ["Monthly initial purchase upgrades the signed-in account", "Tests C and D; server plan and device both changed to Personal Plus", "Passed"],
            ["Yearly renewal remains continuously entitled", "Test B DID_RENEW active to active with stable app state", "Passed"],
            ["Different-account transaction cannot be attached", "Test C displayed backend ownership rejection", "Passed"],
            ["Failed renewal enters grace", "Tests C and D DID_FAIL_TO_RENEW with GRACE_PERIOD", "Passed"],
            ["Grace retains paid access", "Plan remained Plus and Test D device displayed Plus Current", "Passed"],
            ["Grace expiry removes paid access", "Test C GRACE_PERIOD_EXPIRED and audited Plus to Free", "Passed"],
            ["Billing retry expiry is idempotent", "Test C EXPIRED retained Free without another audit change", "Passed"],
            ["Billing recovery restores active state without churn", "Test D DID_RENEW BILLING_RECOVERY and one-row audit", "Passed"],
            ["Normal renewal works after billing recovery", "Test D second DID_RENEW active to active", "Passed"],
            ["Device refresh reflects the server-authoritative plan", "Final C Free and final D Plus screens matched database state", "Passed"],
            ["Lifecycle and reconciliation processing is clean", "All inspected processing_error and reconciliation_error fields NULL", "Passed"],
        ],
        widths=[3.0, 3.15, 0.65],
    )

    doc.add_heading("Remaining production release evidence", level=1)
    doc.add_paragraph(
        "The manual scenarios above are complete. The following requirements from the production plan were not fully demonstrated end to end in this chat and should remain open until separately evidenced:"
    )
    add_bullets(
        doc,
        [
            "Refund, revocation, and refund-reversal entitlement handling.",
            "Restore Purchases on another device while mapping to the correct HitnScore account.",
            "A deliberately missed notification repaired by App Store Server API reconciliation.",
            "Real Sandbox negative cases for invalid signature, wrong bundle ID, Apple app ID, product, environment, and account token.",
            "Real duplicate notification and out-of-order notification delivery, although automated regression coverage exists.",
            "Root-admin subscription activity and audit parity after every remaining scenario.",
            "Production V2 notification URL, Production environment enablement, monitoring, DLQ, and operational runbook gates.",
        ],
    )

    doc.add_heading("Sign off statement", level=1)
    doc.add_paragraph(
        "The Test A, Test B, Test C and Test D Apple Sandbox and TestFlight subscription scenarios described in this report are signed off as passed. "
        "The observed defects were either rectified in the backend and iOS client or resolved through correct Sandbox account configuration. "
        "The final database, audit, and device states were consistent for all four testers. Production purchasing should remain gated until the separate outstanding release evidence listed above is completed."
    )

    doc.add_heading("Appendix SQL evidence queries", level=1)
    queries = [
        (
            "Organisation lookup",
            "SELECT id, owner_username, org_type, plan\nFROM \"SkwshOrgSettings\"\nWHERE LOWER(owner_username) = 'tester@hitnscore.com';",
        ),
        (
            "Subscription state",
            "SELECT organization_id, status, product_id, original_transaction_id, latest_transaction_id,\n"
            "       purchased_at AT TIME ZONE 'Europe/London' AS purchased_uk,\n"
            "       expires_at AT TIME ZONE 'Europe/London' AS expires_uk,\n"
            "       grace_period_expires_at AT TIME ZONE 'Europe/London' AS grace_expires_uk,\n"
            "       billing_retry_started_at AT TIME ZONE 'Europe/London' AS billing_retry_started_uk,\n"
            "       auto_renew_enabled, last_status_source, reconciliation_error\n"
            "FROM app_store_subscriptions\nWHERE organization_id = :organization_id;",
        ),
        (
            "Lifecycle event history",
            "SELECT notification_type, subtype, transaction_id, subscription_status_before,\n"
            "       subscription_status_after, plan_before, plan_after,\n"
            "       processed_at AT TIME ZONE 'Europe/London' AS processed_uk, processing_error\n"
            "FROM app_store_subscription_events\nWHERE organization_id = :organization_id\nORDER BY verified_at DESC\nLIMIT 10;",
        ),
        (
            "Entitlement audit",
            "SELECT previous_plan, new_plan, source, reason,\n"
            "       effective_at AT TIME ZONE 'Europe/London' AS effective_uk,\n"
            "       created_at AT TIME ZONE 'Europe/London' AS created_uk\n"
            "FROM subscription_entitlement_audit\nWHERE organization_id = :organization_id\nORDER BY created_at;",
        ),
    ]
    for heading, query in queries:
        doc.add_heading(heading, level=2)
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Inches(0.25)
        p.paragraph_format.right_indent = Inches(0.25)
        p.paragraph_format.space_after = Pt(10)
        for index, line in enumerate(query.splitlines()):
            run = p.add_run(line)
            run.font.name = "Courier New"
            run.font.size = Pt(8.5)
            if index < len(query.splitlines()) - 1:
                run.add_break()

    add_headers_and_footers(doc)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
