module SourcesHelper
  # "jw.org" for www.jw.org, as each page an answer used shows beside its title. Every source passed Ai::SourceLink,
  # so it parses.
  def source_host(url)
    URI(url).host.delete_prefix("www.")
  end
end
