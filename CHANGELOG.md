<!--
K2HR3 Helm Chart

Copyright 2022 Yahoo Japan Corporation.

K2HR3 is K2hdkc based Resource and Roles and policy Rules, gathers 
common management information for the cloud.
K2HR3 can dynamically manage information as "who", "what", "operate".
These are stored as roles, resources, policies in K2hdkc, and the
client system can dynamically read and modify these information.

For the full copyright and license information, please view
the license file that was distributed with this source code.

AUTHOR:   Takeshi Nakatani
CREATE:   Wed Jan 19 2022
REVISION:
-----------------------------------------------------------

[About This file]
This file format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and the version in this repository adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

In addition, the following rules apply to this file update.
This file is updated only when it is released and published,
because it is difficult to operate this file every time the
file is updated or changed.
Therefore, we do not use [Unreleased] in this file.

The items should be added in each release are as follows:
	-----------------
	## [0.0.0] - YYYY-MM-DD
	### Chnaged
	- Commit message - #<PR number>
	- ...
	
	...
	...
	
	[x.x.x]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v0.0.0...v0.0.1
	....
	-----------------
Please have a comparison link which is at the end of the
file ready.
-->
# Change Log for K2HR3 Helm Chart

## [1.0.20] - 2024-03-18
### Changed
- Updated the version of alpine image to 3.19.1

## [1.0.19] - 2024-03-18
### Changed
- Updated the version of k2hr3-app/k2hr3-api to 1.0.34

## [1.0.18] - 2024-01-22
### Changed
- Updated the version 1.0.33 of k2hr3-app docker image

## [1.0.17] - 2023-12-11
### Changed
- Updated the version of k2hr3-app docker image

## [1.0.16] - 2023-11-22
### Changed
- Updated the default version for Docker images

## [1.0.15] - 2023-11-02
### Changed
- Changed the default version for Docker images

## [1.0.14] - 2023-10-11
### Changed
- Updated for NSS library usage fix in CHMPX Fedora/RockyLinux

## [1.0.13] - 2023-09-08
### Changed
- Fixed due to changes in k2hr3 api/app

## [1.0.12] - 2023-08-15
### Changed
- Updated versions of related components

## [1.0.11] - 2023-08-02
### Changed
- Updated README.md

## [1.0.10] - 2023-08-02
### Changed
- Updated to the latest the Docker image used version
- Changed Service Account creation can be dis/enable
- Add input values for local tenant

## [1.0.9] - 2023-06-21
### Changed
- Updated README.md and values.schema.json

## [1.0.8] - 2023-06-21
### Changed
- Fixed questions.yaml due to bugs in RANCHER support

## [1.0.7] - 2023-06-20
### Changed
- Added a function to pass local.json as a parameter

## [1.0.6] - 2023-06-01
### Changed
- Re2-updated default image tag for K2HR3 APP and API

## [1.0.5] - 2023-06-01
### Changed
- Re-updated default image tag for K2HR3 APP and API

## [1.0.4] - 2023-06-01
### Changed
- Updated default image tag for K2HR3 APP and API

## [1.0.3] - 2023-05-31
### Changed
- Fixed a bug about PROXY variables in _helpers.tpl
- Removed LF code from shell scripts output to configmap.yaml
- Added parameters for PROXY and Image, and fixed bugs
- Fixed bugs about checking os type in scripts
- Fixed bugs in scripts in files directory
- Updated scripts under files directory
- Fixed bugs about shellscript contidion
- Updated header and footer in comment lines
- Updated issue/pullrequest templates
- Reviewed ShellCheck processing
- Updated ci.yml for upgrading actions/checkout
- Updated azure/setup-helm from v1 to v3
- Updated helm_packager.sh for changing grep parameter

## [1.0.2] - 2022-03-11
### Changed
- Fixed a bug(helm_package.sh) and Updated some files

## [1.0.1] - 2022-03-11
### Changed
- Supported RANCHER as RANCHER Helm Chart

## [1.0.0] - 2022-02-09
### Changed
- Initial Commit and publishing

[1.0.20]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.19...v1.0.20
[1.0.19]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.18...v1.0.19
[1.0.18]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.17...v1.0.18
[1.0.17]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.16...v1.0.17
[1.0.16]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.15...v1.0.16
[1.0.15]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.14...v1.0.15
[1.0.14]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.13...v1.0.14
[1.0.13]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.12...v1.0.13
[1.0.12]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.11...v1.0.12
[1.0.11]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.10...v1.0.11
[1.0.10]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.9...v1.0.10
[1.0.9]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/yahoojapan/k2hr3_helm_chart/compare/58ea5df...v1.0.0
