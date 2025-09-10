
{{/*
Data templates for mozcloud-shared-data-lib

These templates expose the common data in a way that can be accessed by dependent charts.
The data is embedded directly in the templates to avoid file access limitations.
*/}}

{{/*
mozcloud-shared-data-lib.commonData
Returns the raw common data as YAML.
This is the primary way for dependent charts to access the shared data.
*/}}
{{- define "mozcloud-shared-data-lib.commonData" -}}
0din:
  labels:
    component_code: unset
    domain: 0din
    env_code: unset
    realm: unset
    system: 0din
ads:
  labels:
    component_code: unset
    domain: ads
    env_code: unset
    realm: unset
    system: ads
airflow-gke:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: airflow-gke
amo:
  labels:
    component_code: unset
    domain: amo
    env_code: unset
    realm: unset
    system: amo
assets-mozilla-net:
  labels:
    component_code: unset
    domain: mozilla-org
    env_code: unset
    realm: unset
    system: assets-mozilla-net
autograph:
  labels:
    component_code: unset
    domain: autograph
    env_code: unset
    realm: unset
    system: autograph
autopush:
  labels:
    component_code: unset
    domain: push
    env_code: unset
    realm: unset
    system: autopush
backstage:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: backstage
balrog:
  labels:
    component_code: unset
    domain: productdelivery
    env_code: unset
    realm: unset
    system: balrog
basket:
  labels:
    component_code: unset
    domain: marketing
    env_code: unset
    realm: unset
    system: basket
bedrock:
  labels:
    component_code: unset
    domain: mozilla-org
    env_code: unset
    realm: unset
    system: bedrock
birdbox:
  labels:
    component_code: unset
    domain: mozilla-org
    env_code: unset
    realm: unset
    system: birdbox
bouncer:
  labels:
    component_code: unset
    domain: productdelivery
    env_code: unset
    realm: unset
    system: bouncer
braze-cdn:
  labels:
    component_code: unset
    domain: marketing
    env_code: unset
    realm: unset
    system: braze-cdn
browser-proxy:
  labels:
    component_code: unset
    domain: vpn
    env_code: unset
    realm: unset
    system: browser-proxy
bugbug:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: bugbug
bugzilla:
  labels:
    component_code: unset
    domain: bugzilla
    env_code: unset
    realm: unset
    system: bugzilla
cavendish:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: cavendish
cicd-demos:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: cicd-demos
cinder:
  labels:
    component_code: unset
    domain: trustsafety
    env_code: unset
    realm: unset
    system: cinder
cirrus:
  labels:
    component_code: unset
    domain: experimenter
    env_code: unset
    realm: unset
    system: cirrus
classify-client:
  labels:
    component_code: unset
    domain: firefox
    env_code: unset
    realm: unset
    system: classify-client
code-cdn-mozilla-net:
  labels:
    component_code: unset
    domain: mdn
    env_code: unset
    realm: unset
    system: code-cdn-mozilla-net
common-voice:
  labels:
    component_code: unset
    domain: common-voice
    env_code: unset
    realm: unset
    system: common-voice
content-sig-chains:
  labels:
    component_code: unset
    domain: autograph
    env_code: unset
    realm: unset
    system: content-sig-chains
crlite:
  labels:
    component_code: unset
    domain: firefox
    env_code: unset
    realm: unset
    system: crlite
ctms:
  labels:
    component_code: unset
    domain: marketing
    env_code: unset
    realm: unset
    system: ctms
dap:
  labels:
    component_code: unset
    domain: firefox
    env_code: unset
    realm: unset
    system: dap
data-artifacts:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: data-artifacts
data-privacy-mapping:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: data-privacy-mapping
data-static-websites:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: data-static-websites
datahub:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: datahub
enterprise-apps:
  labels:
    component_code: unset
    domain: enterprise-application
    env_code: unset
    realm: unset
    system: enterprise-apps
experimenter:
  labels:
    component_code: unset
    domain: experimenter
    env_code: unset
    realm: unset
    system: experimenter
extensionworkshop:
  labels:
    component_code: unset
    domain: amo
    env_code: unset
    realm: unset
    system: extensionworkshop
fakespot:
  labels:
    component_code: unset
    domain: fakespot
    env_code: unset
    realm: unset
    system: fakespot
fivetran:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: fivetran
fx-profiler:
  labels:
    component_code: unset
    domain: firefox
    env_code: unset
    realm: unset
    system: fx-profiler
fx-sig-verify:
  labels:
    component_code: unset
    domain: productdelivery
    env_code: unset
    realm: unset
    system: fx-sig-verify
fxa:
  labels:
    component_code: unset
    domain: mozilla-accounts
    env_code: unset
    realm: unset
    system: fxa
fxa-testing:
  labels:
    component_code: unset
    domain: mozilla-accounts
    env_code: unset
    realm: unset
    system: fxa-testing
gemini-poc:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: gemini-poc
git-hg-sync:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: git-hg-sync
glam:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: glam
grafana:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: grafana
hg:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: hg
iam:
  labels:
    component_code: unset
    domain: enterprise-iam
    env_code: unset
    realm: unset
    system: iam
ios-logging:
  labels:
    component_code: unset
    domain: firefox-mobile
    env_code: unset
    realm: unset
    system: ios-logging
jbi:
  labels:
    component_code: unset
    domain: bugzilla
    env_code: unset
    realm: unset
    system: jbi
lando:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: lando
llm-proxy:
  labels:
    component_code: unset
    domain: firefox-mobile
    env_code: unset
    realm: unset
    system: llm-proxy
mad:
  labels:
    component_code: unset
    domain: amo
    env_code: unset
    realm: unset
    system: mad
mdn:
  labels:
    component_code: unset
    domain: mdn
    env_code: unset
    realm: unset
    system: mdn
meao:
  labels:
    component_code: unset
    domain: marketing
    env_code: unset
    realm: unset
    system: meao
merino:
  labels:
    component_code: unset
    domain: suggest
    env_code: unset
    realm: unset
    system: merino
mfouterbounds:
  labels:
    component_code: unset
    domain: mlops
    env_code: unset
    realm: unset
    system: mfouterbounds
mlops:
  labels:
    component_code: unset
    domain: mlops
    env_code: unset
    realm: unset
    system: mlops
mlops-inference:
  labels:
    component_code: unset
    domain: mlops
    env_code: unset
    realm: unset
    system: mlops-inference
model-hub:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: model-hub
moderator:
  labels:
    component_code: unset
    domain: enterprise-application
    env_code: unset
    realm: unset
    system: moderator
mofo-data:
  labels:
    component_code: unset
    domain: mofo
    env_code: unset
    realm: unset
    system: mofo-data
monitor:
  labels:
    component_code: unset
    domain: monitor
    env_code: unset
    realm: unset
    system: monitor
moz-language-portal:
  labels:
    component_code: unset
    domain: l10n
    env_code: unset
    realm: unset
    system: moz-language-portal
mozsoc-ml:
  labels:
    component_code: unset
    domain: unset
    env_code: unset
    realm: unset
    system: mozsoc-ml
mozsoc-router:
  labels:
    component_code: unset
    domain: unset
    env_code: unset
    realm: unset
    system: mozsoc-router
mozsocial-dw:
  labels:
    component_code: unset
    domain: unset
    env_code: unset
    realm: unset
    system: mozsocial-dw
mzcld-demo:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: mzcld-demo
necko-logup:
  labels:
    component_code: unset
    domain: firefox
    env_code: unset
    realm: unset
    system: necko-logup
nucleus:
  labels:
    component_code: unset
    domain: mozilla-org
    env_code: unset
    realm: unset
    system: nucleus
o11y-demo:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: o11y-demo
ohttp-gateway:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: ohttp-gateway
outgoing:
  labels:
    component_code: unset
    domain: amo
    env_code: unset
    realm: unset
    system: outgoing
phabricator:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: phabricator
pocket-snowplow:
  labels:
    component_code: unset
    domain: pocket
    env_code: unset
    realm: unset
    system: pocket-snowplow
pollbot:
  labels:
    component_code: unset
    domain: productdelivery
    env_code: unset
    realm: unset
    system: pollbot
pontoon:
  labels:
    component_code: unset
    domain: l10n
    env_code: unset
    realm: unset
    system: pontoon
probe-scraper:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: probe-scraper
productdelivery:
  labels:
    component_code: unset
    domain: productdelivery
    env_code: unset
    realm: unset
    system: productdelivery
publicsuffix:
  labels:
    component_code: unset
    domain: publicsuffix
    env_code: unset
    realm: unset
    system: publicsuffix
qa-gha:
  labels:
    component_code: unset
    domain: test-engineering
    env_code: unset
    realm: unset
    system: qa-gha
rapid-release-model:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: rapid-release-model
refractr:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: refractr
relay:
  labels:
    component_code: unset
    domain: relay
    env_code: unset
    realm: unset
    system: relay
relengworker:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: relengworker
relsre-metrics:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: relsre-metrics
remote-settings:
  labels:
    component_code: unset
    domain: remote-settings
    env_code: unset
    realm: unset
    system: remote-settings
seceng-workloads:
  labels:
    component_code: unset
    domain: mozcloud-security
    env_code: unset
    realm: unset
    system: seceng-workloads
shavar:
  labels:
    component_code: unset
    domain: firefox
    env_code: unset
    realm: unset
    system: shavar
socorro:
  labels:
    component_code: unset
    domain: crash-ingestion
    env_code: unset
    realm: unset
    system: socorro
spacelift-poc:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: spacelift-poc
springfield:
  labels:
    component_code: unset
    domain: mozilla-org
    env_code: unset
    realm: unset
    system: springfield
stubattribution:
  labels:
    component_code: unset
    domain: productdelivery
    env_code: unset
    realm: unset
    system: stubattribution
stv:
  labels:
    component_code: unset
    domain: unset
    env_code: unset
    realm: unset
    system: stv
sumo:
  labels:
    component_code: unset
    domain: sumo
    env_code: unset
    realm: unset
    system: sumo
sw-delivery-perf:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: sw-delivery-perf
symbols:
  labels:
    component_code: unset
    domain: crash-ingestion
    env_code: unset
    realm: unset
    system: symbols
sync:
  labels:
    component_code: unset
    domain: sync
    env_code: unset
    realm: unset
    system: sync
tabs:
  labels:
    component_code: unset
    domain: tabs
    env_code: unset
    realm: unset
    system: tabs
taskcluster:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: taskcluster
telemetry-airflow:
  labels:
    component_code: unset
    domain: dataplatform
    env_code: unset
    realm: unset
    system: telemetry-airflow
telescope:
  labels:
    component_code: unset
    domain: remote-settings
    env_code: unset
    realm: unset
    system: telescope
testapp4:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: testapp4
testapp5:
  labels:
    component_code: unset
    domain: mozcloud
    env_code: unset
    realm: unset
    system: testapp5
themer:
  labels:
    component_code: unset
    domain: firefox
    env_code: unset
    realm: unset
    system: themer
treeherder:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: treeherder
vpn:
  labels:
    component_code: unset
    domain: vpn
    env_code: unset
    realm: unset
    system: vpn
vpn-network-benchmark:
  labels:
    component_code: unset
    domain: vpn
    env_code: unset
    realm: unset
    system: vpn-network-benchmark
webcompat:
  labels:
    component_code: unset
    domain: firefox
    env_code: unset
    realm: unset
    system: webcompat
whattrainisitnow:
  labels:
    component_code: unset
    domain: firefox
    env_code: unset
    realm: unset
    system: whattrainisitnow
wikimo:
  labels:
    component_code: unset
    domain: wiki
    env_code: unset
    realm: unset
    system: wikimo
youtube-test:
  labels:
    component_code: unset
    domain: firefoxci
    env_code: unset
    realm: unset
    system: youtube-test

{{- end -}}
