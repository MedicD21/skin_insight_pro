import argparse
import csv
import difflib
import html
import json
import re
import time
import urllib.request
from pathlib import Path
from urllib.parse import urljoin

from bs4 import BeautifulSoup


BASE_URL = "https://zoskinhealth.com/us/shop/?start=0&sz=18"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)


def normalize_text(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def read_product_list(path: str) -> list[str]:
    products: list[str] = []
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            name = line.strip()
            if name:
                products.append(name)
    return products


def fetch_html(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", errors="replace")


def extract_image_url(img_tag) -> str | None:
    if img_tag is None:
        return None

    for attr in ("data-srcset", "data-src", "data-lazy", "data-original", "srcset", "src"):
        if not img_tag.has_attr(attr):
            continue
        value = img_tag.get(attr)
        if not value:
            continue
        if attr.endswith("srcset"):
            candidates = [part.strip().split(" ")[0] for part in value.split(",") if part.strip()]
            if candidates:
                value = candidates[-1]
        if value and not value.startswith("data:image"):
            return value
    return None


def extract_name(tile) -> str | None:
    data_name = tile.get("data-product-name")
    if data_name:
        return data_name.strip()

    aria_name = tile.get("aria-label")
    if aria_name:
        return aria_name.strip()

    selectors = [
        "h3.b-product_tile-title a",
        "[itemprop='name']",
        ".product-name",
        ".product-tile__name",
        ".product-name a",
        ".pdp-link",
        ".product-tile a",
        "a.name",
        "a.link",
    ]
    for selector in selectors:
        element = tile.select_one(selector)
        if element:
            text = element.get_text(" ", strip=True)
            if text:
                return text
    return None


def extract_tile_image(tile, base_url: str) -> str | None:
    picture = tile.select_one("picture.b-product_tile-image") or tile.select_one(
        "picture[data-tau='product_image']"
    )
    if picture:
        img = picture.find("img")
        if img:
            url = extract_image_url(img)
            if url:
                return urljoin(base_url, url)
        source = picture.find("source")
        if source:
            url = extract_image_url(source)
            if url:
                return urljoin(base_url, url)

    img = tile.select_one("img[data-ref='tileImage']") or tile.select_one("img[alt]")
    url = extract_image_url(img)
    if url:
        return urljoin(base_url, url)
    return None


def parse_products(html: str, base_url: str) -> list[dict]:
    soup = BeautifulSoup(html, "html.parser")
    tiles = soup.select("article.b-product_tile")
    if not tiles:
        tiles = soup.select(
            "div.product-tile, div.product, li.product, li.product-tile, "
            "div.product-card, div.product-grid__item, div.b-product_tile, "
            "div.b-product_card, div.product-tile-wrapper"
        )

    results: list[dict] = []
    for tile in tiles:
        name = extract_name(tile)
        if not name:
            continue
        image_url = extract_tile_image(tile, base_url)
        product_url = extract_tile_url(tile, base_url)
        category_hint = extract_tile_category(tile)
        results.append({
            "name": name,
            "image_url": image_url,
            "url": product_url,
            "category_hint": category_hint,
        })

    if not results:
        for img in soup.find_all("img"):
            image_url = extract_image_url(img)
            if not image_url:
                continue
            parent = img.find_parent()
            if not parent:
                continue
            name = extract_name(parent)
            if not name:
                continue
            results.append({"name": name, "image_url": urljoin(base_url, image_url)})

    return results


def collect_all_products(base_url: str, max_loads: int) -> list[dict]:
    products: dict[str, dict] = {}
    url = base_url
    visited: set[str] = set()
    loads = 0

    while url and url not in visited and loads <= max_loads:
        visited.add(url)
        html = fetch_html(url)
        parsed = parse_products(html, base_url)
        for item in parsed:
            normalized = normalize_text(item["name"])
            if not normalized:
                continue
            if normalized not in products:
                products[normalized] = item

        soup = BeautifulSoup(html, "html.parser")
        load_more = soup.select_one("a.b-load_more-button")
        if load_more and loads < max_loads:
            next_url = (
                load_more.get("data-show-ajax-url")
                or load_more.get("data-show-url")
                or load_more.get("href")
            )
            if next_url:
                url = urljoin(base_url, next_url)
                loads += 1
                time.sleep(0.5)
                continue
        break

    return list(products.values())


def extract_tile_url(tile, base_url: str) -> str | None:
    link = tile.select_one("h3.b-product_tile-title a") or tile.select_one("a.b-product_tile-image_link")
    if link and link.has_attr("href"):
        return urljoin(base_url, link["href"])
    return None


def extract_tile_category(tile) -> str | None:
    data_analytics = tile.get("data-analytics")
    if not data_analytics:
        return None
    try:
        decoded = html.unescape(data_analytics)
        data = json.loads(decoded)
    except json.JSONDecodeError:
        return None
    category = data.get("category")
    if isinstance(category, str) and category.strip():
        return category.strip()
    return None


def match_products(targets: list[str], scraped: list[dict]) -> tuple[list[dict], list[str]]:
    scraped_by_norm = {normalize_text(item["name"]): item for item in scraped if item["name"]}

    matches: list[dict] = []
    missing: list[str] = []

    for target in targets:
        normalized = normalize_text(target)
        if not normalized:
            continue
        if normalized in scraped_by_norm:
            match = scraped_by_norm[normalized]
            matches.append({
                "list_name": target,
                "scraped_name": match["name"],
                "image_url": match.get("image_url", ""),
                "product_url": match.get("url", ""),
                "category_hint": match.get("category_hint", ""),
                "match_type": "exact",
            })
            continue

        best_ratio = 0.0
        best_match = None
        for candidate in scraped:
            candidate_name = candidate.get("name", "")
            candidate_norm = normalize_text(candidate_name)
            if not candidate_norm:
                continue
            ratio = difflib.SequenceMatcher(None, normalized, candidate_norm).ratio()
            if ratio > best_ratio:
                best_ratio = ratio
                best_match = candidate

        if best_match and best_ratio >= 0.7:
            matches.append({
                "list_name": target,
                "scraped_name": best_match["name"],
                "image_url": best_match.get("image_url", ""),
                "product_url": best_match.get("url", ""),
                "category_hint": best_match.get("category_hint", ""),
                "match_type": f"fuzzy ({best_ratio:.2f})",
            })
        else:
            missing.append(target)

    return matches, missing


def write_results(output_base: str, matches: list[dict], missing: list[str]) -> tuple[str, str]:
    output_path = Path(output_base)
    if output_path.suffix.lower() != ".csv":
        csv_path = output_path.with_suffix(".csv")
    else:
        csv_path = output_path

    missing_path = csv_path.with_name(f"{csv_path.stem}_missing.txt")

    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["Product Name", "Matched Name", "Image URL", "Match Type"],
        )
        writer.writeheader()
        for match in matches:
            writer.writerow({
                "Product Name": strip_staff_order(match["list_name"]),
                "Matched Name": match["scraped_name"],
                "Image URL": match["image_url"],
                "Match Type": match["match_type"],
            })

    if missing:
        with missing_path.open("w", encoding="utf-8") as handle:
            for name in missing:
                handle.write(f"{strip_staff_order(name)}\n")
    else:
        missing_path.write_text("", encoding="utf-8")

    return str(csv_path), str(missing_path)


def clean_text(value: str) -> str:
    return " ".join(value.replace("\xa0", " ").split())


def strip_staff_order(value: str) -> str:
    cleaned = re.sub(r"\bstaff\s*order\b", "", value, flags=re.IGNORECASE)
    return clean_text(cleaned)


def extract_html_text(fragment: str) -> str:
    fragment = html.unescape(fragment or "")
    soup = BeautifulSoup(fragment, "html.parser")
    text = soup.get_text(" ", strip=True)
    return clean_text(text)


def extract_key_ingredients(soup: BeautifulSoup) -> str:
    items = []
    for item in soup.select("ul.b-product_ingredients-list li.b-product_ingredients-item"):
        term = item.select_one("span.b-product_ingredients-list_term")
        description = item.select_one("div.b-product_ingredients-list_description")
        term_text = clean_text(term.get_text(" ", strip=True)) if term else ""
        desc_text = ""
        if description:
            desc_text = clean_text(description.get_text(" ", strip=True))
            if term_text and desc_text.lower().startswith(term_text.lower()):
                desc_text = clean_text(desc_text[len(term_text):])
        if term_text and desc_text:
            items.append(f"{term_text} {desc_text}".strip())
        elif term_text:
            items.append(term_text.strip())
        elif desc_text:
            items.append(desc_text.strip())
    return "; ".join(items)


def extract_all_ingredients(soup: BeautifulSoup) -> str:
    candidates = []
    modal = soup.select_one("div[data-id='seeAllIngredients']")
    if modal:
        nodes = modal.select("div.b-product_details-disclosure_content_inner[data-glossary-string]")
    else:
        nodes = soup.select("div.b-product_details-disclosure_content_inner[data-glossary-string]")

    for node in nodes:
        raw = node.get("data-glossary-string", "")
        text = extract_html_text(raw)
        if text.count(",") >= 3 and len(text) > 40:
            candidates.append(text)

    if candidates:
        return max(candidates, key=lambda value: value.count(","))
    return ""


def extract_usage_directions(soup: BeautifulSoup) -> str:
    usage_section = None
    for button in soup.select("button.b-accordion-button"):
        label = button.get_text(" ", strip=True).lower()
        if "usage" in label:
            usage_section = button.find_parent("div", class_="b-accordion-item")
            break

    if usage_section:
        glossary = usage_section.select_one("div[data-glossary-string]")
        if glossary:
            raw = glossary.get("data-glossary-string", "")
            fragment = html.unescape(raw)
            fragment_soup = BeautifulSoup(fragment, "html.parser")
            items = [clean_text(li.get_text(" ", strip=True)) for li in fragment_soup.find_all("li")]
            if items:
                return " | ".join(items)
            text = fragment_soup.get_text(" ", strip=True)
            if text:
                return clean_text(text)

    return ""


def extract_skin_types(soup: BeautifulSoup) -> str:
    best_section = None
    for button in soup.select("button.b-accordion-button"):
        label = button.get_text(" ", strip=True).lower()
        if "best for" in label:
            best_section = button.find_parent("div", class_="b-accordion-item")
            break

    if not best_section:
        return ""

    indicators = []
    for item in best_section.select(".b-product_indicators-item"):
        text = clean_text(item.get_text(" ", strip=True))
        if not text:
            continue
        lowered = text.lower()
        if lowered in {"am + pm", "am", "pm"}:
            continue
        if "gsr" in lowered:
            continue
        indicators.append(text)

    return ", ".join(dict.fromkeys(indicators))


def map_category(name: str, listing_category: str | None) -> str:
    normalized = f"{name} {listing_category or ''}".lower()

    keyword_map = [
        (["sunscreen", "spf"], "SPF / Sunscreen"),
        (["cleanser", "cleansing"], "Cleanser"),
        (["toner"], "Toner"),
        (["essence"], "Essence"),
        (["serum"], "Serum"),
        (["eye"], "Eye Cream"),
        (["mask"], "Mask"),
        (["peel"], "Peel"),
        (["scrub"], "Scrub"),
        (["retinol"], "Retinol"),
        (["mist", "hydro mist"], "Mist"),
        (["oil"], "Oil"),
        (["balm"], "Balm"),
        (["makeup remover"], "Makeup Remover"),
        (["spot"], "Spot Treatment"),
        (["exfoliant", "exfoliating", "polish", "pads"], "Exfoliant"),
        (["treatment", "repair", "brightening", "defense"], "Treatment"),
        (["body wash", "body cleanser"], "Body Wash"),
        (["body", "body lotion", "body emulsion", "body creme"], "Body Lotion"),
        (["lip"], "Lip Balm"),
        (["moisturizer", "creme", "cream", "lotion"], "Moisturizer"),
    ]

    for keywords, category in keyword_map:
        if any(keyword in normalized for keyword in keywords):
            return category

    if listing_category:
        return clean_text(listing_category)

    return ""


def scrape_product_details(url: str, product_name: str, category_hint: str | None) -> dict:
    html_text = fetch_html(url)
    soup = BeautifulSoup(html_text, "html.parser")

    description = ""
    description_block = soup.select_one("div.b-product_details-copy")
    if description_block:
        description = clean_text(description_block.get_text(" ", strip=True))

    key_ingredients = extract_key_ingredients(soup)
    all_ingredients = extract_all_ingredients(soup)
    usage_directions = extract_usage_directions(soup)
    skin_types = extract_skin_types(soup)
    category = map_category(product_name, category_hint)

    return {
        "description": description,
        "category": category,
        "key_ingredients": key_ingredients,
        "all_ingredients": all_ingredients,
        "usage_directions": usage_directions,
        "skin_types": skin_types,
    }


def write_details_csv(path: str, rows: list[dict]) -> None:
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "Product Name",
                "Matched Name",
                "Product URL",
                "Image URL",
                "Category",
                "Description",
                "Key Ingredients",
                "All Ingredients",
                "Usage Directions",
                "Skin Types",
                "Match Type",
            ],
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> None:
    parser = argparse.ArgumentParser(description="Scrape ZO Skin Health product images.")
    parser.add_argument("--list", default="ZO_Product_List.txt", help="Input product list file")
    parser.add_argument("--output", default="ZO_Result", help="Output base name (CSV)")
    parser.add_argument("--base-url", default=BASE_URL, help="Base shop URL")
    parser.add_argument("--max-loads", type=int, default=3, help="Max load more clicks")
    args = parser.parse_args()

    targets = read_product_list(args.list)
    scraped = collect_all_products(args.base_url, args.max_loads)
    matches, missing = match_products(targets, scraped)
    csv_path, missing_path = write_results(args.output, matches, missing)

    match_lookup = {match["list_name"]: match for match in matches}
    detail_rows = []
    for product_name in targets:
        output_name = strip_staff_order(product_name)
        match = match_lookup.get(product_name)
        if not match or not match.get("product_url"):
            detail_rows.append({
                "Product Name": output_name,
                "Matched Name": match.get("scraped_name", "") if match else "",
                "Product URL": match.get("product_url", "") if match else "",
                "Image URL": match.get("image_url", "") if match else "",
                "Category": "",
                "Description": "",
                "Key Ingredients": "",
                "All Ingredients": "",
                "Usage Directions": "",
                "Skin Types": "",
                "Match Type": match.get("match_type", "missing") if match else "missing",
            })
            continue

        details = scrape_product_details(
            match["product_url"],
            product_name,
            match.get("category_hint", ""),
        )
        detail_rows.append({
            "Product Name": output_name,
            "Matched Name": match.get("scraped_name", ""),
            "Product URL": match.get("product_url", ""),
            "Image URL": match.get("image_url", ""),
            "Category": details.get("category", ""),
            "Description": details.get("description", ""),
            "Key Ingredients": details.get("key_ingredients", ""),
            "All Ingredients": details.get("all_ingredients", ""),
            "Usage Directions": details.get("usage_directions", ""),
            "Skin Types": details.get("skin_types", ""),
            "Match Type": match.get("match_type", ""),
        })
        time.sleep(0.4)

    write_details_csv("ZO_Details_Results.csv", detail_rows)

    print(f"Scraped {len(scraped)} products.")
    print(f"Matched {len(matches)} list items.")
    print(f"Wrote {csv_path}")
    print(f"Wrote {missing_path}")
    print("Wrote ZO_Details_Results.csv")


if __name__ == "__main__":
    main()
