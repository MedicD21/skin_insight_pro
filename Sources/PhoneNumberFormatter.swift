import Foundation

extension String {
    /// Formats a phone number string to (XXX) XXX-XXXX format
    /// Supports US phone numbers with 10 digits
    func formatPhoneNumber() -> String {
        // Remove all non-numeric characters
        let digits = self.filter { $0.isNumber }

        // Limit to 10 digits
        let limitedDigits = String(digits.prefix(10))

        // Format based on length
        if limitedDigits.count <= 3 {
            return limitedDigits
        } else if limitedDigits.count <= 6 {
            let areaCode = limitedDigits.prefix(3)
            let prefix = limitedDigits.dropFirst(3)
            return "(\(areaCode)) \(prefix)"
        } else {
            let areaCode = limitedDigits.prefix(3)
            let prefix = limitedDigits.dropFirst(3).prefix(3)
            let lineNumber = limitedDigits.dropFirst(6)
            return "(\(areaCode)) \(prefix)-\(lineNumber)"
        }
    }

    /// Removes all phone number formatting, leaving only digits
    func unformatPhoneNumber() -> String {
        return self.filter { $0.isNumber }
    }
}
