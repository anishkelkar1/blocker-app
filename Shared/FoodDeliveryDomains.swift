import Foundation

/// A built-in list of popular food-delivery services, used when a blocklist has
/// `blockFoodDelivery` on. Entries are apex domains; the matcher in
/// `BlockedDomains` also catches subdomains, so one entry covers a service's
/// website *and* much of its app — the apps talk to these same domains, so
/// DNS-blocking them breaks the app too, not just the site.
///
/// Curated, not exhaustive. Like all DNS filtering, a service using its own
/// encrypted DNS can bypass it, and other services can be added to a blocklist
/// by hand on top of this.
enum FoodDeliveryDomains {
    static let list: [String] = [
        "doordash.com",
        "ubereats.com",
        "grubhub.com",
        "seamless.com",
        "postmates.com",
        "instacart.com",
        "caviar.com",
        "gopuff.com",
        "chownow.com",
        "slicelife.com",
        "toasttab.com",
        "deliveroo.com",
        "just-eat.com",
        "justeat.com",
        "skipthedishes.com",
        "foodpanda.com",
        "swiggy.com",
        "zomato.com",
        "wolt.com",
    ]
}
