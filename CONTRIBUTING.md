# Contributing
1. Create a feature branch for your change.
2. Push up your proposed changes to your feature branch.
  * Ensure you have full test coverage. Untested code will not be merged in and code coverage is reported on all builds.
  * Bump the version of the gem according to [Versioning](#versioning) below
  * Breaking changes resulting in a major version bump will require more discussion, so please try to keep changes
  fully backward-compatible unless you have a good reason not to.
  * Update documentation in README.md and CHANGES.mb
2. Create a Pull Request with your change.

### Versioning
This gem follows Semantic Versioning (2.0):

Given a version number MAJOR.MINOR.PATCH, increment the:

MAJOR version when you make incompatible API changes,
MINOR version when you add functionality in a backwards compatible manner, and
PATCH version when you make backwards compatible bug fixes.