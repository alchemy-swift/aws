# Alchemy AWS

Support for AWS integration with Alchemy. 

Currently provides S3 integration for `Filesystem` with the `AlchemyS3` package.

## Installation

Use the Swift Package Manager.

```swift
.package(url: "https://github.com/alchemy-swift/aws", branch: "main"),
```

## Usage

```swift
import AlchemyS3

let filesystem: Filesystem = .s3(
    key: "<key>",
    secret: "<secret>",
    bucket: "<bucket>",
    region: .useast1,
    endpoint: "<endpoint>" // If using S3 compatible storage such as DigitalOcean Spaces
)
```
