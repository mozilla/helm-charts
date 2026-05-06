package main

import rego.v1

deny contains msg if {
  not is_replace_mozcloud_chart_version
  msg := sprintf("'%s' is not safe to automerge", [input])
}

# Allow any change to the Mozcloud chart version
is_replace_mozcloud_chart_version if {
  input.op == "replace"
  input.path == "/metadata/labels/mozcloud_chart_version"
}
