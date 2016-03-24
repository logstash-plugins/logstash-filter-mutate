# 2.0.6
  - [Internal] Temp fix for patterns path in tests
# 2.0.5
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash
# 2.0.4
  - New dependency requirements for logstash-core for the 5.0 release
## 2.0.3
 - Code cleanups and fix field assignments

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

## 1.0.2
 - Fix for uppercase and lowercase fail when value is already desired case
 - Modify tests to prove bug and verify fix.

## 1.0.1
 - Fix for uppercase and lowercase malfunction
 - Specific test to prove bug and fix.
