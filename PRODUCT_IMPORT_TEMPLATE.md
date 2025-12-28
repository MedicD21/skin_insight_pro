# Product Import Template

Use this template to bulk import products into your Product Catalog.

## CSV Template Format

Create a CSV file with the following columns (in this exact order):

```
name,brand,category,description,ingredients,skin_types,concerns,price,image_url,is_active
```

## Column Descriptions

| Column | Required | Type | Description | Example |
|--------|----------|------|-------------|---------|
| `name` | Yes | Text | Product name | Hydrating Serum |
| `brand` | Yes | Text | Brand name | CeraVe |
| `category` | Yes | Text | Product category | Serum |
| `description` | No | Text | Product description | Lightweight hydrating serum for all skin types |
| `ingredients` | No | Text | Key ingredients | Hyaluronic Acid, Ceramides, Niacinamide |
| `skin_types` | No | Text (comma-separated) | Suitable skin types | Normal,Dry,Combination |
| `concerns` | No | Text (comma-separated) | Addresses concerns | Dryness,Fine Lines |
| `price` | No | Number | Product price | 24.99 |
| `image_url` | No | URL | Image URL (leave empty to upload later) | https://example.com/image.jpg |
| `is_active` | No | Boolean | Active status (TRUE/FALSE) | TRUE |

## Valid Values

### Skin Types
Choose from: `Normal`, `Dry`, `Oily`, `Combination`, `Sensitive`

Multiple values should be separated by commas (no spaces): `Normal,Dry,Combination`

### Concerns
Choose from: `Acne`, `Aging`, `Dark Spots`, `Redness`, `Dryness`, `Oiliness`, `Fine Lines`, `Pores`

Multiple values should be separated by commas (no spaces): `Acne,Oiliness,Pores`

### Price
- Use decimal format: `24.99`
- Do not include currency symbols
- Leave empty if price is not available

### Image URL
- Must be a valid HTTPS URL
- Leave empty to upload images manually later
- Supported formats: JPG, PNG

### Is Active
- Use `TRUE` for active products
- Use `FALSE` for inactive products
- Defaults to `TRUE` if empty

## Sample CSV Template

Download this sample and edit with your products:

```csv
name,brand,category,description,ingredients,skin_types,concerns,price,image_url,is_active
Hydrating Serum,CeraVe,Serum,Lightweight hydrating serum for all skin types,Hyaluronic Acid,Normal,Dryness,24.99,,TRUE
Gentle Cleanser,La Roche-Posay,Cleanser,Mild foaming cleanser for sensitive skin,Glycerin,Sensitive,Redness,18.50,,TRUE
Retinol Night Cream,The Ordinary,Moisturizer,Anti-aging night treatment with retinol,Retinol,Normal,Aging,12.99,,TRUE
Vitamin C Serum,Skinceuticals,Serum,Brightening serum with pure vitamin C,L-Ascorbic Acid,Normal,Dark Spots,165.00,,TRUE
Niacinamide Solution,The Ordinary,Treatment,Pore-refining treatment,Niacinamide,Oily,Pores,6.50,,TRUE
```

## How to Import

1. Open the Product Catalog in the admin section
2. Tap the "Import Products" button
3. Select your CSV file
4. Review the preview of products to be imported
5. Tap "Import" to add all products to your catalog
6. Any errors will be shown for individual rows

## Tips

- Use a spreadsheet program (Excel, Google Sheets, Numbers) to create your CSV
- Ensure all required fields are filled
- Check for typos in skin types and concerns (must match exactly)
- Test with a small file first (2-3 products)
- Products are added to your personal catalog only
- You can edit products individually after importing

## Troubleshooting

### "Invalid skin type" error
- Check spelling and capitalization
- Use exact values: Normal, Dry, Oily, Combination, Sensitive
- No spaces in comma-separated lists

### "Invalid concern" error
- Check spelling and capitalization
- Use exact values: Acne, Aging, Dark Spots, Redness, Dryness, Oiliness, Fine Lines, Pores
- No spaces in comma-separated lists

### "Required field missing" error
- Ensure name, brand, and category are filled for every row
- Check for empty cells in required columns

### "Invalid price format" error
- Use numbers only (no $ symbol)
- Use decimal point for cents: 24.99

---

**Need help?** Check the example CSV above or import it as-is to see how products should be formatted.
