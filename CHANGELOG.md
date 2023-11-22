## 3.5.8
  - Fix "Can't modify frozen string" error when converting boolean to `string` [#171](https://github.com/logstash-plugins/logstash-filter-mutate/pull/171) 
  
## 3.5.7
  - Clarify that `split` and `join` also support strings [#164](https://github.com/logstash-plugins/logstash-filter-mutate/pull/164)

## 3.5.6
 - [DOC] Added info on maintaining precision between Ruby float and Elasticsearch float [#158](https://github.com/logstash-plugins/logstash-filter-mutate/pull/158)

## 3.5.5
 - Fix: removed code and documentation for already removed 'remove' option. [#161](https://github.com/logstash-plugins/logstash-filter-mutate/pull/161)

## 3.5.4
 - [DOC] In 'replace' documentation, mention 'add' behavior [#155](https://github.com/logstash-plugins/logstash-filter-mutate/pull/155)
 - [DOC] Note that each mutate must be in its own code block as noted in issue [#27](https://github.com/logstash-plugins/logstash-filter-mutate/issues/27). Doc fix [#101](https://github.com/logstash-plugins/logstash-filter-mutate/pull/101)

## 3.5.3
 - [DOC] Expand description and behaviors for `rename` option [#156](https://github.com/logstash-plugins/logstash-filter-mutate/pull/156)

## 3.5.2
 - Fix: ensure that when an error occurs during registration, we use the correct i18n key to propagate the error message in a useful manner [#154](https://github.com/logstash-plugins/logstash-filter-mutate/pull/154)

## 3.5.1
 - Fix: removed a minor optimization in case-conversion helpers that could result in a race condition in very rare and specific situations [#151](https://github.com/logstash-plugins/logstash-filter-mutate/pull/151)

## 3.5.0
 - Fix: eliminated possible pipeline crashes; when a failure occurs during the application of this mutate filter, the rest of
the operations are now aborted and a configurable tag is added to the event [#136](https://github.com/logstash-plugins/logstash-filter-mutate/pull/136)

## 3.4.0
 - Added ability to directly convert from integer and float to boolean [#127](https://github.com/logstash-plugins/logstash-filter-mutate/pull/127)

## 3.3.4
 - [DOC] Changed documentation to clarify execution order and to provide workaround 
 [#128](https://github.com/logstash-plugins/logstash-filter-mutate/pull/128)

## 3.3.3
 - Changed documentation to clarify use of `replace` config option [#125](https://github.com/logstash-plugins/logstash-filter-mutate/pull/125)

## 3.3.2
 - Fix: when converting to `float` and `float_eu`, explicitly support same range of inputs as their integer counterparts; eliminates a regression introduced in 3.3.1 in which support for non-string inputs was inadvertently removed.

## 3.3.1
 - Fix: Number strings using a **decimal comma** (e.g. 1,23), added convert support to specify integer_eu and float_eu.

## 3.3.0
 - feature: Added capitalize feature.

## 3.2.0
  - Support boolean to integer conversion #107

## 3.1.7
  - Update gemspec summary

## 3.1.6
  - Fix some documentation issues

## 3.1.4
 - feature: Allow to copy fields.

## 3.1.3
 - Don't create empty fields when lower/uppercasing a non-existant field

## 3.1.2
 - bugfix: split method was not working, #78

## 3.1.1
 - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99

## 3.1.0
 - breaking,config: Remove deprecated config `remove`. Please use generic `remove_field` instead.

## 3.0.1
 - internal: Republish all the gems under jruby.

## 3.0.0
 - internal,deps: Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141

## 2.0.6
 - internal,test: Temp fix for patterns path in tests

## 2.0.5
 - internal,deps: Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash

## 2.0.4
 - internal,deps: New dependency requirements for logstash-core for the 5.0 release

## 2.0.3
 - internal,cleanup: Code cleanups and fix field assignments

## 2.0.0
 - internal: Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - internal,deps: Dependency on logstash-core update to 2.0

## 1.0.2
 - bugfix: Fix for uppercase and lowercase fail when value is already desired case
 - internal,test: Modify tests to prove bug and verify fix.

## 1.0.1
 - bugfix: Fix for uppercase and lowercase malfunction
 - internal,test: Specific test to prove bug and fix.
