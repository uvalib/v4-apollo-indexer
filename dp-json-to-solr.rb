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

$ancestorPIDs = []
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
      date=DateTime.parse(node["value"].gsub(/Daily Progress, /,'')).strftime('%Y-%m-%d')
      pf "  <field name=\"title_tsearch_stored\">#{node['value'].encode(:xml => :text)}</field>\n  <field name=\"full_title_tsearchf_stored\">#{node['value'].encode(:xml => :text)}</field>\n  <field name=\"individual_call_number_a\">#{node['value'].encode(:xml => :text)}</field>\n  <field name=\"published_daterange\">#{date}</field>\n  <field name=\"published_display_a\">#{date}</field>\n  <field name=\"published_date\">#{date}T00:00:00Z</field>"
    rescue
      pf "  <field name=\"title_tsearch_stored\">#{node['value'].encode(:xml => :text)}</field>\n  <field name=\"full_title_tsearchf_stored\">#{node['value'].encode(:xml => :text)}</field>\n  <field name=\"individual_call_number_a\">#{node['value'].encode(:xml => :text)}</field>"
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
    sequences=JSON.parse(getManifest(node)).values_at("sequences")
    canvases=sequences[0][0]["canvases"]
    thumbnail=canvases[0]["thumbnail"]
    "  <field name=\"id\">#{node['value']}</field>\n <field name=\"alternate_id_f_stored\">#{node['value']}</field>\n <field name=\"url_oembed_stored\">https://curio.lib.virginia.edu/oembed?url=https://curio.lib.virginia.edu/view/#{node['value']}</field>\n <field name=\"rights_wrapper_url_a\">http://rightswrapper2.lib.virginia.edu:8090/rights-wrapper/?pid=#{node['value']}&amp;pagePid=</field>\n <field name=\"work_title3_key_ssort_stored\">unique_#{node['value']}</field>\n <field name=\"work_title2_key_ssort_stored\">unique_#{node['value']}</field>\n <field name=\"thumbnail_url_a\">#{thumbnail}</field>\n"
end

def reelFields(node)
  "  <field name=\"reel_tsearch_stored\">#{node['value']}</field>\n"
end

def createXmlDoc(node, parent)
  pf "<doc>"
  #pf '  <field name="pool_f_stored"> daily_progress</field>'
  pf '  <field name="collection_note_tsearch_stored">The Daily Progress is the Charlottesville, VA, area newspaper, published daily from 1892 to the present. Issues from 1892 through 1964 have been digitized from the Library\'s set of microfilm and are available for viewing online.</field>'
  pf '  <field name="pool_f_stored">serials</field>'
  pf '  <field name="uva_availability_f_stored">Online</field>'
  pf '  <field name="anon_availability_f_stored">Online</field>'
  pf '  <field name="format_f">Online</field>'
  pf '  <field name="circulating_f">true</field>'
  pf '  <field name="call_number_tsearch_stored" />'
  pf '  <field name="data_source_f_stored">daily progress</field>'
  pf '  <field name="digital_collection_f_stored">Daily Progress Digitized Microfilm</field>'
  pf '  <field name="shadowed_location_f_stored">VISIBLE</field>'
  pf "  <field name=\"identifier_e_stored\"> #{$ancestorPIDs[0]}</field>"
  pf "  <field name=\"identifier_e_stored\"> #{$ancestorPIDs[1]}</field>"
  pf "  <field name=\"identifier_e_stored\"> #{$ancestorPIDs[2]}</field>"
  pf '  <field name="dailyprogress_tsearch">daily progress digitized microfilm digital scan newspaper charlottesville</field>'
  pf '  <field name="pdf_url_a">https://pdfservice.lib.virginia.edu/pdf</field>'
  pf '  <field name="feature_f_stored">iiif</field>'
  pf '  <field name="feature_f_stored">rights_wrapper</field>'
  pf '  <field name="feature_f_stored">pdf_service</field>'
  node["children"].each do |child|
    printSolrField child, node
  end
  pf "</doc>"
end


#conf.echo = false
FileUtils.mkdir_p 'dp/cache'
jsonFile = 'dp/uva-an1054'

# get the file from apollo
File.write(jsonFile, Net::HTTP.get_response(URI.parse('https://apollo.lib.virginia.edu/api/collections/uva-an1054')).body || '')

json_text = File.read(jsonFile)
hash = JSON.parse(json_text);
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


