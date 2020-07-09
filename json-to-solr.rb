require 'json'
require 'net/http'

def pf(string)
    File.write("wsls-collection-solr.xml", "#{string}\n", mode: "a")
end

def getScriptText(url)
  uri = URI.parse(url)
  response = Net::HTTP.get_response uri
  text = response.body if response.code == "200"
  text || ''
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

def visit(node, parent=nil)
    #listMetadata node
    if (node['type']['name'] == 'item' && !parent.nil? && !getField(node, 'externalPID').empty?)
        puts "Writing out #{getField(node, "wslsID")}"  
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

def wslsTagFields(node)
   '  <field name="video_sound_a">Silent</field>' if (!node['value'].include? 'sound') 
end

def wslsColorField(node)
   '<field name="video_color_a">BW</field>' if (!node['value'].include? 'color') 
end

def runtimeField(node)
   hm = node['value'].split(':')
  case hm.length
  when 3
    if (hm[0].to_i > 0) then
      return "<field name=\"video_run_time_a\">#{hm[0].to_i} hours, #{hm[1].to_i} minutes, #{hm[2].to_i} seconds</field>"
    else
      if (hm[1].to_i > 0) then
        return "<field name=\"video_run_time_a\">#{hm[1].to_i} minutes, #{hm[2].to_i} seconds</field>"
      else
        return "<field name=\"video_run_time_a\">#{hm[2].to_i} seconds</field>"
      end
    end
  when 2
    if (hm[0].to_i > 0) then
      return "<field name=\"video_run_time_a\">#{hm[0].to_i} minutes, #{hm[1].to_i} seconds</field>"
    else
      return "<field name=\"video_run_time_a\">#{hm[1].to_i} seconds</field>"
    end
  when 1
    return "<field name=\"video_run_time_a\">#{hm[0].to_i} seconds</field>"
  end
   # if (hm.length == 2) then
   #   if (hm[0].to_i > 0) then
   #      return "<field name=\"video_run_time_a\">#{hm[0].to_i} minutes, #{hm[1].to_i} seconds</field>"
   #   else
   #      return "<field name=\"video_run_time_a\">#{hm[1].to_i} seconds</field>"
   #   end
   # else
   #      return "<field name=\"video_run_time_a\">#{hm[0].to_i} seconds</field>"
   # end
end

def dateFields(node)
  case node['value'].split('-').count
  when 3
    "  <field name=\"published_daterange\">#{node['value'].gsub("XX", "01")}</field>\n  <field name=\"published_display_a\">#{node['value'].gsub("XX", "01")}</field>\n  <field name=\"published_date\">#{node['value'].gsub("XX", "01")}T00:00:00Z</field>"
  when 2
    "  <field name=\"published_daterange\">#{node['value']+ "-01"}</field>\n  <field name=\"published_display_a\">#{node['value']+ "-01"}</field>\n  <field name=\"published_date\">#{node['value']}-01T00:00:00Z</field>"
  when 1
    "  <field name=\"published_daterange\">#{node['value']+ "-01-01"}</field>\n  <field name=\"published_display_a\">#{node['value']+ "-01-01"}</field>\n  <field name=\"published_date\">#{node['value']}-01-01T00:00:00Z</field>"
  end
end

def videoFields(node, parent)
   #puts "Video Node: #{node}\n parent node: #{parent}"
   if (node['value'] == 'true')  
     id = getField(parent, 'wslsID') 
     "<field name=\"video_download_url_a\">https://wsls.lib.virginia.edu/#{id}/#{id}.webm</field>\n  <field name=\"url_str_stored\">https://wsls.lib.virginia.edu/#{id}/#{id}.webm</field>\n  <field name=\"url_label_str_stored\">Download Video</field>\n  <field name=\"format_f_stored\">Video</field>"
   end
end

def printSolrField(node, parent) 
  case node["type"]["name"]
  when "title"
    pf "  <field name=\"title_tsearch_stored\">#{node['value'].encode(:xml => :text)}</field>\n  <field name=\"full_title_tsearchf_stored\">WSLS_#{node['value'].encode(:xml => :text)}</field>"
  when "wslsTopic"
    pf "<field name=\"subject_tsearchf_stored\">#{node['value'].encode(:xml => :text)}</field>"
  when "duration"
    pf runtimeField(node)
  when "wslsColor"
    pf wslsColorField(node)
  when "wslsTag"
    pf wslsTagFields(node)
  when "abstract"
    pf "  <field name=\"subject_summary_tsearch_stored\">#{node['value'].encode(:xml => :text)}</field>"
  when "externalPID"
    pf pidFields(node)
  when "wslsID" 
    pf "  <field name=\"identifier_e_stored\">#{node['value']}</field>\n  <field name=\"work_title3_key_ssort_stored\">WSLS_#{node['value']}</field>\n  <field name=\"thumbnail_url_a\">https://wsls.lib.virginia.edu/#{node['value']}/#{node['value']}-thumbnail.jpg</field>"
  when "hasVideo"
    pf videoFields(node, parent)
  when "hasScript"
    pf scriptFields(node, parent)
  when "wslsRights"
    pf wslsRightsField(node)
  when "dateCreated"
    pf dateFields(node)
  when "digitalObject"
  when "filmBoxLabel"
  when "wslsPlace"
  else
    pf "<!-- skipped #{node['type']['name']}: #{node['value']} -->"
  end
end

def pidFields(node)
  if $excerpt_hash.select{|h|h['pid']==node['value']}.empty?
    "<field name=\"id\">#{node['value']}</field>\n  <field name=\"url_str_stored\">https://curio.lib.virginia.edu/view/#{node['value']}</field>\n  <field name=\"url_label_str_stored\">View Video</field>\n  <field name=\"url_oembed_stored\">https://curio.lib.virginia.edu/oembed?url=https://curio.lib.virginia.edu/view/#{node['value']}</field>"
  else
    excerpt= $excerpt_hash.select{|h|h['pid']==node['value']}.first['excerpt']
    "<field name=\"id\">#{node['value']}</field>\n  <field name=\"url_str_stored\">https://curio.lib.virginia.edu/view/#{node['value']}</field>\n  <field name=\"url_label_str_stored\">View Video</field>\n  <field name=\"url_oembed_stored\">https://curio.lib.virginia.edu/oembed?url=https://curio.lib.virginia.edu/view/#{node['value']}</field>\n   <field name=\"script_excerpt_tsearch_stored\">#{excerpt}</field>"
  end
end

def scriptFields(node, parent)
  if (node['value'] == 'true')
     id = getField(parent, 'wslsID') 
     scriptText = getScriptText("https://wsls.lib.virginia.edu/#{id}/#{id}.txt")
     "<field name=\"url_script_pdf\">https://wsls.lib.virginia.edu/#{id}/#{id}.pdf</field>
     <field name=\"url_str_stored\">https://wsls.lib.virginia.edu/#{id}/#{id}.pdf</field>
     <field name=\"url_label_str_stored\">Script PDF</field>
     <field name=\"url_script_txt\">https://wsls.lib.virginia.edu/#{id}/#{id}.txt</field>
     <field name=\"url_str_stored\">https://wsls.lib.virginia.edu/#{id}/#{id}.txt</field>
     <field name=\"url_label_str_stored\">Script Text</field>
     <field name=\"anchor_script_tsearch\">#{scriptText.encode(:xml => :text)}}</field>"
  end
end

def wslsRightsField(node)
   if (node['value'].include? "Local")
     "<field name=\"cc_uri_a\">https://creativecommons.org/publicdomain/zero/1.0/</field>\n  <field name=\"rs_uri_a\">http://rightsstatements.org/vocab/NoC-US/1.0/</field>"
   end
end

def createXmlDoc(node, parent)
  pf "<doc>"
  pf '  <field name="pool_f_stored">video</field>'
  pf '  <field name="uva_availability_f_stored">Online</field>'
  pf '  <field name="anon_availability_f_stored">Online</field>'
  pf '  <field name="circulating_f">true</field>'
  pf '  <field name="call_number_tsearch_stored">MSS 15988</field>'
  pf '  <field name="source_f_stored">WSLS-TV News Film Collection, 1951-1971</field>'
  pf '  <field name="source_tsearch">WSLS-TV News Film Collection, 1951-1971</field>'
  pf '  <field name="wsls_tsearch">wsls</field>'
  pf '  <field name="wsls_tsearch">clips</field>'
  pf '  <field name="wsls_tsearch">video</field>'
  pf '  <field name="wsls_tsearch">anchor scripts</field>'
  pf '  <field name="wsls_tsearch">WSLS-TV News Film Collection, 1951-1971</field>'
  pf '  <field name="data_source_f_stored">wsls</field>'
  pf '  <field name="digital_collection_f_stored">WSLS-TV News Film Collection, 1951-1971</field>'
  pf '  <field name="identifier_e_stored">uva-lib:2214294</field>'
  pf '  <field name="shadowed_location_f_stored">VISIBLE</field>'
  pf '  <field name="library_f_stored">Special Collections</field>'
  pf '  <field name="terms_of_use_a">Each user of the WSLS materials must individually evaluate any copyright or privacy issues that might pertain to the intended uses of these materials, including fair use. &lt;a href="https://copyright.library.virginia.edu/wsls_use/"&gt;Read More.&lt;/a&gt;</field>'
  node["children"].each do |child|
    printSolrField child, node
  end
  pf "</doc>"
end


conf.echo = false
json_text = File.read("wsls.json")
hash = JSON.parse(json_text);
excerpt_text = File.read("wsls_excerpts_test.json")
$excerpt_hash = JSON.parse(excerpt_text);
pf '<add>'
visit hash
pf '</add>'

