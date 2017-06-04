# Change Log

## [1.2](https://github.com/arista-eosplus/puppet-netdev/tree/1.2) (2017-06-03)
[Full Changelog](https://github.com/arista-eosplus/puppet-netdev/compare/v1.1.1...1.2)

**Fixed bugs:**

- Syntax Error in tacacs\_server provider [\#31](https://github.com/arista-eosplus/puppet-netdev/issues/31)
- \(maint\) Limit import of rbeapi to systems that support it [\#36](https://github.com/arista-eosplus/puppet-netdev/pull/36) ([shermdog](https://github.com/shermdog))
- Backout rubocop suggestion which causes failures [\#32](https://github.com/arista-eosplus/puppet-netdev/pull/32) ([jerearista](https://github.com/jerearista))

**Merged pull requests:**

- \(NETDEV-29\) Enhance netdev NTP providers [\#37](https://github.com/arista-eosplus/puppet-netdev/pull/37) ([shermdog](https://github.com/shermdog))
- Remove deprecated 'pe' from requirements [\#35](https://github.com/arista-eosplus/puppet-netdev/pull/35) ([jerearista](https://github.com/jerearista))
- Release 1.1.2 [\#34](https://github.com/arista-eosplus/puppet-netdev/pull/34) ([jerearista](https://github.com/jerearista))
- Hotfix 1.1.2 [\#33](https://github.com/arista-eosplus/puppet-netdev/pull/33) ([jerearista](https://github.com/jerearista))

## [v1.1.1](https://github.com/arista-eosplus/puppet-netdev/tree/v1.1.1) (2016-01-06)
[Full Changelog](https://github.com/arista-eosplus/puppet-netdev/compare/v1.1.0...v1.1.1)

**Fixed bugs:**

- Metadata update [\#29](https://github.com/arista-eosplus/puppet-netdev/pull/29) ([jerearista](https://github.com/jerearista))

**Merged pull requests:**

- Release 1.1.1: Remove unnecessary dependency and correct issues URL [\#30](https://github.com/arista-eosplus/puppet-netdev/pull/30) ([jerearista](https://github.com/jerearista))

## [v1.1.0](https://github.com/arista-eosplus/puppet-netdev/tree/v1.1.0) (2016-01-06)
[Full Changelog](https://github.com/arista-eosplus/puppet-netdev/compare/v1.0.0...v1.1.0)

**Implemented enhancements:**

- Confine providers to only run on AristaEOS and when rbeapi is present [\#26](https://github.com/arista-eosplus/puppet-netdev/issues/26)
- Update metadata to include requirements section [\#25](https://github.com/arista-eosplus/puppet-netdev/issues/25)
- Release 1.1.0 to Master [\#28](https://github.com/arista-eosplus/puppet-netdev/pull/28) ([jerearista](https://github.com/jerearista))

**Fixed bugs:**

- Could not autoload puppet/provider/radius/eos when running rspec tests [\#16](https://github.com/arista-eosplus/puppet-netdev/issues/16)

**Closed issues:**

- cannot load such file -- puppet\_x/net\_dev/eos\_api [\#17](https://github.com/arista-eosplus/puppet-netdev/issues/17)

**Merged pull requests:**

- Release 1.1.0 [\#27](https://github.com/arista-eosplus/puppet-netdev/pull/27) ([jerearista](https://github.com/jerearista))
- Release 1.0 [\#24](https://github.com/arista-eosplus/puppet-netdev/pull/24) ([privateip](https://github.com/privateip))

## [v1.0.0](https://github.com/arista-eosplus/puppet-netdev/tree/v1.0.0) (2015-06-05)
[Full Changelog](https://github.com/arista-eosplus/puppet-netdev/compare/v0.2.0...v1.0.0)

**Closed issues:**

- Bad doc links to rbeapi [\#20](https://github.com/arista-eosplus/puppet-netdev/issues/20)

**Merged pull requests:**

- Release 1.0 [\#23](https://github.com/arista-eosplus/puppet-netdev/pull/23) ([privateip](https://github.com/privateip))
- Clean up spec tests and pull in JJM 14149 \#17 [\#22](https://github.com/arista-eosplus/puppet-netdev/pull/22) ([jerearista](https://github.com/jerearista))
- Fixup URLs to rbeapi.  Closes \#20 [\#21](https://github.com/arista-eosplus/puppet-netdev/pull/21) ([jerearista](https://github.com/jerearista))
- fix path issues related to JJM 14149 [\#19](https://github.com/arista-eosplus/puppet-netdev/pull/19) ([greenpau](https://github.com/greenpau))

## [v0.2.0](https://github.com/arista-eosplus/puppet-netdev/tree/v0.2.0) (2015-02-25)
**Merged pull requests:**

- \(ARISTA-30\) Add tacacs\_server\_group provider [\#15](https://github.com/arista-eosplus/puppet-netdev/pull/15) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-32\) Add tacacs\_server provider [\#14](https://github.com/arista-eosplus/puppet-netdev/pull/14) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-31\) Add provider for tacacs\_global type [\#13](https://github.com/arista-eosplus/puppet-netdev/pull/13) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-29\) Add radius\_server\_group provider [\#12](https://github.com/arista-eosplus/puppet-netdev/pull/12) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-33\) Add radius\_server provider [\#11](https://github.com/arista-eosplus/puppet-netdev/pull/11) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-27\) added ntp\_config provider [\#10](https://github.com/arista-eosplus/puppet-netdev/pull/10) ([privateip](https://github.com/privateip))
- \(ARISTA-34\) Add radius\_global provider [\#9](https://github.com/arista-eosplus/puppet-netdev/pull/9) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-28\) Remove PuppetX::NetDev::EosApi namespace [\#8](https://github.com/arista-eosplus/puppet-netdev/pull/8) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-22\) Add snmp\_user provider [\#7](https://github.com/arista-eosplus/puppet-netdev/pull/7) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-24\) Implement snmp\_notification\_receiver provider [\#6](https://github.com/arista-eosplus/puppet-netdev/pull/6) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-23\) Implement snmp\_notification provider [\#5](https://github.com/arista-eosplus/puppet-netdev/pull/5) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-21\) Use snmp\_community flush for management [\#4](https://github.com/arista-eosplus/puppet-netdev/pull/4) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-20\) Add provider for network\_snmp type [\#3](https://github.com/arista-eosplus/puppet-netdev/pull/3) ([jeffmccune](https://github.com/jeffmccune))
- \(ARISTA-3\) Add EOS port\_channel provider [\#2](https://github.com/arista-eosplus/puppet-netdev/pull/2) ([jeffmccune](https://github.com/jeffmccune))
- Add EOS provider for network\_interface and network\_vlan [\#1](https://github.com/arista-eosplus/puppet-netdev/pull/1) ([jeffmccune](https://github.com/jeffmccune))



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*