require 'json'
require 'net/http'

def pf(string)
    File.write("daily-progress.xml", "#{string}\n", mode: "a")
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

def dateFields(node)
  "   <field name=\"published_date\">#{node['value']}</field>"
end

def printSolrField(node, parent)
  #puts node["type"]["name"]
  case node["type"]["name"]
  when "title"
    pf "  <field name=\"title_tsearch_stored\">#{node['value'].encode(:xml => :text)}</field>\n  <field name=\"full_title_tsearchf_stored\">#{node['value'].encode(:xml => :text)}</field>"
  when "externalPID"
    pf pidFields(node)
  when "reel"
    pf reelFields(node)
  else
    pf "<!-- skipped #{node['type']['name']}: #{node['value']} -->"
  end
end

def pidFields(node)
    "<field name=\"id\">#{node['value']}</field>\n  <field name=\"url_oembed_stored\">https://curio.lib.virginia.edu/oembed?url=https://curio.lib.virginia.edu/view/#{node['value']}</field>"
end

def reelFields(node)
  "<field name=\"reel\">#{node['value']}</field>\n"
end

def createXmlDoc(node, parent)
  #printout(node)
  pf "<doc>"
  pf '  <field name="pool_f_stored"> daily_progress</field>'
  pf '  <field name="uva_availability_f_stored">Online</field>'
  pf '  <field name="anon_availability_f_stored">Online</field>'
  pf '  <field name="format_f">Online</field>'
  pf '  <field name="circulating_f">true</field>'
  pf '  <field name="call_number_tsearch_stored"></field>'
  pf '  <field name="data_source_f_stored">daily progress</field>'
  pf '  <field name="digital_collection_f_stored">Daily Progress Digitized Microfilm</field>'
  pf '  <field name="shadowed_location_f_stored">VISIBLE</field>'
  pf '  <field name="library_f_stored">Special Collections</field>'
  pf '  <field name="terms_of_use_a">Each user of the Daily Progress materials must individually evaluate any copyright or privacy issues that might pertain to the intended uses of these materials, including fair use. &lt;a href="https://copyright.library.virginia.edu/wsls_use/"&gt;Read More.&lt;/a&gt;</field>'
  pf "  <field name=\"identifier_e_stored\"> #{$ancestorPIDs[0]}</field>"
  pf "  <field name=\"identifier_e_stored\"> #{$ancestorPIDs[1]}</field>"
  pf "  <field name=\"identifier_e_stored\"> #{$ancestorPIDs[2]}</field>"
  node["children"].each do |child|
    printSolrField child, node
  end
  pf "</doc>"
end


#conf.echo = false
json_text = File.read("daily-progress-sample.json")
hash = JSON.parse(json_text);
pf '<add>'
visit hash
pf '</add>'


