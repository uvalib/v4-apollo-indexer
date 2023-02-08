import json

with open("wsls/wsls_orig.json", "r") as read_file:
   obj=json.load(read_file)
   pretty_json = json.dumps(obj, indent=4)
   print(pretty_json)
