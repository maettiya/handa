# Configure AWS SDK for Cloudflare R2 compatibility
#
# R2 is S3-compatible but doesn't support the newer S3 checksum algorithms
# introduced in aws-sdk-s3 1.175+. This configures the SDK globally to only
# calculate checksums when explicitly required.
#
# This must run early before any S3 clients are created.

require "aws-sdk-s3"

Aws.config.update(
  request_checksum_calculation: "when_required",
  response_checksum_validation: "when_required"
)
