require 'open-uri'
require 'rubygems'

module MicroXMLParser
  HEADER = %r{<\?xml\s.+\?>\n}
  ATTRIBUTE = %r{(\w+)="([^"]+)"}
  OPEN_TAG = %r{<(\w+)((?:\s+#{ATTRIBUTE})*)>}
  CLOSE_TAG = %r{</(\w+)>}
  TEXT = %r{([^<]*)}

  def self.parse(xml)
    xml = xml.strip
    raise xml unless xml.start_with? HEADER
    xml = xml[$&.size..-1].strip
    value, rest = rec(xml)
    raise rest unless rest.empty?
    value
  end

  def self.rec(xml)
    xml = xml.strip
    if xml.start_with? OPEN_TAG
      entries = []
      while xml.start_with? OPEN_TAG
        tag, attributes = $1, $2
        xml = xml[$&.size..-1].strip

        until attributes.empty?
          attributes = attributes.strip
          raise attributes unless attributes.start_with? ATTRIBUTE
          key, value = $1, $2
          attributes = attributes[$&.size..-1]
          entries << { key.to_sym => value }
        end

        value, xml = rec(xml)
        entries << { tag.to_sym => value }

        close_tag = "</#{tag}>"
        raise "Missing close tag #{close_tag}: #{xml}" unless xml.start_with? close_tag
        xml = xml[close_tag.size..-1].strip
      end

      keys = entries.map { |entry| entry.first.first }
      if keys == keys.uniq
        entries = entries.inject({}, :merge)
      end

      [entries, xml]
    elsif xml.start_with? TEXT
      text = $1
      xml = xml[$&.size..-1]
      [text, xml]
    else
      raise xml
    end
  end
end

base_url = 'https://oss.sonatype.org/content/repositories/snapshots/org/jruby/jruby-dist'
index_url = "#{base_url}/maven-metadata.xml"

STDERR.puts index_url
xml = URI.open(index_url, &:read)
STDERR.puts xml

parsed = MicroXMLParser.parse(xml)
versions = parsed.dig(:metadata, :versioning, :versions).map { |e| e[1] }

versions.delete('9000.dev-SNAPSHOT')
most_recent = versions.max_by { |v| Gem::Version.new(v) }

builds_url = "#{base_url}/#{most_recent}/maven-metadata.xml"
STDERR.puts builds_url
xml = URI.open(builds_url, &:read)
STDERR.puts xml

parsed = MicroXMLParser.parse(xml)
last_build = parsed.dig(:metadata, :versioning, :snapshotVersions).map { |e| e[:snapshotVersion] }.select { |node|
  node[:classifier] == 'bin' and node[:extension] == 'tar.gz'
}.map { |node| node[:value] }.last

final_url = "#{base_url}/#{most_recent}/jruby-dist-#{last_build}-bin.tar.gz"
puts final_url
