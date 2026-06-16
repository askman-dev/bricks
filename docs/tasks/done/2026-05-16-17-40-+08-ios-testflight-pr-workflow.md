# iOS TestFlight PR Workflow

## Background

The `go-puzzle` repository has a GitHub Actions workflow that builds an iOS IPA,
uploads it to TestFlight, and labels the associated PR after a successful
upload.

Bricks needs the same release-support workflow for the mobile Flutter app in
this monorepo. The workflow should be limited to pull requests targeting a
designated release branch so it does not run expensive macOS packaging for
every pull request.

## Goals

- Add a GitHub Actions workflow that builds and uploads the iOS app to
  TestFlight.
- Trigger the expensive build only for PRs whose target branch is
  `testflight-beta`.
- Add a `testflight-uploaded` label to the associated PR only after upload
  succeeds.
- Keep secrets and signing configuration in GitHub Actions secrets.

## Implementation Plan

1. Add `.github/workflows/ios-testflight.yml`.
2. Scope the workflow to same-repository pull requests targeting `testflight-beta`
   and manual dispatch.
3. Run Flutter and CocoaPods commands from `apps/mobile_chat_app`.
4. Configure iOS bundle id and team through existing `Release.xcconfig`
   variables using GitHub secrets.
5. Use Codemagic CLI tools to fetch signing files and publish the IPA.
6. Create or update the PR label after a successful upload.

## Acceptance Criteria

- A PR targeting `testflight-beta` triggers the TestFlight workflow.
- PRs targeting other branches do not run the expensive iOS packaging job.
- A successful TestFlight upload adds `testflight-uploaded` to the associated
  PR.
- The workflow can also be run manually through `workflow_dispatch`.
- No App Store Connect credentials, certificate keys, or bundle identifiers are
  hardcoded beyond secret names and existing local defaults.

## Validation Commands

- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ios-testflight.yml"); puts "workflow yaml ok"'`
