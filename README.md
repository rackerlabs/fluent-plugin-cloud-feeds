# Fluentd output plugin to Rackspace cloud feeds

This plugin mirrors functionality in the [cf-flume-sink](https://github.com/rackerlabs/cf-flume-sink/tree/master/cf-sink)
except for [fluentd](www.fluentd.org) instead of flume.

## Configuration

It is highly recommended to use this plugin with the [bufferize plugin](https://github.com/sabottenda/fluent-plugin-bufferize).
This plugin has been designed to fail in a way that allows the bufferize plugin to properly retry.

### Fluentd configuration for this plugin

```
type rackspace_cloud_feeds
identity_endpoint http://identity.com/post/for/token
identity_username username
identity_password teh_password
feeds_endpoint http://feed.com/endpoint/of/feed
```

* **type** Needs to be rackspace_cloud_feeds for fluentd to recognize the plugin
* **identity_endpoint** The url to authenticate with identity
* **identity_username** The username to use during posting to get a token
* **identity_password** The password component of getting a token
* **feeds_endpoint** The endpoint of the authenticated feed to post events to

### log4j2 logging configuration

This example configuration assumes that you're using the Repose [HERP filter](https://repose.atlassian.net/wiki/display/REPOSE/Highly+Efficient+Record+Processor+%28HERP%29+filter), as this is the primary purpose for building this output plugin.


```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration packages="org.openrepose.commons.utils.xslt">
    <Appenders>
        <RollingFile name="UserAccessEventLog" fileName="/var/log/repose-uae.log"
                     filePattern="logs/$${date:yyyy-MM}/app-%d{MM-dd-yyyy}-%i.log.gz">
            <PatternLayout pattern="%m%n"/>
            <Policies>
                <TimeBasedTriggeringPolicy />
                <SizeBasedTriggeringPolicy size="250 MB"/>
            </Policies>
        </RollingFile>
    </Appenders>
    <Loggers>
        <Logger name="highly-efficient-record-processor-post-Logger" level="trace">
            <AppenderRef ref="UserAccessEventLog"/>
        </Logger>
    </Loggers>
</Configuration>
```

This will ensure that the output log lines from Repose are one JSON per line so that the fluentd can consume them.

### Naieve sample configuration for fluentd

This is a very naieve configuration for fluentd that can be extended upon to configure fluentd to pull in
entries from the repose log and send them out the cloud-feeds fluent plugin through the bufferize plugin.

```
<source>
 type tail
 path /var/log/repose-uae.log
 pos_file /var/log/repose-uae.log
 format none
 tag repose
</source>

<match repose*>
  type bufferize
  buffer_type file
  buffer_path /tmp/repose.*.buffer
  <config>
    type rackspace_cloud_feeds
    identity_endpoint http://localhost:8080/tokens
    identity_username lolol
    identity_password butts
    feeds_endpoint http://localhost:8081/feed
  </config>
</match>
```

There are many options with the bufferize plugin, be sure to read the documentation for bufferize and
fluentd to ensure that the stuff is set up properly for your environment.
