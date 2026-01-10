import Foundation
import UIKit
import Vision

struct ProductScrapeResult: Hashable {
    let sourceURL: URL
    var name: String?
    var brand: String?
    var category: String?
    var description: String?
    var ingredients: String?
    var allIngredients: String?
    var usageGuidelines: String?
    var imageUrl: String?
    var price: Double?
    var priceCurrency: String?
    var notes: [String]
}

final class ProductScraper {
    static let shared = ProductScraper()
    private init() {}

    private struct ImageTag {
        let src: String?
        let alt: String?
        let title: String?
    }

    func scrapeProduct(from url: URL, includeImageOCR: Bool = true) async throws -> ProductScrapeResult {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw URLError(.cannotDecodeContentData)
        }

        var result = ProductScrapeResult(sourceURL: url, notes: [])

        let metaTags = parseMetaTags(from: html)
        let jsonLdObjects = extractJsonLdObjects(from: html)
        let embeddedJsonObjects = extractEmbeddedJsonObjects(from: html)
        let imageTags = parseImageTags(from: html)
        let urlBrand = inferBrand(from: url)
        let footerBrand = extractFooterBrand(from: html)
        let embedded = extractFromEmbeddedJson(embeddedJsonObjects, baseURL: url)
        if let product = findProductJsonLd(in: jsonLdObjects) {
            result.name = product["name"] as? String
            result.description = product["description"] as? String
            result.category = product["category"] as? String ?? product["itemCategory"] as? String

            if let brandValue = product["brand"] {
                if let brandDict = brandValue as? [String: Any] {
                    result.brand = brandDict["name"] as? String
                } else if let brandString = brandValue as? String {
                    result.brand = brandString
                }
            }

            if let imageValue = product["image"] {
                result.imageUrl = extractImageUrl(from: imageValue, baseURL: url)
            }

            if let ingredientsValue = product["ingredients"] as? String {
                result.allIngredients = ingredientsValue
                result.ingredients = result.ingredients ?? ingredientsValue
            } else if let ingredientValue = product["ingredient"] as? String {
                result.allIngredients = ingredientValue
                result.ingredients = result.ingredients ?? ingredientValue
            }

            if let offersValue = product["offers"] {
                let offers = extractOffers(from: offersValue)
                if result.price == nil {
                    result.price = offers.price
                }
                if result.priceCurrency == nil {
                    result.priceCurrency = offers.currency
                }
            }
        }

        if result.name == nil {
            result.name = embedded.name
        }
        if result.name == nil {
            result.name = itempropContent(from: html, name: "name")
        }
        if result.name == nil {
            result.name = metaContent(metaTags, key: "og:title") ?? extractTitle(from: html)
        }
        if result.description == nil {
            result.description = embedded.description
        }
        if result.description == nil {
            result.description = itempropContent(from: html, name: "description")
        }
        if result.description == nil {
            result.description = metaContent(metaTags, key: "og:description")
                ?? metaContent(metaTags, key: "description")
        }
        if result.imageUrl == nil {
            result.imageUrl = embedded.imageUrl
        }
        if result.imageUrl == nil {
            if let itempropImage = itempropContent(from: html, name: "image") {
                result.imageUrl = resolveURL(itempropImage, baseURL: url)
            }
        }
        if result.imageUrl == nil {
            if let metaImage = metaContent(metaTags, key: "og:image") {
                result.imageUrl = resolveURL(metaImage, baseURL: url)
            }
        }
        if result.brand == nil {
            result.brand = embedded.brand
        }
        if result.brand == nil {
            result.brand = itempropContent(from: html, name: "brand")
        }
        if result.brand == nil {
            result.brand = metaContent(metaTags, key: "product:brand")
                ?? metaContent(metaTags, key: "og:site_name")
        }
        if result.brand == nil {
            result.brand = urlBrand
        }
        if result.price == nil {
            result.price = embedded.price
        }
        if result.price == nil {
            if let itempropPrice = itempropContent(from: html, name: "price") {
                result.price = parsePrice(itempropPrice)
            }
        }
        if result.price == nil {
            if let priceValue = metaContent(metaTags, key: "product:price:amount")
                ?? metaContent(metaTags, key: "og:price:amount") {
                result.price = parsePrice(priceValue)
            }
        }
        if result.priceCurrency == nil {
            result.priceCurrency = embedded.priceCurrency
        }
        if result.priceCurrency == nil {
            result.priceCurrency = itempropContent(from: html, name: "priceCurrency")
        }
        if result.priceCurrency == nil {
            result.priceCurrency = metaContent(metaTags, key: "product:price:currency")
                ?? metaContent(metaTags, key: "og:price:currency")
        }
        if result.ingredients == nil {
            let extracted = embedded.keyIngredients ?? extractSectionText(from: html, labels: ["Key Ingredients", "Ingredients"])
            result.ingredients = sanitizeIngredientText(extracted, labels: ["Key Ingredients", "Ingredients"])
        }
        if result.ingredients == nil {
            result.ingredients = extractKeyIngredientsList(from: html)
        }
        if result.allIngredients == nil {
            let extracted = embedded.allIngredients ?? extractSectionText(from: html, labels: ["Full Ingredients", "Ingredient List", "Ingredients"])
            result.allIngredients = sanitizeIngredientText(extracted, labels: ["Full Ingredients", "Ingredient List", "Ingredients"])
        }
        if result.usageGuidelines == nil {
            result.usageGuidelines = embedded.usage ?? extractSectionText(from: html, labels: ["How to Use", "Directions", "Usage", "Application"])
        }
        if result.usageGuidelines == nil {
            result.usageGuidelines = extractDirectionsText(from: html)
        }

        if result.imageUrl == nil {
            result.imageUrl = selectImageUrl(from: imageTags, baseURL: url, name: result.name, brand: result.brand)
        }

        if result.name == nil {
            result.name = inferName(from: imageTags, brand: result.brand)
        }
        if result.brand == nil || isGenericBrand(result.brand) {
            result.brand = inferBrand(from: imageTags) ?? result.brand
        }

        var ocrCombinedText: String?
        if includeImageOCR {
            let ocrUrls = rankedImageUrls(from: imageTags, baseURL: url, name: result.name, brand: result.brand)
            let ocrTexts = await extractTextFromImages(ocrUrls, maxImages: 10)
            let combinedText = ocrTexts.joined(separator: "\n")
            ocrCombinedText = combinedText
            if !combinedText.isEmpty {
                applyOCRText(combinedText, to: &result)
            }
        }

        result.brand = resolveBrand(
            current: result.brand,
            urlBrand: urlBrand,
            imageBrand: inferBrand(from: imageTags),
            footerBrand: footerBrand,
            ocrText: ocrCombinedText
        )

        result.name = cleanedText(result.name)
        result.brand = normalizeBrandName(cleanedText(result.brand))
        result.category = cleanedText(result.category)
        result.description = cleanedText(result.description)
        result.ingredients = sanitizeIngredientText(cleanedText(result.ingredients), labels: ["Key Ingredients", "Ingredients"])
        result.allIngredients = sanitizeIngredientText(cleanedText(result.allIngredients), labels: ["Full Ingredients", "Ingredient List", "Ingredients"])
        result.usageGuidelines = cleanedText(result.usageGuidelines)

        if result.name == nil { result.notes.append("Product name not found") }
        if result.brand == nil { result.notes.append("Brand not found") }
        if result.imageUrl == nil { result.notes.append("Product image not found") }
        if result.description == nil { result.notes.append("Description not found") }
        if result.ingredients == nil && result.allIngredients == nil { result.notes.append("Ingredients not found") }
        if result.price == nil { result.notes.append("Price not found") }

        return result
    }

    private func parseMetaTags(from html: String) -> [[String: String]] {
        let pattern = "<meta\\s+[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsHtml = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        var tags: [[String: String]] = []

        let attributeRegex = try? NSRegularExpression(pattern: "([a-zA-Z:-]+)\\s*=\\s*\"([^\"]*)\"|([a-zA-Z:-]+)\\s*=\\s*'([^']*)'", options: [])

        for match in matches {
            let tag = nsHtml.substring(with: match.range)
            let nsTag = tag as NSString
            let attrMatches = attributeRegex?.matches(in: tag, range: NSRange(location: 0, length: nsTag.length)) ?? []
            var attributes: [String: String] = [:]

            for attrMatch in attrMatches {
                if attrMatch.range(at: 1).location != NSNotFound {
                    let key = nsTag.substring(with: attrMatch.range(at: 1)).lowercased()
                    let value = nsTag.substring(with: attrMatch.range(at: 2))
                    attributes[key] = value
                } else if attrMatch.range(at: 3).location != NSNotFound {
                    let key = nsTag.substring(with: attrMatch.range(at: 3)).lowercased()
                    let value = nsTag.substring(with: attrMatch.range(at: 4))
                    attributes[key] = value
                }
            }

            if !attributes.isEmpty {
                tags.append(attributes)
            }
        }

        return tags
    }

    private func extractEmbeddedJsonObjects(from html: String) -> [Any] {
        let pattern = "<script[^>]*>(.*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let nsHtml = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        var objects: [Any] = []

        for match in matches {
            let content = nsHtml.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            guard content.first == "{" || content.first == "[" else { continue }
            guard content.count < 5_000_000 else { continue }
            guard let data = content.data(using: .utf8) else { continue }
            if let json = try? JSONSerialization.jsonObject(with: data) {
                objects.append(json)
            }
        }

        return objects
    }

    private func parseImageTags(from html: String) -> [ImageTag] {
        let pattern = "<img\\s+[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsHtml = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        let attributeRegex = try? NSRegularExpression(pattern: "([a-zA-Z:-]+)\\s*=\\s*\\\"([^\\\"]*)\\\"|([a-zA-Z:-]+)\\s*=\\s*'([^']*)'", options: [])
        var tags: [ImageTag] = []

        for match in matches {
            let tag = nsHtml.substring(with: match.range)
            let nsTag = tag as NSString
            let attrMatches = attributeRegex?.matches(in: tag, range: NSRange(location: 0, length: nsTag.length)) ?? []
            var attributes: [String: String] = [:]

            for attrMatch in attrMatches {
                if attrMatch.range(at: 1).location != NSNotFound {
                    let key = nsTag.substring(with: attrMatch.range(at: 1)).lowercased()
                    let value = nsTag.substring(with: attrMatch.range(at: 2))
                    attributes[key] = value
                } else if attrMatch.range(at: 3).location != NSNotFound {
                    let key = nsTag.substring(with: attrMatch.range(at: 3)).lowercased()
                    let value = nsTag.substring(with: attrMatch.range(at: 4))
                    attributes[key] = value
                }
            }

            if attributes.isEmpty { continue }

            let src = attributes["src"]
                ?? attributes["data-src"]
                ?? attributes["data-original"]
                ?? extractFirstUrl(from: attributes["srcset"])
            let alt = attributes["alt"]
            let title = attributes["title"]

            if src != nil || alt != nil || title != nil {
                tags.append(ImageTag(src: src, alt: alt, title: title))
            }
        }

        return tags
    }

    private func metaContent(_ tags: [[String: String]], key: String) -> String? {
        let lowerKey = key.lowercased()
        if let match = tags.first(where: { $0["property"]?.lowercased() == lowerKey }) {
            return match["content"]
        }
        if let match = tags.first(where: { $0["name"]?.lowercased() == lowerKey }) {
            return match["content"]
        }
        return nil
    }

    private func itempropContent(from html: String, name: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let metaPattern = "<meta\\s+[^>]*itemprop=[\"']\(escaped)[\"'][^>]*>"
        if let metaMatch = firstTagMatch(pattern: metaPattern, in: html) {
            let attributes = parseAttributes(in: metaMatch)
            if let content = attributes["content"] {
                return content
            }
            if let value = attributes["value"] {
                return value
            }
        }

        let tagPattern = "<[^>]*itemprop=[\"']\(escaped)[\"'][^>]*>(.*?)</[^>]+>"
        if let inner = firstCaptureMatch(pattern: tagPattern, in: html) {
            return stripHTML(inner)
        }

        return nil
    }

    private func firstTagMatch(pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsHtml = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHtml.length)) else {
            return nil
        }
        return nsHtml.substring(with: match.range)
    }

    private func firstCaptureMatch(pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let nsHtml = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHtml.length)),
              match.numberOfRanges > 1 else {
            return nil
        }
        return nsHtml.substring(with: match.range(at: 1))
    }

    private func parseAttributes(in tag: String) -> [String: String] {
        let attributeRegex = try? NSRegularExpression(pattern: "([a-zA-Z:-]+)\\s*=\\s*\\\"([^\\\"]*)\\\"|([a-zA-Z:-]+)\\s*=\\s*'([^']*)'", options: [])
        let nsTag = tag as NSString
        let matches = attributeRegex?.matches(in: tag, range: NSRange(location: 0, length: nsTag.length)) ?? []
        var attributes: [String: String] = [:]

        for match in matches {
            if match.range(at: 1).location != NSNotFound {
                let key = nsTag.substring(with: match.range(at: 1)).lowercased()
                let value = nsTag.substring(with: match.range(at: 2))
                attributes[key] = value
            } else if match.range(at: 3).location != NSNotFound {
                let key = nsTag.substring(with: match.range(at: 3)).lowercased()
                let value = nsTag.substring(with: match.range(at: 4))
                attributes[key] = value
            }
        }

        return attributes
    }

    private func extractTitle(from html: String) -> String? {
        let pattern = "<title>(.*?)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: (html as NSString).length)) else {
            return nil
        }
        let title = (html as NSString).substring(with: match.range(at: 1))
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractJsonLdObjects(from html: String) -> [Any] {
        let pattern = "<script[^>]*type=\"application/ld\\+json\"[^>]*>(.*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let nsHtml = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        var objects: [Any] = []

        for match in matches {
            let jsonString = nsHtml.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = jsonString.data(using: .utf8) else { continue }
            if let json = try? JSONSerialization.jsonObject(with: data) {
                objects.append(json)
            }
        }
        return objects
    }

    private func findProductJsonLd(in objects: [Any]) -> [String: Any]? {
        for object in objects {
            if let product = extractProduct(from: object) {
                return product
            }
        }
        return nil
    }

    private func extractProduct(from object: Any) -> [String: Any]? {
        if let dict = object as? [String: Any] {
            if let product = matchProductDictionary(dict) {
                return product
            }
            if let graph = dict["@graph"] {
                return extractProduct(from: graph)
            }
            return nil
        }
        if let array = object as? [Any] {
            for item in array {
                if let product = extractProduct(from: item) {
                    return product
                }
            }
        }
        return nil
    }

    private func matchProductDictionary(_ dict: [String: Any]) -> [String: Any]? {
        if let typeValue = dict["@type"] {
            if let typeString = typeValue as? String, typeString.lowercased().contains("product") {
                return dict
            }
            if let typeArray = typeValue as? [String], typeArray.contains(where: { $0.lowercased().contains("product") }) {
                return dict
            }
        }
        return nil
    }

    private func extractImageUrl(from value: Any, baseURL: URL) -> String? {
        if let imageString = value as? String {
            return resolveURL(imageString, baseURL: baseURL)
        }
        if let images = value as? [Any] {
            for item in images {
                if let imageString = item as? String {
                    return resolveURL(imageString, baseURL: baseURL)
                }
            }
        }
        if let imageDict = value as? [String: Any], let url = imageDict["url"] as? String {
            return resolveURL(url, baseURL: baseURL)
        }
        return nil
    }

    private func extractOffers(from value: Any) -> (price: Double?, currency: String?) {
        if let dict = value as? [String: Any] {
            return extractOfferDetails(from: dict)
        }
        if let array = value as? [Any] {
            for item in array {
                if let dict = item as? [String: Any] {
                    let details = extractOfferDetails(from: dict)
                    if details.price != nil || details.currency != nil {
                        return details
                    }
                }
            }
        }
        return (nil, nil)
    }

    private func extractOfferDetails(from dict: [String: Any]) -> (price: Double?, currency: String?) {
        var price: Double?
        if let priceValue = dict["price"] {
            if let priceString = priceValue as? String {
                price = parsePrice(priceString)
            } else if let priceNumber = priceValue as? NSNumber {
                price = priceNumber.doubleValue
            }
        }
        let currency = dict["priceCurrency"] as? String
        return (price, currency)
    }

    private func extractSectionText(from html: String, labels: [String]) -> String? {
        let joinedLabels = labels.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let pattern = "(?is)(?:\\b(?:\(joinedLabels))\\b)[^<]{0,80}</[^>]+>\\s*<[^>]+>(.{20,600})<"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let nsHtml = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHtml.length)) else {
            return nil
        }
        let rawText = nsHtml.substring(with: match.range(at: 1))
        let cleaned = stripHTML(rawText)
        return cleaned
    }

    private func stripHTML(_ string: String) -> String {
        let withoutTags = string.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let decoded = withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&reg;", with: "®")
            .replacingOccurrences(of: "&#174;", with: "®")
            .replacingOccurrences(of: "&trade;", with: "™")
            .replacingOccurrences(of: "&#8482;", with: "™")
        return decoded.replacingOccurrences(of: "\\{\\{\\{.*?\\}\\}\\}", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : stripHTML(trimmed)
    }

    private func extractFromEmbeddedJson(_ objects: [Any], baseURL: URL? = nil) -> (name: String?, brand: String?, description: String?, imageUrl: String?, price: Double?, priceCurrency: String?, keyIngredients: String?, allIngredients: String?, usage: String?) {
        let name = findStringValue(in: objects, keys: ["name", "productname", "title"])
        let description = findStringValue(in: objects, keys: ["description", "shortdescription", "longdescription", "productdescription"])
        let brand = extractBrandValue(in: objects)
        let keyIngredients = findStringValue(in: objects, keys: ["keyingredients", "activeingredients", "heroingredients", "featuredingredients"])
        let allIngredients = findStringValue(in: objects, keys: ["ingredients", "ingredientlist", "fullingredients", "inci"])
        let usage = findStringValue(in: objects, keys: ["howtouse", "directions", "usage", "application", "instructions"])
        let price = findNumberValue(in: objects, keys: ["price", "pricevalue", "priceamount", "currentprice", "saleprice"])
        let priceCurrency = findStringValue(in: objects, keys: ["pricecurrency", "currency"])

        let imageRaw = findImageValue(in: objects)
        let imageUrl = baseURL.flatMap { resolveURL(imageRaw ?? "", baseURL: $0) } ?? imageRaw

        return (name, brand, description, imageUrl, price, priceCurrency, keyIngredients, allIngredients, usage)
    }

    private func findStringValue(in objects: [Any], keys: [String]) -> String? {
        for object in objects {
            if let found = findStringValue(in: object, keys: keys) {
                return found
            }
        }
        return nil
    }

    private func findStringValue(in object: Any, keys: [String]) -> String? {
        let loweredKeys = Set(keys.map { $0.lowercased() })

        if let dict = object as? [String: Any] {
            for (key, value) in dict {
                let lowered = key.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
                if loweredKeys.contains(lowered), let stringValue = value as? String, !stringValue.isEmpty {
                    return stringValue
                }
                if let nested = findStringValue(in: value, keys: keys) {
                    return nested
                }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let nested = findStringValue(in: item, keys: keys) {
                    return nested
                }
            }
        }

        return nil
    }

    private func findNumberValue(in objects: [Any], keys: [String]) -> Double? {
        for object in objects {
            if let found = findNumberValue(in: object, keys: keys) {
                return found
            }
        }
        return nil
    }

    private func findNumberValue(in object: Any, keys: [String]) -> Double? {
        let loweredKeys = Set(keys.map { $0.lowercased() })

        if let dict = object as? [String: Any] {
            for (key, value) in dict {
                let lowered = key.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
                if loweredKeys.contains(lowered) {
                    if let number = value as? NSNumber {
                        return number.doubleValue
                    }
                    if let stringValue = value as? String, let parsed = parsePrice(stringValue) {
                        return parsed
                    }
                }
                if let nested = findNumberValue(in: value, keys: keys) {
                    return nested
                }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let nested = findNumberValue(in: item, keys: keys) {
                    return nested
                }
            }
        }

        return nil
    }

    private func findImageValue(in objects: [Any]) -> String? {
        for object in objects {
            if let found = findImageValue(in: object) {
                return found
            }
        }
        return nil
    }

    private func findImageValue(in object: Any) -> String? {
        let keys = ["image", "images", "productimage", "primaryimage", "heroimage", "thumbnail"]
        let loweredKeys = Set(keys.map { $0.lowercased() })

        if let dict = object as? [String: Any] {
            for (key, value) in dict {
                let lowered = key.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
                if loweredKeys.contains(lowered) {
                    if let stringValue = value as? String {
                        return stringValue
                    }
                    if let arrayValue = value as? [Any] {
                        for item in arrayValue {
                            if let stringValue = item as? String {
                                return stringValue
                            }
                        }
                    }
                }
                if let nested = findImageValue(in: value) {
                    return nested
                }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let nested = findImageValue(in: item) {
                    return nested
                }
            }
        }

        return nil
    }

    private func extractBrandValue(in objects: [Any]) -> String? {
        for object in objects {
            if let found = extractBrandValue(in: object) {
                return found
            }
        }
        return nil
    }

    private func extractBrandValue(in object: Any) -> String? {
        let keys = ["brand", "brandname", "manufacturer"]
        let loweredKeys = Set(keys.map { $0.lowercased() })

        if let dict = object as? [String: Any] {
            for (key, value) in dict {
                let lowered = key.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
                if loweredKeys.contains(lowered) {
                    if let stringValue = value as? String, !stringValue.isEmpty {
                        return stringValue
                    }
                    if let brandDict = value as? [String: Any], let name = brandDict["name"] as? String {
                        return name
                    }
                }
                if let nested = extractBrandValue(in: value) {
                    return nested
                }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let nested = extractBrandValue(in: item) {
                    return nested
                }
            }
        }

        return nil
    }

    private func inferBrand(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        if host.contains("skinceuticals") {
            return "SkinCeuticals"
        }
        if host.contains("zoskinhealth") {
            return "ZO Skin Health"
        }
        let components = host.split(separator: ".")
        guard let root = components.first else { return nil }
        let sanitized = root.replacingOccurrences(of: "-", with: " ")
        return sanitized.isEmpty ? nil : sanitized.capitalized
    }

    private func inferBrand(from imageTags: [ImageTag]) -> String? {
        let candidates = imageTags.compactMap { $0.alt ?? $0.title }
        for text in candidates {
            let cleaned = text.lowercased()
            if cleaned.contains("skinceuticals") {
                return "SkinCeuticals"
            }
            if cleaned.contains("zo skin health") || cleaned.contains("zoskinhealth") {
                return "ZO Skin Health"
            }
        }
        return nil
    }

    private func resolveBrand(current: String?, urlBrand: String?, imageBrand: String?, footerBrand: String?, ocrText: String?) -> String? {
        var selected = normalizeBrandName(current)
        let normalizedUrl = normalizeBrandName(urlBrand)
        let normalizedImage = normalizeBrandName(imageBrand)
        let normalizedFooter = normalizeBrandName(footerBrand)
        let normalizedOCR = normalizeBrandName(extractBrandFromText(ocrText, urlBrand: normalizedUrl))

        if let normalizedUrl {
            if selected == nil || isGenericBrand(selected) || !brandMatches(selected, normalizedUrl) {
                selected = normalizedUrl
            }
        }

        if let normalizedOCR {
            if selected == nil || isGenericBrand(selected) || brandMatches(normalizedOCR, normalizedUrl) {
                selected = normalizedOCR
            }
        }

        if let normalizedFooter {
            if selected == nil || isGenericBrand(selected) || brandMatches(normalizedFooter, normalizedUrl) {
                selected = normalizedFooter
            }
        }

        if let normalizedImage {
            if selected == nil || isGenericBrand(selected) {
                selected = normalizedImage
            }
        }

        return selected
    }

    private func extractBrandFromText(_ text: String?, urlBrand: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        let lower = text.lowercased()
        if lower.contains("skinceuticals") {
            return "SkinCeuticals"
        }
        if lower.contains("zo skin health") || lower.contains("zoskinhealth") {
            return "ZO Skin Health"
        }
        if let urlBrand, lower.contains(urlBrand.lowercased()) {
            return urlBrand
        }
        return nil
    }

    private func normalizeBrandName(_ value: String?) -> String? {
        guard let value else { return nil }
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let separators = ["|", "–", "-", "—", "•"]
        for separator in separators {
            if trimmed.contains(separator) {
                trimmed = trimmed.components(separatedBy: separator).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
            }
        }

        let lower = trimmed.lowercased()
        if lower.contains("skinceuticals") {
            return "SkinCeuticals"
        }
        if lower.contains("zo skin health") || lower.contains("zoskinhealth") || lower.contains("zo® skin health") {
            return "ZO Skin Health"
        }

        let suffixes = ["official site", "official", "site", "store", "shop", "skincare", "products"]
        for suffix in suffixes {
            if lower.hasSuffix(suffix) {
                trimmed = trimmed.replacingOccurrences(of: suffix, with: "", options: [.caseInsensitive, .regularExpression])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return trimmed.isEmpty ? nil : trimmed
    }

    private func brandMatches(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs else { return false }
        let left = lhs.lowercased()
        let right = rhs.lowercased()
        return left.contains(right) || right.contains(left)
    }

    private func isGenericBrand(_ value: String?) -> Bool {
        guard let value else { return true }
        let lower = value.lowercased()
        let genericMarkers = ["official", "site", "shop", "store", "skincare", "products"]
        return genericMarkers.contains(where: { lower.contains($0) })
    }

    private func extractFooterBrand(from html: String) -> String? {
        let lowerHtml = html.lowercased()
        if lowerHtml.contains("zo skin health") || lowerHtml.contains("zo® skin health") || lowerHtml.contains("zoskinhealth") {
            return "ZO Skin Health"
        }
        if lowerHtml.contains("skinceuticals") {
            return "SkinCeuticals"
        }

        let pattern = "©\\s*\\d{4}[^<]{0,80}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsHtml = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHtml.length)) else {
            return nil
        }
        let snippet = nsHtml.substring(with: match.range)
        return normalizeBrandName(stripHTML(snippet))
    }

    private func inferName(from imageTags: [ImageTag], brand: String?) -> String? {
        let candidates = imageTags.compactMap { $0.alt ?? $0.title }
            .map { stripHTML($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 6 }

        let filtered = candidates.filter { text in
            let lower = text.lowercased()
            let blocked = ["logo", "icon", "badge", "thumbnail"]
            return !blocked.contains(where: { lower.contains($0) })
        }

        for text in filtered {
            if let brand, text.lowercased().hasPrefix(brand.lowercased()) {
                let trimmed = text.dropFirst(brand.count).trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return String(trimmed) }
            }
        }

        return filtered.sorted { $0.count > $1.count }.first
    }

    private func selectImageUrl(from tags: [ImageTag], baseURL: URL, name: String?, brand: String?) -> String? {
        let nameToken = name?.lowercased()
        let brandToken = brand?.lowercased()

        let prioritized = tags.sorted { lhs, rhs in
            scoreImageTag(lhs, nameToken: nameToken, brandToken: brandToken) >
                scoreImageTag(rhs, nameToken: nameToken, brandToken: brandToken)
        }

        for tag in prioritized {
            if let src = tag.src, let resolved = resolveURL(src, baseURL: baseURL) {
                return resolved
            }
        }
        return nil
    }

    private func scoreImageTag(_ tag: ImageTag, nameToken: String?, brandToken: String?) -> Int {
        var score = 0
        let text = [tag.alt, tag.title].compactMap { $0?.lowercased() }.joined(separator: " ")
        if let nameToken, text.contains(nameToken) { score += 3 }
        if let brandToken, text.contains(brandToken) { score += 2 }
        if text.contains("product") { score += 1 }
        return score
    }

    private func rankedImageUrls(from tags: [ImageTag], baseURL: URL, name: String?, brand: String?) -> [String] {
        let nameToken = name?.lowercased()
        let brandToken = brand?.lowercased()

        let scored = tags.compactMap { tag -> (url: String, score: Int)? in
            guard let src = tag.src, let resolved = resolveURL(src, baseURL: baseURL) else { return nil }
            if shouldSkipImageUrl(resolved) { return nil }
            let score = scoreImageTag(tag, nameToken: nameToken, brandToken: brandToken)
            return (resolved, score)
        }

        let sorted = scored.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.url.count > rhs.url.count
            }
            return lhs.score > rhs.score
        }

        var unique: [String] = []
        var seen = Set<String>()
        for item in sorted {
            if seen.insert(item.url).inserted {
                unique.append(item.url)
            }
        }
        return unique
    }

    private func shouldSkipImageUrl(_ url: String) -> Bool {
        let lowered = url.lowercased()
        let blocked = ["sprite", "icon", "logo", "badge", "swatch", "placeholder"]
        if blocked.contains(where: { lowered.contains($0) }) {
            return true
        }
        if lowered.hasSuffix(".svg") || lowered.hasSuffix(".gif") {
            return true
        }
        return false
    }

    private func extractTextFromImages(_ urls: [String], maxImages: Int) async -> [String] {
        var results: [String] = []
        let capped = urls.prefix(maxImages)

        for urlString in capped {
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else { continue }
                guard data.count < 6_000_000 else { continue }
                guard let image = UIImage(data: data), let cgImage = image.cgImage else { continue }
                let recognized = try recognizeText(in: cgImage)
                if !recognized.isEmpty {
                    results.append(recognized.joined(separator: " "))
                }
            } catch {
                continue
            }
        }

        return results
    }

    private func recognizeText(in image: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en_US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        var lines: [String] = []
        lines.reserveCapacity(observations.count)
        for observation in observations {
            if let candidate = observation.topCandidates(1).first {
                lines.append(candidate.string)
            }
        }
        return lines
    }

    private func applyOCRText(_ text: String, to result: inout ProductScrapeResult) {
        let normalized = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if result.brand == nil {
            if normalized.lowercased().contains("skinceuticals") {
                result.brand = "SkinCeuticals"
            }
        }

        if result.name == nil {
            if let candidate = extractNameCandidate(from: normalized, brand: result.brand) {
                result.name = candidate
            }
        }

        if result.allIngredients == nil {
            if let ingredients = extractIngredients(from: normalized) {
                let sanitized = sanitizeIngredientText(ingredients, labels: ["Ingredients"])
                result.allIngredients = sanitized
                if result.ingredients == nil {
                    result.ingredients = sanitized
                }
            }
        }
    }

    private func extractNameCandidate(from text: String, brand: String?) -> String? {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let brand {
            for line in lines {
                if line.lowercased().contains(brand.lowercased()) {
                    return line
                }
            }
        }
        return lines.first { $0.count >= 6 }
    }

    private func extractIngredients(from text: String) -> String? {
        let lower = text.lowercased()
        guard let range = lower.range(of: "ingredients") else { return nil }
        let substring = text[range.upperBound...]
        let terminators = ["directions", "how to use", "usage", "apply"]
        var endIndex = substring.endIndex
        for term in terminators {
            if let termRange = substring.lowercased().range(of: term) {
                endIndex = termRange.lowerBound
                break
            }
        }
        let raw = substring[..<endIndex]
        let cleaned = raw
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitizeIngredientText(cleaned, labels: ["Ingredients"])
    }

    private func sanitizeIngredientText(_ value: String?, labels: [String]) -> String? {
        guard var value else { return nil }
        value = stripHTML(value).trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }

        let lowerValue = value.lowercased()
        for label in labels {
            let lowerLabel = label.lowercased()
            if lowerValue == lowerLabel {
                return nil
            }
            if lowerValue.hasPrefix(lowerLabel) {
                let remainder = value.dropFirst(label.count).trimmingCharacters(in: .whitespacesAndNewlines)
                if remainder.isEmpty { return nil }
                value = String(remainder)
            }
        }

        value = normalizeIngredientSpacing(value)

        let separators = [",", ";", "•", "/", " and "]
        let hasSeparator = separators.contains(where: { value.lowercased().contains($0) })
        if !hasSeparator && value.split(separator: " ").count < 2 {
            return nil
        }

        return value
    }

    private func normalizeIngredientSpacing(_ text: String) -> String {
        var value = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Fix split words like "en vironmental"
        value = value.replacingOccurrences(
            of: "\\b([a-z]{2,})\\s+([a-z]{2,})\\b",
            with: "$1$2",
            options: .regularExpression
        )

        // Insert spacing after commas and colons
        value = value.replacingOccurrences(of: "\\s*,\\s*", with: ", ", options: .regularExpression)
        value = value.replacingOccurrences(of: "\\s*:\\s*", with: ": ", options: .regularExpression)

        // Normalize list separators
        value = value.replacingOccurrences(of: "\\s*;\\s*", with: "; ", options: .regularExpression)

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractKeyIngredientsList(from html: String) -> String? {
        let pattern = "<ul[^>]*class=\\\"[^\\\"]*b-product_ingredients-list[^\\\"]*\\\"[^>]*>(.*?)</ul>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let nsHtml = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHtml.length)) else {
            return nil
        }
        let listHtml = nsHtml.substring(with: match.range(at: 1))
        let itemPattern = "<li[^>]*>(.*?)</li>"
        guard let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let items = itemRegex.matches(in: listHtml, range: NSRange(location: 0, length: (listHtml as NSString).length))
        var results: [String] = []
        for item in items {
            let raw = (listHtml as NSString).substring(with: item.range(at: 1))
            let cleaned = stripHTML(raw)
            if !cleaned.isEmpty {
                results.append(cleaned)
            }
        }
        var seen = Set<String>()
        let ordered = results.filter { seen.insert($0).inserted }
        return ordered.isEmpty ? nil : ordered.joined(separator: ", ")
    }

    private func extractDirectionsText(from html: String) -> String? {
        let pattern = "<h3[^>]*>\\s*Directions\\s*</h3>(.*?)</div>\\s*</div>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let nsHtml = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHtml.length)) else {
            return nil
        }
        let raw = nsHtml.substring(with: match.range(at: 1))
        let cleaned = stripHTML(raw)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func extractFirstUrl(from srcset: String?) -> String? {
        guard let srcset, !srcset.isEmpty else { return nil }
        let firstPart = srcset.split(separator: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let urlPart = firstPart.split(separator: " ").first ?? ""
        return urlPart.isEmpty ? nil : String(urlPart)
    }

    private func resolveURL(_ value: String, baseURL: URL) -> String? {
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value) {
            if url.scheme != nil {
                return url.absoluteString
            }
            if let absolute = URL(string: value, relativeTo: baseURL) {
                return absolute.absoluteString
            }
        }
        return nil
    }

    private func parsePrice(_ value: String) -> Double? {
        let cleaned = value
            .replacingOccurrences(of: "[^0-9\\.]", with: "", options: .regularExpression)
        return Double(cleaned)
    }
}
