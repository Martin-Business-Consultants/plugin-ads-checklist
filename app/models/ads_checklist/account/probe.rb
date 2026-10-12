require "resolv"
require "ipaddr"
require "net/http"

module AdsChecklist
  # What can be found out about an ad account's website from outside, without logging in anywhere:
  # the domain's verifications in DNS (Google, Meta), how its addresses answer (HTTPS, where they
  # redirect), the landing page's ad tags (the Google tag and its conversion IDs, Analytics, Tag
  # Manager, the Meta Pixel and its events, consent banners, call links, forms, a privacy policy),
  # and what the public Tag Manager container loads. Every part fails on its own, as an `error` in
  # its facts. Only public addresses are fetched.
  class Account::Probe
    TIMEOUT = 8
    MAX_BODY = 5.megabytes
    MAX_REDIRECTS = 5
    USER_AGENT = "Runwell ad account audit"
    CONSENT_TOOLS = { "Cookiebot" => "cookiebot", "CookieYes" => "cookieyes", "OneTrust" => "onetrust", "Termly" => "termly",
                      "iubenda" => "iubenda", "Osano" => "osano", "Complianz" => "complianz", "Usercentrics" => "usercentrics",
                      "TrustArc" => "trustarc", "Shopify consent" => "customerPrivacy" }.freeze

    class Refused < StandardError; end

    attr_reader :domain, :files

    # "https://www.Example.com/about" → "example.com"
    def self.normalize(input)
      text = input.to_s.strip.downcase
      host = URI.parse(text.include?("://") ? text : "https://#{text}").host.to_s
      host.delete_prefix("www.").presence || text
    rescue URI::InvalidURIError
      text
    end

    # page: the landing page to read (the account's address), when it's on this domain; else its home page.
    def initialize(domain, page: nil)
      @domain = self.class.normalize(domain)
      @page = page if page.present? && self.class.normalize(page) == @domain
      @files = {}
    end

    def facts
      @facts ||= {
        "domain" => domain,
        "dns" => part { dns },
        "addresses" => part { addresses },
        "landing_page" => part { landing_page },
        "tag_manager" => part { tag_manager }
      }
    end

    private
      def part
        yield
      rescue => error
        { "error" => "#{error.class.name.demodulize}: #{error.message}".truncate(200) }
      end

      # DNS: who verified the domain ----------------------------------------------------------------
      def dns
        Resolv::DNS.open do |resolver|
          resolver.timeouts = 4
          txt = resolver.getresources(domain, Resolv::DNS::Resource::IN::TXT).map { it.strings.join }
          {
            "google_site_verification" => txt.grep(/\Agoogle-site-verification=/i),
            "facebook_domain_verification" => txt.grep(/\Afacebook-domain-verification=/i),
            "other_verifications" => txt.grep(/verification|verify/i).grep_v(/\A(google-site|facebook-domain)-verification=/i).map { it.truncate(120) }
          }
        end
      end

      # How https://, http:// and www answer, and where they end up ------------------------------
      def addresses
        %W[https://#{domain}/ https://www.#{domain}/ http://#{domain}/].to_h do |url|
          response = follow(url)
          [ url, { "status" => response[:status], "ends_at" => response[:url], "redirects" => response[:hops], "error" => response[:error] }.compact ]
        end
      end

      # The landing page and its tags ------------------------------------------------------------
      def landing_page = @landing_page ||= read_landing_page

      def read_landing_page
        response = follow(@page || "https://#{domain}/")
        raise response[:error] || "answered #{response[:status]}" unless response[:status] == 200

        html = response[:body].to_s
        {
          "url" => response[:url],
          "title" => html[%r{<title[^>]*>(.*?)</title>}mi, 1]&.strip&.gsub(/\s+/, " ")&.truncate(150),
          "platform_hints" => platform_hints(html),
          **tags(html),
          "facebook_domain_verification" => meta(html, "facebook-domain-verification"),
          "google_site_verification" => meta(html, "google-site-verification"),
          "consent_tools" => CONSENT_TOOLS.select { |_, marker| html.include?(marker) }.keys,
          "consent_mode" => html.match?(/gtag\(\s*['"]consent['"]/),
          "privacy_policy_links" => html.scan(/<a\b[^>]*href=["']([^"']*privacy[^"']*)["']/i).flatten.uniq.first(3),
          "phone_links" => html.scan(/href=["']tel:([^"']+)["']/i).flatten.map(&:strip).uniq.first(5),
          "forms" => html.scan(/<form\b[^>]*>/i).size,
          "form_posts_to" => html.scan(/<form\b[^>]*action=["']([^"']+)["']/i).flatten.map { URI.join(response[:url], it).host rescue it }.uniq.first(5),
          "gclid_field" => html.match?(/name=["'][^"']*gclid/i)
        }.compact
      end

      # The ad tags in a page or a Tag Manager container.
      def tags(text)
        {
          "google_ads_ids" => text.scan(/\b(AW-\d{6,12})\b/).flatten.uniq,
          "google_ads_conversions" => text.scan(%r{\b(AW-\d{6,12}/[A-Za-z0-9_-]{6,})}).flatten.uniq.first(10),
          "analytics_ids" => text.scan(/\b(G-[A-Z0-9]{6,12})\b/).flatten.uniq,
          "tag_manager_ids" => text.scan(/\b(GTM-[A-Z0-9]{4,10})\b/).flatten.uniq,
          "enhanced_conversions" => text.match?(/allow_enhanced_conversions|user_data|enhanced_conversion/),
          "meta_pixel_ids" => (text.scan(/fbq\(\s*\\?['"]init\\?['"]\s*,\s*\\?['"](\d{10,20})/) + text.scan(%r{facebook\.com/tr\?id=(\d{10,20})})).flatten.uniq,
          "meta_events" => text.scan(/fbq\(\s*\\?['"]track\\?['"]\s*,\s*\\?['"](\w+)/).flatten.uniq
        }
      end

      # Tag Manager containers are public: what the first one on the page loads.
      def tag_manager
        id = Array((landing_page rescue {})["tag_manager_ids"]).first or raise "no Tag Manager container on the page"
        response = follow("https://www.googletagmanager.com/gtm.js?id=#{id}")
        raise response[:error] || "answered #{response[:status]}" unless response[:status] == 200

        body = response[:body].to_s
        found = tags(body).reject { |key, _| key == "tag_manager_ids" }
        found["google_ads_conversions"] = (found["google_ads_conversions"] + container_conversions(body)).uniq.first(10)
        { "container" => id, **found }
      end

      # A container's Google Ads conversion tags (__awct) keep their ID and label as separate fields.
      def container_conversions(body)
        body.split(/"function":"__/).filter_map do |tag|
          next unless tag.start_with?("awct")

          conversion = tag[/"vtp_conversionId":"(\d+)"/, 1] or next
          label = tag[/"vtp_conversionLabel":"([^"]+)"/, 1]
          [ "AW-#{conversion}", label ].compact.join("/")
        end
      end

      def meta(html, name)
        html[/<meta[^>]+name=["']#{Regexp.escape(name)}["'][^>]*content=["']([^"']*)["']/i, 1] ||
          html[/<meta[^>]+content=["']([^"']*)["'][^>]*name=["']#{Regexp.escape(name)}["']/i, 1]
      end

      def platform_hints(html)
        hints = []
        hints << "WordPress" if html.include?("wp-content")
        hints << "Shopify" if html.include?("cdn.shopify.com")
        hints << "Wix" if html.include?("wixstatic.com")
        hints << "Squarespace" if html.include?("squarespace")
        hints << "Webflow" if html.include?("webflow")
        hints
      end

      # HTTP -------------------------------------------------------------------------------------
      def follow(url, accept: "*/*")
        hops = []
        MAX_REDIRECTS.times do
          response = fetch(url, accept: accept)
          return response.merge(url: url, hops: hops) unless response[:status].to_i.between?(300, 399) && response[:location]

          hops << "#{response[:status]} → #{response[:location]}"
          url = URI.join(url, response[:location]).to_s
        end
        { status: nil, url: url, hops: hops, error: "too many redirects" }
      rescue Refused, StandardError => error
        { status: nil, url: url, hops: hops, error: "#{error.class.name.demodulize}: #{error.message}".truncate(160) }
      end

      def fetch(url, accept: "*/*")
        uri = URI.parse(url)
        raise Refused, "only http and https" unless uri.is_a?(URI::HTTP)
        refuse_private!(uri.host)

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT, ssl_timeout: TIMEOUT) do |http|
          request = Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => accept)
          http.request(request) do |response|
            body = +""
            response.read_body { |chunk| body << chunk if body.bytesize < MAX_BODY }
            return { status: response.code.to_i, location: response["location"], body: body.byteslice(0, MAX_BODY).force_encoding(Encoding::UTF_8).scrub,
                     headers: response.each_header.to_h }
          end
        end
      end

      def refuse_private!(host)
        addresses = Resolv.getaddresses(host)
        raise Refused, "#{host} doesn't resolve" if addresses.empty?
        if addresses.any? { |address| ip = IPAddr.new(address); ip.private? || ip.loopback? || ip.link_local? || address.start_with?("0.") }
          raise Refused, "#{host} is a private address"
        end
      end
  end
end
