import Foundation

/// A built-in list of popular food-delivery services, used when a blocklist has
/// `blockFoodDelivery` on. Entries are apex domains; the matcher in
/// `BlockedDomains` also catches subdomains, so one entry covers a service's
/// website *and* its app — the apps hit the same domains (api., cdn., etc.), so
/// DNS-blocking the apex breaks the app's backend, not just the website.
///
/// Note on Uber Eats: its app runs on Uber's shared backend (uber.com), which
/// is deliberately NOT blocked here (that would also block Uber rides). So
/// ubereats.com blocks the website, but the Uber Eats app itself may still
/// work — add the app in the blocklist's Apps & categories picker to hard-block
/// it.
///
/// Curated, not exhaustive. Like all DNS filtering, a service using its own
/// encrypted DNS can bypass it; for a hard block, also add the app in the
/// blocklist's Apps & categories picker. Other services can be added by hand.
enum FoodDeliveryDomains {
    static let list: [String] = [
        // Restaurant delivery
        "doordash.com",
        "ubereats.com",
        "grubhub.com",
        "seamless.com",
        "postmates.com",
        "caviar.com",
        "trycaviar.com",
        "chownow.com",
        "slicelife.com",
        "toasttab.com",
        "ritual.co",
        "favordelivery.com",
        // Grocery / convenience delivery
        "instacart.com",
        "shipt.com",
        "gopuff.com",
        "freshdirect.com",
        "drizly.com",
        // International
        "deliveroo.com",
        "deliveroo.co.uk",
        "just-eat.com",
        "justeat.com",
        "just-eat.co.uk",
        "skipthedishes.com",
        "foodpanda.com",
        "swiggy.com",
        "zomato.com",
        "wolt.com",
        "glovoapp.com",
    ]
}
