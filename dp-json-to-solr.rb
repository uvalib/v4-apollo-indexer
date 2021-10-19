require 'json'
require 'net/http'
require 'date'
require 'fileutils'

def pf(string)
    $file.write("#{string}\n")
end

def getField(node, name) 
    value = ""
    #puts "DEBUG getField #{node}, #{name}"
    node["children"].each do | child |
       if (child['type']['name'] == name)
         #puts "DEBUG #{name}: #{child}"
         value = child['value']
         #puts child['value']
         break
       end
    end
    value
end

def printout(node) 
  puts "#{node["type"]["name"]}: #{node["value"]}\n"
end

def isContainer(node) 
   node["type"]["container"]
end

$count = 0
def visitToCount(node, parent=nil)
    if node['type']['name'] == 'issue' && !parent.nil? && !getField(node, 'externalPID').empty?
        $count = $count + 1
    end
    node["children"].each do |child|
       if (isContainer(child))
           visitToCount(child, node)
       end
    end
end

$ancestorPIDs = []
$current = 0;
def visit(node, parent=nil)
    #listMetadata node
    if node['type']['name'] == 'collection' && !getField(node, 'externalPID').empty?
        $ancestorPIDs[0]=getField(node, "externalPID")
    elsif node['type']['name'] == 'year' && !getField(node, 'externalPID').empty?
        $ancestorPIDs[1]=getField(node, "externalPID")
    elsif node['type']['name'] == 'month' && !getField(node, 'externalPID').empty?
        $ancestorPIDs[2]=getField(node, "externalPID")
    elsif node['type']['name'] == 'issue' && !parent.nil? && !getField(node, 'externalPID').empty?
        puts "Writing out #{node['type']['name']}: #{getField(node, "externalPID")}"
        createXmlDoc(node, parent)
    else
        puts "Skipping #{node['type']['name']} node."
    end
    node["children"].each do |child|
       if (isContainer(child))
           visit(child, node)
       end
    end
end

def listMetadata(node)
    node["children"].each do |child|
       printout child unless isContainer(child)
    end
end

def printSolrField(node, parent)
  #puts node["type"]["name"]
  case node["type"]["name"]
  when "title"
    begin
      date=DateTime.parse(node["value"].gsub(/Daily Progress, /,''))
      title = "Daily Progress, #{date.strftime('%A %B %-d, %Y')}"
      pf "  <field name=\"title_tsearch_stored\">#{title.encode(:xml => :text)}</field>\n  <field name=\"full_title_tsearchf_stored\">#{title.encode(:xml => :text)}</field>\n  <field name=\"published_daterange\">#{date.strftime('%Y-%m-%d')}</field>\n  <field name=\"published_display_a\">#{date.strftime('%Y-%m-%d')}</field>\n  <field name=\"published_date\">#{date.strftime('%Y-%m-%d')}T00:00:00Z</field>"
    rescue
      pf "  <field name=\"title_tsearch_stored\">#{node['value'].encode(:xml => :text)}</field>\n  <field name=\"full_title_tsearchf_stored\">#{node['value'].encode(:xml => :text)}</field>"
    end
  when "externalPID"
    pf pidFields(node)
  when "reel"
    pf reelFields(node)
  else
    pf "<!-- skipped #{node['type']['name']}: #{node['value']} -->"
  end
end

def getManifest(node)
  cacheFilename = "dp/cache/#{node['value']}-iiif-manifest.txt"
  if (File.exist? cacheFilename)
     File.read(cacheFilename)
  else
    url = "https://iiifman.lib.virginia.edu/pid/#{node['value']}"
    uri = URI.parse(url)
    response = Net::HTTP.get_response uri
    text = response.body if response.code == "200"
    File.write(cacheFilename, text || '')
    text || ''    
  end    
end

def pidFields(node)
  pid = node['value']
  manifest = JSON.parse(getManifest(node))
  sequences = manifest.values_at("sequences")
  canvases=sequences[0][0]["canvases"]
  thumbnail=canvases[0]["thumbnail"]
  partLabel=manifest["label"].sub('Daily Progress Digitized Microfilm: Daily Progress, ', '')
    
  part = {}
  part['iiif_manifest_url'] = "https://s3.us-east-1.amazonaws.com/iiif-manifest-cache-production/pid-#{pid.sub(':', '-')}"
  part['oembed_url'] = "https://curio.lib.virginia.edu/oembed?url=https://curio.lib.virginia.edu/view/#{pid}"
  part['label'] = partLabel
  part['pdf'] = { 'urls' => { 'delete' => "https://pdfservice.lib.virginia.edu/pdf/#{pid}/delete", 'download' => "https://pdfservice.lib.virginia.edu/pdf/#{pid}/download", 'generate' => "https://pdfservice.lib.virginia.edu/pdf/#{pid}", 'status' => "https://pdfservice.lib.virginia.edu/pdf/#{pid}/status"}}
  part['pid'] = pid
  part['thumbnail_url'] = thumbnail
  metadata = {};
  metadata['parts'] = []
  metadata['parts'].push(part);
  File.open("dp/dcs/#{pid}", "w").write(metadata.to_json)
    "<field name=\"id\">#{pid}</field>\n<field name=\"alternate_id_a\">#{pid}</field>\n<field name=\"url_oembed_stored\">https://curio.lib.virginia.edu/oembed?url=https://curio.lib.virginia.edu/view/#{pid}</field>\n  <field name=\"work_title3_key_ssort_stored\">unique_#{pid}</field>\n<field name=\"work_title2_key_ssort_stored\">unique_#{pid}</field>\n<field name=\"digital_content_service_url_e_stored\">https://digital-content-metadata-cache-production.s3.amazonaws.com/#{pid}</field>\n<field name=\"thumbnail_url_a\">#{thumbnail}</field>"

end

def reelFields(node)
  "  <field name=\"reel_tsearch_stored\">#{node['value']}</field>\n"
end

def createXmlDoc(node, parent)
  pf "<doc>"
  #pf '  <field name="pool_f_stored"> daily_progress</field>'
  pf '  <field name="pool_f_stored">serials</field>'
  pf '  <field name="uva_availability_f_stored">Online</field>'
  pf '  <field name="anon_availability_f_stored">Online</field>'
  pf '  <field name="format_f">Online</field>'
  pf '  <field name="circulating_f">true</field>'
  pf '  <field name="call_number_tsearch_stored" />'
  pf '  <field name="digital_collection_f_stored">Daily Progress Digitized Microfilm</field>'
  pf '  <field name="shadowed_location_f_stored">VISIBLE</field>'
  #pf "  <field name=\"identifier_e_stored\">#{$ancestorPIDs[0]}</field>"
  pf "  <field name=\"identifier_e_stored\">#{$ancestorPIDs[1]}</field>"
  pf "  <field name=\"identifier_e_stored\">#{$ancestorPIDs[2]}</field>"
  pf '  <field name="dailyprogress_tsearch">daily progress digitized microfilm digital scan newspaper charlottesville</field>'
  #pf '  <field name="url_supp_str_stored">https://search.lib.virginia.edu/search?mode=advanced&amp;q=keyword%3A%20%7B%2a%7D&amp;exclude=articles,books,images,jmrl,archival,maps,music-recordings,musical-scores,sound-recordings,thesis,video,worldcat&amp;pool=journals&amp;filter=%7B%22FacetCollection%22%3A%5B%22Daily%20Progress%20Digitized%20Microfilm%22%5D%7D&amp;sort=SortDatePublished_asc</field>'
  #pf '  <field name="url_label_supp_str_stored">Browse all Issues</field>'
  pf '  <field name="feature_f_stored">iiif</field>'
  $current = $current + 1
  pf " <field name=\"collection_position_a\">issue #{format_number($current)} of #{format_number($count)}</field>"
  node["children"].each do |child|
    printSolrField child, node
  end
  pf "</doc>"
end

def format_number(number)
  num_groups = number.to_s.chars.to_a.reverse.each_slice(3)
  num_groups.map(&:join).join(',').reverse
end


#conf.echo = false
FileUtils.mkdir_p 'dp/cache'
FileUtils.mkdir_p 'dp/dcs'
jsonFile = 'dp/uva-an1054'

# get the file from apollo
File.write(jsonFile, Net::HTTP.get_response(URI.parse('https://apollo.lib.virginia.edu/api/collections/uva-an1054')).body || '')

json_text = File.read(jsonFile)
hash = JSON.parse(json_text);
visitToCount hash
begin
  $file = File.open("dp/daily-progress-collection-solr.xml", "w")
  pf '<add>'
  visit hash
  pf '</add>'
rescue IOError => e
  puts "Error! #{e}"
ensure
  $file.close unless $file.nil?
end


