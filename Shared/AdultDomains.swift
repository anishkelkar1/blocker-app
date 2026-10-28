import Foundation

/// A built-in list of popular adult/pornography site domains, used when a
/// blocklist has `blockAdult` on. Entries are apex domains; the matcher in
/// `BlockedDomains` also catches their subdomains (m., www., etc.), so one
/// entry covers a site's variants.
///
/// This is a curated set of high-traffic sites, not an exhaustive filter — new
/// or niche sites can still slip through, and (like all DNS filtering) a browser
/// using its own encrypted DNS/DoH, such as Firefox, bypasses it unless the app
/// itself is blocked. Users can add specific domains to a blocklist on top of
/// this list.
enum AdultDomains {
    static let list: [String] = [
        "pornhub.com",
        "xvideos.com",
        "xnxx.com",
        "xhamster.com",
        "redtube.com",
        "youporn.com",
        "tube8.com",
        "spankbang.com",
        "youjizz.com",
        "porn.com",
        "porntrex.com",
        "hqporner.com",
        "eporner.com",
        "txxx.com",
        "hclips.com",
        "upornia.com",
        "thumbzilla.com",
        "pornhd.com",
        "tnaflix.com",
        "empflix.com",
        "keezmovies.com",
        "extremetube.com",
        "drtuber.com",
        "nuvid.com",
        "sunporno.com",
        "porn300.com",
        "pornone.com",
        "4tube.com",
        "gotporn.com",
        "beeg.com",
        "sex.com",
        "motherless.com",
        "fapello.com",
        "brazzers.com",
        "realitykings.com",
        "naughtyamerica.com",
        "bangbros.com",
        "onlyfans.com",
        "fansly.com",
        "chaturbate.com",
        "livejasmin.com",
        "bongacams.com",
        "stripchat.com",
        "cam4.com",
        "myfreecams.com",
        "camsoda.com",
        "rule34.xxx",
        "e-hentai.org",
        "nhentai.net",
        "hanime.tv",
        "hentaihaven.xxx",
        "ashemaletube.com",
        "pornpics.com",
        "imagefap.com",
        "redgifs.com",
        "adultfriendfinder.com",
    ]
}
