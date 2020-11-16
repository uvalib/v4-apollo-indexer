require 'json'
require 'net/http'
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

#$ancestorPIDs = []
def visit(node, parent=nil)
  pid = getField(node, "externalPID")
  if (!pid.empty?) 
    if (node['type']['name'] == 'collection')
      puts "#{node['type']['name']}: #{pid}"
      createXmlDoc(node, parent, pid)
    elsif (node['type']['name'] == 'issue')
      puts "#{node['type']['name']}: #{pid}"
      createLinkDigitalContentMetadata(node, parent, pid) 
    else
      puts "Skipping #{node['type']['name']} node."
    end
  else
    puts "Skipping #{node['type']['name']} node. (no pid)"
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
    pf "  <field name=\"individual_call_number_a\">#{node['value'].encode(:xml => :text)}</field>  "
  when "description"
    pf "   <field name=\"description\">#{node['value']}</field>  "
  else
    pf "<!-- skipped #{node['type']['name']}: #{node['value']} -->"
  end
end

def getManifest(pid)
  cacheFilename = "omw/cache/#{pid}-iiif-manifest.txt"
  if (File.exist? cacheFilename)
     File.read(cacheFilename)
  else
    url = "https://iiifman.lib.virginia.edu/pid/#{pid}"
    uri = URI.parse(url)
    response = Net::HTTP.get_response uri
    text = response.body if response.code == "200"
    File.write(cacheFilename, text || '')
    text || ''    
  end    
end


def createLinkDigitalContentMetadata(node, parent, pid)
  partPid = getField(node, 'externalPID')
  partLabel = getField(node, 'title').encode(:xml => :text)
  sequences = JSON.parse(getManifest(partPid)).values_at("sequences")
  canvases = sequences[0][0]["canvases"]
  thumbnail = canvases[0]["thumbnail"]

  part = {}
  part['iiif_manifest_url'] = "https://s3.us-east-1.amazonaws.com/iiif-manifest-cache-production/pid-#{partPid.sub(':', '-')}"
  part['oembed_url'] = "https://curio.lib.virginia.edu/oembed?url=https://curio.lib.virginia.edu/view/#{partPid}"
  part['label'] = partLabel
  part['pdf'] = { 'urls' => { 'delete' => "https://pdfservice.lib.virginia.edu/pdf/#{partPid}/delete", 'download' => "https://pdfservice.lib.virginia.edu/pdf/#{partPid}/download", 'generate' => "https://pdfservice.lib.virginia.edu/pdf/#{partPid}/generate", 'status' => "https://pdfservice.lib.virginia.edu/pdf/#{partPid}/status"}}
  part['pid'] = partPid
  part['thumbnail_url'] = thumbnail
  $metadata['parts'].push(part);
end

def createXmlDoc(node, parent, pid)
  $metadata['id'] = pid;
  pf '  <field name="pool_f_stored">serials</field>'
  pf "  <field name=\"title_tsearch_stored\">#{getField(node, "title")}</field>  "
  pf "  <field name=\"full_serials_title_f\">#{getField(node, "title")}</field>  "
  pf "  <field name=\"full_title_f\">#{getField(node, "title")}</field>  "
  pf "  <field name=\"full_journal_title_f\">#{getField(node, "title")}</field>  "
  pf "  <field name=\"work_title_tsearch_stored\">#{getField(node, "title")}</field>  "
  pf '  <field name="work_title3_key_ssort_stored">our_mountain_work</field>'
  pf '  <field name="work_title2_key_ssort_stored">our_mountain_work</field>'
  pf "  <field name=\"id\">#{pid}</field>"
  if (pid == 'uva-lib:2528441')
    pf '  <field name="title_later_tsearch_stored">Our Mountain Work in the Diocese of Virginia</field>'
    pf '  <field name="thumbnail_url_a">https://iiif.lib.virginia.edu/iiif/uva-lib:2451601/full/!200,200/0/default.jpg</field>'
    pf '  <field name="published_daterange">[1909 TO 1911]</field>'
    pf '  <field name="published_location_tsearch_stored">Elkton,Va</field>'
    pf '  <field name="published_display_tsearch_stored">1909 - 1911</field>'
    pf '  <field name="published_date">1909-01-01T00:00:00Z</field>'
  else 
    pf '  <field name="title_previous_tsearch_stored">Our Mountain Work</field>'
    pf '  <field name="thumbnail_url_a">https://iiif.lib.virginia.edu/iiif/uva-lib:2253170/full/!200,200/0/default.jpg</field>'
    pf '  <field name="published_daterange">[1911 TO 1935]</field>'
    pf '  <field name="published_location_tsearch_stored">Elkton,Va</field>'
    pf '  <field name="published_display_tsearch_stored">1911 - 1935</field>'
    pf '  <field name="published_date">1911-01-01T00:00:00Z</field>'
  end
  pf "  <field name=\"digital_content_service_url_e_stored\">https://digital-content-metadata-cache-production.s3.amazonaws.com/#{pid}</field>"
  pf "  <field name=\"identifier_e_stored\">#{getField(node, "externalPID")}</field>"
  pf '  <field name="library_f_stored">Special Collections</field>'
  pf '  <field name="shadowed_location_f_stored">VISIBLE</field>'
  pf '  <field name="feature_f_stored">iiif</field>'
  pf '  <field name="feature_f_stored">rights_wrapper</field>'
  pf '  <field name="feature_f_stored">pdf_service</field>'
  pf "  <field name=\"abstract_tsearch_stored\">#{getField(node, "description")}</field>  "
  pf '  <field name="rs_uri_a">http://rightsstatements.org/vocab/CNE/1.0/</field>'
  pf "  <field name=\"barcode_tsearch_stored\">#{getField(node, "barcode")}</field>  "
  pf "  <field name=\"catalogKey\">#{getField(node, "catalogKey")}</field>  "
  pf "  <field name=\"call_number_tsearch_stored\">#{getField(node, "callNumber")}</field>  "
  pf '  <field name="subject_f">Episcopal Church -- Missions -- Virginia</field>'
  pf '  <field name="subject_f">Missions -- Virginia</field>'
  pf '  <field name="subject_f">Rural missions -- Virginia</field>'
end



#conf.echo = false
FileUtils.mkdir_p 'omw/cache'
jsonFile1 = 'omw/uva-an1.json'
jsonFile2 = 'omw/uva-an118.json'

# get the files from apollo
File.write(jsonFile1, Net::HTTP.get_response(URI.parse('https://apollo.lib.virginia.edu/api/collections/uva-an1')).body || '')
File.write(jsonFile2, Net::HTTP.get_response(URI.parse('https://apollo.lib.virginia.edu/api/collections/uva-an118')).body || '')

json_text1 = File.read(jsonFile1)
json_text2 = File.read(jsonFile2)
hash1 = JSON.parse(json_text1);
hash2 = JSON.parse(json_text2);

$file = File.open("omw/our-mountain-work.xml", "w")
begin
    pf '<add>'
    $metadata = {};
    $metadata['parts'] = []
    pf '  <doc>'
    visit hash1
    pf '  </doc>'
    File.open("omw/uva-lib:2528441", "w").write($metadata.to_json)
    $metadata = {};
    $metadata['parts'] = []
    pf '  <doc>'
    visit hash2
    pf '  </doc>'
    File.open("omw/uva-lib:2253857", "w").write($metadata.to_json)
    pf '</add>'
rescue IOError => e
  puts "Error! #{e}"
ensure
  $file.close unless $file.nil?
end
