import Foundation

enum StripeError: Error {
    case unauthorized
    case invalidResponse
    case networkError(Error)
}

struct MRRResult {
    let cents: Int
    let currency: String  // ISO 4217, e.g. "brl", "usd"
}

actor StripeService {
    private let apiKey: String
    private let baseURL = "https://api.stripe.com/v1"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func fetchMRR() async throws -> MRRResult {
        // Group MRR by currency (subscriptions may use different currencies)
        var mrrByCurrency: [String: Int] = [:]
        var startingAfter: String? = nil

        repeat {
            var urlString = "\(baseURL)/subscriptions?status=active&limit=100&expand[]=data.discount"
            if let cursor = startingAfter {
                urlString += "&starting_after=\(cursor)"
            }

            guard let url = URL(string: urlString) else {
                throw StripeError.invalidResponse
            }

            var request = URLRequest(url: url)
            let credentials = "\(apiKey):".data(using: .utf8)!.base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw StripeError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw StripeError.unauthorized
            }

            guard httpResponse.statusCode == 200 else {
                throw StripeError.invalidResponse
            }

            let list = try JSONDecoder().decode(SubscriptionList.self, from: data)

            for subscription in list.data {
                let currency = subscription.currency.lowercased()
                let amount = subscription.monthlyAmountCents
                mrrByCurrency[currency, default: 0] += amount
                fputs("SUB \(subscription.id) currency=\(currency) monthly=\(amount) cancel_at_period_end=\(subscription.cancel_at_period_end) discount=\(String(describing: subscription.discount?.coupon))\n", stderr)
            }

            if list.has_more, let last = list.data.last {
                startingAfter = last.id
            } else {
                startingAfter = nil
            }
        } while startingAfter != nil

        // Return the dominant currency (highest MRR)
        guard let (currency, cents) = mrrByCurrency.max(by: { $0.value < $1.value }) else {
            return MRRResult(cents: 0, currency: "usd")
        }

        return MRRResult(cents: cents, currency: currency)
    }
}

// MARK: - Codable Models

struct SubscriptionList: Codable {
    let data: [Subscription]
    let has_more: Bool
}

struct Subscription: Codable {
    let id: String
    let currency: String
    let cancel_at_period_end: Bool
    let items: SubscriptionItemList
    let discount: Discount?

    var monthlyAmountCents: Int {
        let raw = items.data.reduce(0) { $0 + $1.monthlyAmountCents }
        // Apply subscription-level discount if present
        if let coupon = discount?.coupon {
            if let off = coupon.percent_off {
                return raw - Int(Double(raw) * off / 100.0)
            } else if let off = coupon.amount_off {
                return max(0, raw - off)
            }
        }
        return raw
    }
}

struct SubscriptionItemList: Codable {
    let data: [SubscriptionItem]
}

struct SubscriptionItem: Codable {
    let price: Price
    let quantity: Int?

    var monthlyAmountCents: Int {
        let qty = quantity ?? 1
        let unitAmount = price.unit_amount ?? 0
        return price.recurring.map { recurring in
            switch recurring.interval {
            case "year":
                return (unitAmount * qty) / 12
            case "week":
                return (unitAmount * qty * 433) / 100
            case "day":
                return (unitAmount * qty * 3044) / 100
            default: // "month"
                return unitAmount * qty
            }
        } ?? 0
    }
}

struct Price: Codable {
    let unit_amount: Int?
    let recurring: Recurring?
}

struct Recurring: Codable {
    let interval: String
}

struct Discount: Codable {
    let coupon: Coupon?
}

struct Coupon: Codable {
    let percent_off: Double?
    let amount_off: Int?
}
