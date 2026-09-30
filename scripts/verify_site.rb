# frozen_string_literal: true

# Validate the actual Pages artifact, including privacy and bilingual navigation.
# Uses only Ruby's standard library so the CI and local checks are identical.
require "yaml"
require "cgi"
require "uri"
require "pathname"

ROOT = Pathname.new(__dir__).parent
SITE = ROOT.join("_site")
PROFILE = YAML.safe_load_file(ROOT.join("_data/profile.yml"))
CONFIG = YAML.safe_load_file(ROOT.join("_config.yml"))
EXPECTED_AWARDS = %w[ecfinal ccpc-zhengzhou icpc-xian northeast].freeze

def verify(condition, message)
  abort "FAIL: #{message}" unless condition
end

def readable(html)
  CGI.unescapeHTML(html.gsub(/<[^>]*>/, " ")).gsub(/\s+/, " ").strip
end

def verify_text(html, text, context)
  # Markdown may render straight quotation marks as typographic quotation marks.
  actual = readable(html).tr("‘’“”", %q{''""})
  expected = text.gsub(/\s+/, " ").tr("‘’“”", %q{''""})
  verify(actual.include?(expected), "Missing #{context}")
end

verify(SITE.directory?, "Run the Jekyll production build first")
verify(PROFILE.fetch("awards").map { |item| item.fetch("id") } == EXPECTED_AWARDS,
       "Awards must retain the owner's explicitly approved order")

%w[cv pre].each do |folder|
  verify(!ROOT.join(folder).exist? && !SITE.join(folder).exist?, "Original #{folder} directory must be removed")
end
verify(!SITE.join("README.md").exist?, "Project README must not be published")

{ "en" => ["index.html", "en", "/"], "zh" => ["zh/index.html", "zh-CN", "/zh/"] }.each do |lang, (file, html_lang, route)|
  path = SITE.join(file)
  verify(path.file?, "Missing #{route}")
  html = path.read
  verify(html.include?(%(<html lang="#{html_lang}">)), "Incorrect document language for #{route}")
  verify(html.scan(/<h1\b/).length == 1, "Exactly one page heading is required for #{route}")
  verify(!html.match?(/\{[{%]/), "Unrendered Liquid in #{route}")
  verify(html.include?(%(<link rel="canonical" href="#{CONFIG.fetch('url')}#{route}">)), "Incorrect canonical for #{route}")
  { "en" => "/", "zh-CN" => "/zh/", "x-default" => "/" }.each do |locale, url|
    verify(html.include?(%(<link rel="alternate" hreflang="#{locale}" href="#{CONFIG.fetch('url')}#{url}">)), "Missing #{locale} alternate for #{route}")
  end

  verify_text(html, PROFILE.fetch("summary").fetch(lang), "#{lang} introduction")
  PROFILE.fetch("education").each do |entry|
    %w[institution school qualification date].each do |key|
      verify_text(html, entry.fetch(key).fetch(lang), "#{lang} education #{key}")
    end
  end
  verify(html.scan(/data-award="([^"]+)"/).flatten == EXPECTED_AWARDS, "Incorrect rendered award order for #{route}")
  PROFILE.fetch("awards").each do |award|
    %w[name result].each { |key| verify_text(html, award.fetch(key).fetch(lang), "#{lang} award #{key}") }
    verify_text(html, award.fetch("detail").fetch(lang), "#{lang} World Finals qualification") if award["detail"]
  end
  %w[internship leadership].each do |section|
    PROFILE.fetch(section).each_value { |value| verify_text(html, value.fetch(lang), "#{lang} #{section}") }
  end
  %w[about education honors experience].each do |id|
    verify(html.include?(%(id="#{id}")), "Missing #{id} section for #{route}")
  end
  ["mailto:#{PROFILE.fetch('email')}", PROFILE.fetch("github"), PROFILE.fetch("codeforces")].each do |href|
    verify(html.include?(%(href="#{href}")), "Missing confirmed contact link for #{route}")
  end
  verify(!html.match?(/tel:|@(?:163|qq)\.com|GPA|CET-6|LangGraph|HotpotQA|Qwen3|国家奖学金|校一等奖学金/), "Excluded content found in #{route}")
  verify(!html.match?(/id="(?:research|projects|publications|blog|cv)"/), "Unapproved section in #{route}")
end

# Check every internal resource and anchor in all generated HTML, including 404.
SITE.glob("**/*.html").each do |page|
  html = page.read
  html.scan(/\b(?:href|src)="([^"]+)"/).flatten.each do |raw|
    href = CGI.unescapeHTML(raw)
    uri = URI.parse(href)
    next if uri.scheme && !(uri.scheme == "https" && uri.host == URI(CONFIG.fetch("url")).host)
    next if uri.host && uri.host != URI(CONFIG.fetch("url")).host

    target = if uri.path.nil? || uri.path.empty?
               page
             elsif uri.path.start_with?("/")
               SITE.join(uri.path.delete_prefix("/"))
             else
               page.parent.join(uri.path)
             end
    target = target.join("index.html") if target.directory?
    verify(target.file?, "Broken internal link #{href} in #{page.relative_path_from(SITE)}")
    if uri.fragment && target.extname == ".html"
      verify(target.read.include?(%(id="#{uri.fragment}")), "Missing anchor #{href}")
    end
  end
end

%w[robots.txt sitemap.xml assets/css/main.css images/portrait.jpg].each do |file|
  verify(SITE.join(file).file?, "Missing deployment asset #{file}")
end
sitemap = SITE.join("sitemap.xml").read
verify(sitemap.include?("#{CONFIG.fetch('url')}/zh/"), "Chinese page missing from sitemap")
puts "PASS: bilingual content, approved award order, privacy, metadata, local links, anchors, and deployment assets"
