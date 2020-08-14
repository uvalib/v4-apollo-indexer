require 'json'
require 'net/http'


def pf(string)
  File.write("our-mountain-work.xml", "#{string}\n", mode: "a")
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
  #listMetadata node
  if (node['type']['name'] == 'collection' || node['type']['name'] == 'issue') && !getField(node, 'externalPID').empty?
    puts "#{node['type']['name']}: #{getField(node, "externalPID")}"
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
    pf "  <field name=\"individual_call_number_a\">#{node['value'].encode(:xml => :text)}</field>  "
  when "externalPID"
    pf pidFields(node)
  when "description"
    pf "   <field name=\"description\">#{node['value']}</field>  "
  else
    pf "<!-- skipped #{node['type']['name']}: #{node['value']} -->"
  end
end

def pidFields(node)
  response = Net::HTTP.get_response URI.parse("https://iiifman.lib.virginia.edu/pid/#{node['value']}")
  sequences=JSON.parse(response.body).values_at("sequences")
  canvases=sequences[0][0]["canvases"]
  thumbnail=canvases[0]["thumbnail"]
  "  <field name=\"alternate_id_f_stored\">#{node['value']}</field>\n <field name=\"identifier_e_stored\">#{node['value']}</field>\n <field name=\"rights_wrapper_url_a\">http://rightswrapper2.lib.virginia.edu:8090/rights-wrapper/?pid=#{node['value']}&amp;pagePid=</field>\n <field name=\"thumbnail_url_a\">#{thumbnail}</field>\n"
end

def createXmlDoc(node, parent)
  if node['type']['name'] == 'collection'
    pf '  <field name="pool_f_stored">serials</field>'
    pf "  <field name=\"title_tsearch_stored\">#{getField(node, "title")}</field>  "
    pf "  <field name=\"full_serials_title_f\">#{getField(node, "title")}</field>  "
    pf "  <field name=\"full_title_f\">#{getField(node, "title")}</field>  "
    pf "  <field name=\"full_journal_title_f\">#{getField(node, "title")}</field>  "
    pf "  <field name=\"work_title_tsearch_stored\">#{getField(node, "title")}</field>  "
    pf '  <field name="title_later_tsearch_stored">Our Mountain Work in the Diocese of Virginia</field>'
    pf '  <field name="work_title3_key_ssort_stored">our_mountain_work</field>'
    pf '  <field name="work_title2_key_ssort_stored">our_mountain_work</field>'
    pf "  <field name=\"id\">#{getField(node, "externalPID")}</field>"
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
    pf '  <field name="published_daterange">[1909 TO 1911]</field>'
    pf '  <field name="published_tsearch_stored">Elkton,Va</field>'
    pf '  <field name="published_location_tsearch_stored">Elkton,Va</field>'
    pf '  <field name="published_display_tsearch_stored">1909 - 1911</field>'
    pf '  <field name="published_date">1909-01-01T00:00:00Z</field>'
    pf '  <field name="subject_f">Episcopal Church -- Missions -- Virginia</field>'
    pf '  <field name="subject_f">Missions -- Virginia</field>'
    pf '  <field name="subject_f">Rural missions -- Virginia</field>'


  elsif node['type']['name'] == 'issue'
    pf '  <field name="pdf_url_a">https://pdfservice.lib.virginia.edu/pdf</field>'
    node["children"].each do |child|
      printSolrField child, node
    end
  end
end


#conf.echo = false
json_text = File.read("our-mountain-work.json")
hash = JSON.parse(json_text);
pf '<add>'
pf '<doc>'
visit hash
pf '</doc>'
pf '</add>'
