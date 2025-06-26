require 'open-uri'
require 'rubygems'
require 'nokogiri'

base_url = 'https://central.sonatype.com/repository/maven-snapshots/org/jruby/jruby-dist'
index_url = "#{base_url}/maven-metadata.xml"

STDERR.puts index_url
xml = URI.open(index_url, &:read)
STDERR.puts xml

versions = Nokogiri::XML(xml).css('version').map(&:text)

versions.delete('9000.dev-SNAPSHOT')
most_recent = versions.max_by { |v| Gem::Version.new(v) }

builds_url = "#{base_url}/#{most_recent}/maven-metadata.xml"
STDERR.puts builds_url
xml = URI.open(builds_url, &:read)
STDERR.puts xml

last_build = Nokogiri::XML(xml).css('snapshotVersion').select { |node|
  classifier = node.at('classifier')
  classifier and classifier.text == 'bin' and node.at('extension').text == 'tar.gz'
}.map { |node| node.at('value').text }.last

final_url = "#{base_url}/#{most_recent}/jruby-dist-#{last_build}-bin.tar.gz"
puts final_url
