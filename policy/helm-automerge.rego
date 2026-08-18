package main

import rego.v1

deny contains msg if {
  not is_replace_mozcloud_chart_version
  msg := sprintf("'%s' is not safe to automerge", [input])
}

# Allow any change to the MozCloud chart version label, wherever it sits in a resource.
#
# The label is written at the top level of every resource and again into pod templates, so a
# chart version bump on a workload produces at least two operations:
#
#   /metadata/labels/mozcloud_chart_version
#   /spec/template/metadata/labels/mozcloud_chart_version
#
# Matching only the top-level path meant any chart with a workload emitted operations this
# policy rejected, so those bumps never qualified for automerge and were merged by hand.
# Matching on the suffix also covers deeper nesting, such as a CronJob's pod template at
# /spec/jobTemplate/spec/template/metadata/labels/mozcloud_chart_version.
#
# The suffix is specific enough to stay safe: it only ever matches a label under a metadata
# block. A selector carrying the same key, for example
# /spec/selector/matchLabels/mozcloud_chart_version, does not match and is still denied.
is_replace_mozcloud_chart_version if {
  input.op == "replace"
  endswith(input.path, "/metadata/labels/mozcloud_chart_version")
}
