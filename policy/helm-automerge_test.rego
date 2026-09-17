package main

import rego.v1

# The policy is fed one JSON-patch operation at a time: conftest iterates the array that
# `diffnest --format json-patch` produces, so each operation is evaluated as its own document.

# --- allowed: a MozCloud chart version bump, at any depth ---------------------------------

test_allows_top_level_chart_version if {
	count(deny) == 0 with input as {
		"op": "replace",
		"path": "/metadata/labels/mozcloud_chart_version",
		"value": "3.9.2",
	}
}

test_allows_pod_template_chart_version if {
	count(deny) == 0 with input as {
		"op": "replace",
		"path": "/spec/template/metadata/labels/mozcloud_chart_version",
		"value": "3.9.2",
	}
}

test_allows_cronjob_pod_template_chart_version if {
	count(deny) == 0 with input as {
		"op": "replace",
		"path": "/spec/jobTemplate/spec/template/metadata/labels/mozcloud_chart_version",
		"value": "3.9.2",
	}
}

# --- denied: anything else ----------------------------------------------------------------

# Adding the label is not a version bump. It is what a migration onto the MozCloud charts
# looks like, where the previous rendering had no MozCloud labels at all.
test_denies_adding_chart_version if {
	count(deny) == 1 with input as {
		"op": "add",
		"path": "/metadata/labels/mozcloud_chart_version",
		"value": "3.9.1",
	}
}

test_denies_removing_chart_version if {
	count(deny) == 1 with input as {
		"op": "remove",
		"path": "/metadata/labels/mozcloud_chart_version",
	}
}

test_denies_other_label if {
	count(deny) == 1 with input as {
		"op": "replace",
		"path": "/metadata/labels/app_code",
		"value": "somethingelse",
	}
}

test_denies_image_change if {
	count(deny) == 1 with input as {
		"op": "replace",
		"path": "/spec/template/spec/containers/0/image",
		"value": "example:latest",
	}
}

test_denies_replica_change if {
	count(deny) == 1 with input as {
		"op": "replace",
		"path": "/spec/replicas",
		"value": 10,
	}
}

test_denies_whole_document_addition if {
	count(deny) == 1 with input as {
		"op": "add",
		"path": "",
		"value": {"kind": "Service", "metadata": {"name": "example"}},
	}
}

# A selector carrying the same key must not be mistaken for a metadata label: changing it
# would repoint a workload at different pods.
test_denies_selector_with_same_key if {
	count(deny) == 1 with input as {
		"op": "replace",
		"path": "/spec/selector/matchLabels/mozcloud_chart_version",
		"value": "3.9.2",
	}
}

# Guard against the suffix match being too loose
test_denies_label_with_similar_name if {
	count(deny) == 1 with input as {
		"op": "replace",
		"path": "/metadata/labels/mozcloud_chart_version_suffixed",
		"value": "3.9.2",
	}
}

test_denies_annotation_with_same_key if {
	count(deny) == 1 with input as {
		"op": "replace",
		"path": "/metadata/annotations/mozcloud_chart_version",
		"value": "3.9.2",
	}
}
